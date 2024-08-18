defmodule ProxyConf.LocalCA do
  require Logger
  @ca_subject "/CN=ProxyConf self-signed issuer"
  @control_plane_subject "/CN=ProxyConf control plane"
  @client_subject "/CN=ProxyConf client"

  @doc """
    Setting up a self signed certificate authority. This isn't build for production usage.
  """
  def ca_setup do
    ca_certificate = Application.get_env(:proxyconf, :ca_certificate)
    ca_private_key = Application.get_env(:proxyconf, :ca_private_key)

    if not File.exists?(ca_certificate) or not File.exists?(ca_private_key) do
      File.mkdir_p!(Path.dirname(ca_certificate))
      File.mkdir_p!(Path.dirname(ca_private_key))

      pk = X509.PrivateKey.new_ec(:secp256r1)

      cert = X509.Certificate.self_signed(pk, @ca_subject, template: :root_ca)

      File.write!(ca_certificate, X509.Certificate.to_pem(cert), [:exclusive])
      File.chmod!(ca_certificate, 0o444)
      File.write!(ca_private_key, X509.PrivateKey.to_pem(pk), [:exclusive])
      File.chmod!(ca_private_key, 0o400)

      Logger.warning(
        "created selfsigned issuer certificate (#{ca_certificate}) and private key (#{ca_private_key}), this only works in single node cluster setup"
      )
    else
      Logger.info(
        "using issuer certificate (#{ca_certificate}) and private key (#{ca_private_key})"
      )
    end
  end

  def control_plane_server_cert_setup do
    server_certificate = Application.get_env(:proxyconf, :control_plane_certificate)
    server_private_key = Application.get_env(:proxyconf, :control_plane_private_key)
    cert_setup(@control_plane_subject, server_certificate, server_private_key)
  end

  def control_plane_client_cert_setup do
    downstream_tls_path = Application.fetch_env!(:proxyconf, :downstream_tls_path)

    cert_setup(
      @client_subject,
      Path.join(downstream_tls_path, "client-cert.pem"),
      Path.join(downstream_tls_path, "client-key.pem")
    )
  end

  def server_cert(hostname) do
    downstream_tls_path = Application.fetch_env!(:proxyconf, :downstream_tls_path)

    cert_setup(
      "/CN=#{hostname}",
      Path.join(downstream_tls_path, hostname <> ".crt"),
      Path.join(downstream_tls_path, hostname <> ".key")
    )
  end

  def cert_setup(subject, certificate, private_key) do
    ca_certificate = Application.get_env(:proxyconf, :ca_certificate)
    ca_private_key = Application.get_env(:proxyconf, :ca_private_key)

    if not File.exists?(certificate) or not File.exists?(private_key) do
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
    else
      Logger.info(
        "using #{subject} certificate (#{certificate}) and private key (#{private_key})"
      )

      wrap_fn({File.read!(certificate), File.read!(private_key)})
    end
  end

  defp wrap_fn(res), do: fn -> res end
end
