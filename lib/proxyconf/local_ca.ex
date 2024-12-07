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

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    {:ok,
     %{
       certs:
         register_certs()
         |> tap(fn certs ->
           Map.keys(certs)
           |> Enum.group_by(fn {cluster, _} -> cluster end, fn {_, name} -> name end)
           |> Enum.each(fn {cluster, names} ->
             Logger.info(
               "Registered the following certificates for cluster #{cluster} during bootup #{inspect(names)}"
             )
           end)
         end),
       tref: Process.send_after(self(), :reload, 300_000)
     }}
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
          {create_cert(cluster, common_name), %{state | certs: register_certs()}}

        cert_id ->
          Logger.info("Found valid certificate ##{cert_id} for #{common_name}")

          db_cert = ProxyConf.Repo.get(DbTlsCert, cert_id)

          {wrap_fn({db_cert.cert_pem, db_cert.key_pem}), state}
      end

    {:reply, reply, state}
  end

  def handle_info(:reload, state) do
    if state.tref do
      Process.cancel_timer(state.tref)
    end

    certs = register_certs()
    tref = Process.send_after(self(), :reload, 300_000)

    {:noreply, %{state | certs: certs, tref: tref}}
  end

  defp register_certs do
    ProxyConf.Repo.all(DbTlsCert)
    |> Enum.reduce(%{}, fn %DbTlsCert{} = cert, acc ->
      register_cert(cert)
      |> Map.merge(acc)
    end)
  end

  defp register_cert(%DbTlsCert{} = db_cert) do
    import X509.ASN1

    with {:ok, cert} <- X509.Certificate.from_pem(db_cert.cert_pem),
         [common_name | _] <- X509.Certificate.subject(cert, oid(:"id-at-commonName")),
         {:Validity, not_before, not_after} <- X509.Certificate.validity(cert),
         not_before <- X509.DateTime.to_datetime(not_before),
         not_after <- X509.DateTime.to_datetime(not_after),
         {:validity, _, false} <-
           {:validity, :not_before, DateTime.before?(DateTime.utc_now(), not_before)},
         {:validity, _, false} <-
           {:validity, :not_after, DateTime.after?(DateTime.utc_now(), not_after)} do
      X509.Certificate.extension(cert, :subject_alt_name)
      |> extension(:extnValue)
      |> Keyword.get_values(:dNSName)
      |> Map.new(fn san -> {{db_cert.cluster, List.to_string(san)}, db_cert.id} end)
      |> Map.put({db_cert.cluster, common_name}, db_cert.id)
    else
      {:validity, t, _} ->
        Logger.warning(
          "Certificate ##{db_cert.id} for cluster #{db_cert.cluster} is not used as it doesn't match the validity constraint '#{t}'"
        )

        %{}

      {:error, reason} ->
        Logger.error(
          "Can't register certificate ##{db_cert.id} for cluster #{db_cert.cluster} due to #{inspect(reason)}"
        )

        %{}

      e ->
        Logger.error(
          "Can't register certificate ##{db_cert.id} for cluster #{db_cert.cluster} due to #{inspect(e)}"
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

  defp create_cert(cluster, hostname) do
    issuer_key = Application.fetch_env!(:proxyconf, :certificate_issuer_key) |> File.read!()

    issuer_cert =
      Application.fetch_env!(:proxyconf, :certificate_issuer_cert) |> File.read!()

    subject = "/CN=#{hostname}"
    key = X509.PrivateKey.new_ec(:secp256r1)
    pub = X509.PublicKey.derive(key)

    [common_name] =
      X509.RDNSequence.new(subject)
      |> X509.RDNSequence.get_attr(:commonName)

    import X509.Certificate.Extension

    template = %X509.Certificate.Template{
      # 30 days
      validity: Application.get_env(:proxyconf, :self_issued_cert_validity, 30),
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
        key_pem: key |> X509.PrivateKey.to_pem()
      }
      |> DbTlsCert.changeset(%{})
      |> ProxyConf.Repo.insert!()

    wrap_fn({db_tls_cert.cert_pem, db_tls_cert.key_pem})
  end

  defp wrap_fn(res), do: fn -> res end
end
