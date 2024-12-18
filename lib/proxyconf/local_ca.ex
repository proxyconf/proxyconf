defmodule ProxyConf.LocalCA do
  @moduledoc """
    This module implements a simple certificate authority that is used to
    create on-demand TLS certificates (incl key material) in case a certificate
    is required but isn't available.

    In general it's recommended to NOT rely on this certificate authority and use
    a solid PKI instead.
  """

  require Logger
  use GenServer
  alias ProxyConf.Api.DbTlsCert

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    reload_interval = Keyword.fetch!(args, :cache_reload_interval)
    rotation_period = Keyword.fetch!(args, :rotation_period_hours)
    validity = Keyword.fetch!(args, :validity_days)
    issuer_cert = Keyword.fetch!(args, :issuer_cert) |> File.read!()
    issuer_key = Keyword.fetch!(args, :issuer_key) |> File.read!()

    state =
      register_certs(%{
        certs: %{},
        tref: nil,
        reload_interval: reload_interval,
        rotation_period: rotation_period,
        validity: validity,
        issuer_fn: fn -> %{cert: issuer_cert, key: issuer_key} end
      })

    Map.keys(state.certs)
    |> Enum.group_by(fn {cluster, _} -> cluster end, fn {_, name} -> name end)
    |> Enum.each(fn {cluster, names} ->
      Logger.info(
        "Registered the following certificates for cluster #{cluster} during bootup #{inspect(names)}"
      )
    end)

    {:ok, state}
  end

  def handle_call(
        {:get_matching_certificate, cluster, common_name},
        _from,
        state
      ) do
    {reply, state} =
      case Map.get_lazy(state.certs, {cluster, common_name}, fn ->
             [_subdomain | rest] = String.split(common_name, ".")
             wildcard_domain = "*." <> Enum.join(rest, ".")
             Map.get(state.certs, wildcard_domain)
           end) do
        nil ->
          {create_cert(cluster, common_name, state.issuer_fn, state.validity),
           register_certs(state)}

        cert_id ->
          db_cert = ProxyConf.Repo.get(DbTlsCert, cert_id)

          if not is_nil(db_cert) do
            Logger.info("Found valid certificate ##{cert_id} for #{common_name}")

            {wrap_fn({db_cert.cert_pem, db_cert.key_pem}), state}
          else
            # Cache Miss, Cert was cleared from DB
            {create_cert(cluster, common_name, state.issuer_fn, state.validity),
             register_certs(state)}
          end
      end

    {:reply, reply, state}
  end

  def handle_call(:trigger_reload_externally, _from, state) do
    Process.send(self(), :reload, [])
    {:reply, :ok, state}
  end

  def handle_info(:reload, state) do
    if state.tref do
      Process.cancel_timer(state.tref)
    end

    {:noreply, register_certs(state)}
  end

  defp register_certs(state) do
    certs =
      ProxyConf.Repo.all(DbTlsCert)
      |> Enum.reduce(%{}, fn %DbTlsCert{} = cert, acc ->
        register_cert(cert, state)
        |> Map.merge(acc)
      end)

    %{state | certs: certs, tref: Process.send_after(self(), :reload, state.reload_interval)}
  end

  defp parse_cert(cert_pem) do
    import X509.ASN1
    now = DateTime.utc_now()

    with {:ok, cert} <- X509.Certificate.from_pem(cert_pem),
         [common_name | _] <- X509.Certificate.subject(cert, oid(:"id-at-commonName")),
         {:Validity, not_before, not_after} <- X509.Certificate.validity(cert),
         not_before <- X509.DateTime.to_datetime(not_before),
         not_after <- X509.DateTime.to_datetime(not_after),
         {:validity, _, false} <-
           {:validity, :not_after, DateTime.after?(now, not_after)} do
      {:ok, %{common_name: common_name, cert: cert, not_before: not_before, not_after: not_after}}
    else
      {:validity, t, _} ->
        {:error, :invalid, t}

      {:error, reason} ->
        {:error, reason}

      e ->
        {:error, e}
    end
  end

  defp register_cert(%DbTlsCert{} = db_cert, state) do
    import X509.ASN1
    now = DateTime.utc_now()

    with {:ok, %{common_name: common_name, cert: cert, not_before: not_before}} <-
           parse_cert(db_cert.cert_pem),
         {:not_yet_valid, false} <- {:not_yet_valid, DateTime.before?(now, not_before)},
         {:rotation_period, false} <-
           {
             :rotation_period,
             # auto rotation only makes sense for locally issued certs
             db_cert.local_ca and
               DateTime.after?(now, DateTime.add(not_before, state.rotation_period, :hour))
           } do
      X509.Certificate.extension(cert, :subject_alt_name)
      |> extension(:extnValue)
      |> Keyword.get_values(:dNSName)
      |> Map.new(fn san -> {{db_cert.cluster, List.to_string(san)}, db_cert.id} end)
      |> Map.put({db_cert.cluster, common_name}, db_cert.id)
    else
      {:not_yet_valid, true} ->
        Logger.debug(
          "Skipping ##{db_cert.id} for cluster #{db_cert.cluster} as it hasn't entered validity period yet"
        )

        %{}

      {:error, :invalid, t} ->
        Logger.warning(
          "Certificate ##{db_cert.id} for cluster #{db_cert.cluster} is not used as it doesn't match the validity constraint '#{t}'"
        )

        %{}

      {:rotation_period, true} ->
        Logger.info(
          "Certificate ##{db_cert.id} for cluster #{db_cert.cluster} is not used as it it is subject to rotation"
        )

        %{}

      {:error, reason} ->
        Logger.error(
          "Can't register certificate ##{db_cert.id} for cluster #{db_cert.cluster} due to #{inspect(reason)}"
        )

        %{}
    end
  end

  def server_cert(cluster, hostname) do
    GenServer.call(
      __MODULE__,
      {:get_matching_certificate, cluster, hostname},
      :infinity
    )
  end

  def trigger_reload do
    GenServer.multi_call(__MODULE__, :trigger_reload_externally)
  end

  def store_external_cert(cluster, cert, key) do
    case parse_cert(cert) do
      {:ok, %{common_name: common_name}} ->
        key = X509.PrivateKey.from_pem!(key)

        %DbTlsCert{
          cluster: cluster,
          cert_pem: cert,
          hostname: common_name,
          local_ca: false,
          key_pem: key
        }
        |> DbTlsCert.changeset(%{})
        |> ProxyConf.Repo.insert!()

        trigger_reload()

        :ok

      {:error, :invalid, _} ->
        {:error, :invalid}
    end
  rescue
    e ->
      {:error, e}
  end

  defp create_cert(cluster, hostname, issuer_fn, validity) do
    %{cert: issuer_cert, key: issuer_key} = issuer_fn.()

    subject = "/CN=#{hostname}"
    key = X509.PrivateKey.new_ec(:secp256r1)
    pub = X509.PublicKey.derive(key)

    [common_name] =
      X509.RDNSequence.new(subject)
      |> X509.RDNSequence.get_attr(:commonName)

    import X509.Certificate.Extension

    template = %X509.Certificate.Template{
      validity: validity,
      hash: :sha256,
      extensions: [
        basic_constraints: basic_constraints(false),
        key_usage: key_usage([:digitalSignature, :keyEncipherment]),
        ext_key_usage: ext_key_usage([:serverAuth, :clientAuth]),
        subject_key_identifier: true,
        authority_key_identifier: true,
        subject_alt_name: subject_alt_name([common_name])
      ]
    }

    cert =
      X509.Certificate.new(
        pub,
        subject,
        issuer_cert |> X509.Certificate.from_pem!(),
        issuer_key |> X509.PrivateKey.from_pem!(),
        template: template
      )
      |> X509.Certificate.to_pem()

    db_tls_cert =
      %DbTlsCert{
        cluster: cluster,
        cert_pem: cert,
        hostname: hostname,
        local_ca: true,
        key_pem: key |> X509.PrivateKey.to_pem()
      }
      |> DbTlsCert.changeset(%{})
      |> ProxyConf.Repo.insert!()

    wrap_fn({db_tls_cert.cert_pem, db_tls_cert.key_pem})
  end

  defp wrap_fn(res), do: fn -> res end
end
