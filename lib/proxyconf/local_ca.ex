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

  @ca_subject "ProxyConf self-signed issuer"
  @control_plane_subject "ProxyConf control plane"
  @client_subject "ProxyConf client"

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    downstream_tls_path = Application.fetch_env!(:proxyconf, :downstream_tls_path)

    {:ok, _pid} =
      FileSystem.start_link(dirs: [downstream_tls_path], name: :downstream_tls_watcher)

    FileSystem.subscribe(:downstream_tls_watcher)
    Process.send(self(), :reload, [])

    Process.spawn(
      fn ->
        ca_setup()
        control_plane_server_cert_setup()
        control_plane_client_cert_setup()
      end,
      []
    )

    {:ok,
     %{
       certs:
         register_certs()
         |> tap(fn certs ->
           Logger.info(
             "Registered the following certificates during bootup #{inspect(Map.keys(certs))}"
           )
         end),
       tref: nil
     }}
  end

  def handle_call(
        {:get_matching_certificate, common_name, certificate_gen, private_key_gen},
        _from,
        state
      ) do
    reply =
      case Map.get_lazy(state.certs, common_name, fn ->
             [_subdomain | rest] = String.split(common_name, ".")
             wildcard_domain = "*." <> Enum.join(rest, ".")
             Map.get(state.certs, wildcard_domain)
           end) do
        nil ->
          create_cert(common_name, certificate_gen, private_key_gen)

        {certificate, private_key} ->
          Logger.info(
            "using #{common_name} certificate (#{certificate}) and private key (#{private_key})"
          )

          wrap_fn({File.read!(certificate), File.read!(private_key)})
      end

    {:reply, reply, state}
  end

  def handle_info({:file_event, _watcher_pid, {path, events}}, state) do
    extname = Path.extname(path)

    if extname in [".crt", ".key"] and
         List.first(events) in [:created, :modified, :deleted] do
    end

    if state.tref do
      Process.cancel_timer(state.tref)
    end

    tref = Process.send_after(self(), :reload, 5000)
    {:noreply, %{state | tref: tref}}
  end

  def handle_info(:reload, state) do
    certs = register_certs()

    {:noreply, %{state | certs: certs, tref: nil}}
  end

  defp register_certs do
    glob = Application.fetch_env!(:proxyconf, :downstream_tls_path) <> "/**/*.crt"

    Path.wildcard(glob)
    |> Enum.reduce(%{}, fn p, acc ->
      register_cert(p)
      |> Map.merge(acc)
    end)
  end

  defp register_cert(cert_path) do
    import X509.ASN1

    extname = Path.extname(cert_path)
    key_path = String.replace_suffix(cert_path, extname, ".key")

    with {:ok, cert} <- File.read(cert_path),
         {_, _, {:ok, pk}} <- {:private_key, key_path, File.read(key_path)},
         {:ok, cert} <- X509.Certificate.from_pem(cert),
         {:ok, _pk} <- X509.PrivateKey.from_pem(pk),
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
      |> Map.new(fn san -> {List.to_string(san), {cert_path, key_path}} end)
      |> Map.put(common_name, {cert_path, key_path})
    else
      {:validity, t, _} ->
        Logger.warning(
          "Certificate #{cert_path} is not used as it doesn't match the validity constraint '#{t}'"
        )

        %{}

      {:private_key, key_path, {:error, reason}} ->
        Logger.error(
          "Can't register certificate #{cert_path} due to issues with private key #{key_path}: #{inspect(reason)}"
        )

        %{}

      {:error, reason} ->
        Logger.error("Can't register certificate #{cert_path} due to #{inspect(reason)}")
        %{}

      e ->
        Logger.error("Can't register certificate #{cert_path} due to #{inspect(e)}")
        %{}
    end
  end

  defp ca_setup do
    ca_certificate = Application.fetch_env!(:proxyconf, :ca_certificate)
    ca_private_key = Application.fetch_env!(:proxyconf, :ca_private_key)

    if not File.exists?(ca_certificate) or not File.exists?(ca_private_key) do
      File.mkdir_p!(Path.dirname(ca_certificate))
      File.mkdir_p!(Path.dirname(ca_private_key))

      pk = X509.PrivateKey.new_ec(:secp256r1)

      cert = X509.Certificate.self_signed(pk, "/CN=#{@ca_subject}", template: :root_ca)

      File.write!(ca_certificate, X509.Certificate.to_pem(cert), [:exclusive])
      File.chmod!(ca_certificate, 0o444)
      File.write!(ca_private_key, X509.PrivateKey.to_pem(pk), [:exclusive])
      File.chmod!(ca_private_key, 0o400)

      Logger.warning(
        "created selfsigned issuer certificate (#{ca_certificate}) and private key (#{ca_private_key}), unless the certificate and private key aren't made available to all other ProxyConf nodes, this only works in single node ProxyConf setup (NOT RECOMMENDED!)."
      )
    else
      Logger.info(
        "using issuer certificate (#{ca_certificate}) and private key (#{ca_private_key})"
      )
    end
  end

  defp control_plane_server_cert_setup do
    cert_setup(
      @control_plane_subject,
      Application.get_env(:proxyconf, :control_plane_certificate),
      Application.get_env(:proxyconf, :control_plane_private_key)
    )
  end

  defp control_plane_client_cert_setup do
    downstream_tls_path = Application.fetch_env!(:proxyconf, :downstream_tls_path)

    cert_setup(
      @client_subject,
      Path.join(downstream_tls_path, "client.crt"),
      Path.join(downstream_tls_path, "client.key")
    )
  end

  def server_cert(hostname) do
    downstream_tls_path = Application.fetch_env!(:proxyconf, :downstream_tls_path)

    cert_setup(
      hostname,
      Path.join(downstream_tls_path, hostname <> ".crt"),
      Path.join(downstream_tls_path, hostname <> ".key")
    )
  end

  def cert_setup(hostname, certificate, private_key) do
    GenServer.call(
      __MODULE__,
      {:get_matching_certificate, hostname, certificate, private_key},
      :infinity
    )
  end

  defp create_cert(hostname, certificate, private_key) do
    subject = "/CN=#{hostname}"
    ca_certificate = Application.get_env(:proxyconf, :ca_certificate)
    ca_private_key = Application.get_env(:proxyconf, :ca_private_key)
    File.mkdir_p!(Path.dirname(certificate))
    File.mkdir_p!(Path.dirname(private_key))

    issuer_cert = File.read!(ca_certificate) |> X509.Certificate.from_pem!()
    issuer_key = File.read!(ca_private_key) |> X509.PrivateKey.from_pem!()

    key = X509.PrivateKey.new_ec(:secp256r1)
    pub = X509.PublicKey.derive(key)

    [common_name] =
      X509.RDNSequence.new(subject)
      |> X509.RDNSequence.get_attr(:commonName)

    import X509.Certificate.Extension

    template = %X509.Certificate.Template{
      # 1 year, plus a 30 days grace period
      validity: 365 + 30,
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

    crt = X509.Certificate.new(pub, subject, issuer_cert, issuer_key, template: template)

    private_key_pem = X509.PrivateKey.to_pem(key)
    File.write!(private_key, private_key_pem, [:exclusive])
    File.chmod!(private_key, 0o400)

    certificate_pem = X509.Certificate.to_pem(crt)
    File.write!(certificate, certificate_pem, [:exclusive])
    File.chmod!(certificate, 0o444)

    Logger.info(
      "created selfsigned #{subject} certificate (#{certificate}) and private key (#{private_key})"
    )

    wrap_fn({certificate_pem, private_key_pem})
  end

  defp wrap_fn(res), do: fn -> res end
end
