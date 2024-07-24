defmodule ApiFence.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  @ca_subject "/CN=API-Fence self-signed issuer"
  @server_subject "/CN=API-Fence control plane"
  @client_subject "/CN=API-Fence client"

  def ca_setup do
    ca_certificate = Application.get_env(:api_fence, :ca_certificate)
    ca_private_key = Application.get_env(:api_fence, :ca_private_key)

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
        "created selfsigned issuer certificate, this only works in single node cluster setup"
      )
    end
  end

  def server_cert_setup do
    server_certificate = Application.get_env(:api_fence, :server_certificate)
    server_private_key = Application.get_env(:api_fence, :server_private_key)
    cert_setup(@server_subject, server_certificate, server_private_key)
  end

  def client_cert_setup do
    cert_setup(@client_subject, "/tmp/api-fence/client-cert.pem", "/tmp/api-fence/client-key.pem")
  end

  def cert_setup(subject, certificate, private_key) do
    ca_certificate = Application.get_env(:api_fence, :ca_certificate)
    ca_private_key = Application.get_env(:api_fence, :ca_private_key)

    if not File.exists?(certificate) or not File.exists?(private_key) do
      File.mkdir_p!(Path.dirname(certificate))
      File.mkdir_p!(Path.dirname(private_key))

      issuer_cert = File.read!(ca_certificate) |> X509.Certificate.from_pem!()
      issuer_key = File.read!(ca_private_key) |> X509.PrivateKey.from_pem!()

      key = X509.PrivateKey.new_ec(:secp256r1)
      pub = X509.PublicKey.derive(key)

      [commonName] =
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
          subject_alt_name: subject_alt_name([commonName])
        ]
      }

      crt = X509.Certificate.new(pub, subject, issuer_cert, issuer_key, template: template)

      File.write!(private_key, X509.PrivateKey.to_pem(key), [:exclusive])
      File.chmod!(private_key, 0o400)

      File.write!(certificate, X509.Certificate.to_pem(crt), [:exclusive])
      File.chmod!(certificate, 0o444)

      Logger.info("created selfsigned #{subject} certificate")
    end
  end

  @impl true
  def start(_type, _args) do
    ca_setup()
    server_cert_setup()
    client_cert_setup()

    children = [
      # Starts a worker by calling: ApiFence.Worker.start_link(arg)
      # {ApiFence.Worker, arg}
      # {GRPC.Server.Supervisor, endpoint: ApiFence.Endpoint, port: 4040, start_server: true},
      ApiFence.ConfigCache,
      {GRPC.Server.Supervisor,
       endpoint: ApiFence.Endpoint,
       port: Application.fetch_env!(:api_fence, :grpc_endpoint_port),
       start_server: true,
       cred:
         GRPC.Credential.new(
           ssl: [
             certfile: Application.get_env(:api_fence, :server_certificate),
             keyfile: Application.get_env(:api_fence, :server_private_key),
             cacertfile: Application.get_env(:api_fence, :ca_certificate),
             secure_renegotiate: true,
             reuse_sessions: true,
             verify: :verify_peer,
             fail_if_no_peer_cert: true
           ]
         )}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ApiFence.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
