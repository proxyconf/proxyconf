import Config
import Dotenvy

source(["#{config_env()}.env", "#{config_env()}.override.env", System.get_env()])

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/proxyconf start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically setsthe env var above.

mgmt_api_port =
  if config_env() == :test do
    4002
  else
    env!("PROXYCONF_MGMT_API_PORT", :integer, 4000)
  end

proxyconf_hostname = env!("PROXYCONF_HOSTNAME", :string, "localhost")

config :proxyconf, :hostname, proxyconf_hostname
config :proxyconf, :mgmt_api_port, mgmt_api_port

config :logger, :level, env!("PROXYCONF_LOG_LEVEL", :atom, :info)

config :logger, :console,
  format: env!("PROXYCONF_LOG_FORMAT", :string, "[$date $time][$level]$metadata $message\n")

if config_env() == :prod do
  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    env!("SECRET_KEY_BASE", :string, nil) ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: openssl rand 32 | base64
      """

  config :proxyconf, :dns_cluster_query, env!("DNS_CLUSTER_QUERY", :string, nil)

  config :proxyconf, ProxyConfWeb.Endpoint,
    url: [host: proxyconf_hostname, port: 443, scheme: "https"],
    https: [
      port: mgmt_api_port,
      protocol_options: [
        server_name: "ProxyConf"
      ]
    ],
    secret_key_base: secret_key_base
end

db_encryption_key =
  env!("PROXYCONF_DB_ENCRYPTION_KEY", :string, nil) ||
    raise """
    environment variable PROXYCONF_DB_ENCRYPTION_KEY is missing.
    You can generate one by calling: openssl rand 32 | base64
    """

database_url =
  env!("PROXYCONF_DATABASE_URL") ||
    raise """
    environment variable PROXYCONF_DATABASE_URL is missing.
    For example: ecto://USER:PASS@HOST/DATABASE
    """

maybe_ipv6 = if env!("ECTO_IPV6", :string, nil) in ~w(true 1), do: [:inet6], else: []

control_plane_ca_certificate =
  env!("PROXYCONF_CA_CERTIFICATE", :string, nil) ||
    raise "environment variable PROXYCONF_CA_CERTIFICATE is missing!"

File.exists?(control_plane_ca_certificate) ||
  raise "File stored in environment variable PROXYCONF_CA_CERTIFICATE does not exist or is not accessible by ProxyConf"

control_plane_certificate =
  env!("PROXYCONF_CONTROL_PLANE_CERTIFICATE", :string, nil) ||
    raise "environment variable PROXYCONF_CONTROL_PLANE_CERTIFICATE is missing!"

File.exists?(control_plane_certificate) ||
  raise "File stored in environment variable PROXYCONF_CONTROL_PLANE_CERTIFICATE does not exist or is not accessible by ProxyConf"

control_plane_key =
  env!("PROXYCONF_CONTROL_PLANE_PRIVATE_KEY", :string, nil) ||
    raise "environment variable PROXYCONF_CONTROL_PLANE_PRIVATE_KEY is missing!"

File.exists?(control_plane_key) ||
  raise "File stored in environment variable PROXYCONF_CONTROL_PLANE_PRIVATE_KEY does not exist or is not accessible by ProxyConf"

mgmt_api_ca_certificate =
  env!("PROXYCONF_MGMT_API_CA_CERTIFICATE", :string, control_plane_ca_certificate)

File.exists?(mgmt_api_ca_certificate) ||
  raise "File stored in environment variable PROXYCONF_MGMT_API_CA_CERTIFICATE does not exist or is not accessible by ProxyConf"

mgmt_api_certificate =
  env!("PROXYCONF_MGMT_API_CERTIFICATE", :string, control_plane_certificate)

File.exists?(mgmt_api_certificate) ||
  raise "File stored in environment variable PROXYCONF_MGMT_API_CERTIFICATE does not exist or is not accessible by ProxyConf"

mgmt_api_key =
  env!("PROXYCONF_MGMT_API_PRIVATE_KEY", :string, control_plane_key)

File.exists?(mgmt_api_key) ||
  raise "File stored in environment variable PROXYCONF_MGMT_API_PRIVATE_KEY does not exist or is not accessible by ProxyConf"

upstream_ca_bundle =
  env!("PROXYCONF_UPSTREAM_CA_BUNDLE", :string, nil) ||
    raise "environment variable PROXYCONF_UPSTREAM_CA_BUNDLE is missing!"

File.exists?(upstream_ca_bundle) ||
  raise "File stored in environment variable PROXYCONF_UPSTREAM_CA_BUNDLE does not exist or is not accessible by ProxyConf"

mgmt_api_jwt_signer_key = env!("PROXYCONF_MGMT_API_JWT_SIGNER_KEY", :string, mgmt_api_key)

File.exists?(mgmt_api_jwt_signer_key) ||
  raise "File stored in environment variable PROXYCONF_MGMT_API_JWT_SIGNER_KEY does not exist or is not accessible by ProxyConf"

certificate_issuer_cert = env!("PROXYCONF_CERTIFICATE_ISSUER_CERT", :string)

File.exists?(certificate_issuer_cert) ||
  raise "File stored in environment variable PROXYCONF_CERTIFICATE_ISSUER_CERT does not exist or is not accessible by ProxyConf"

certificate_issuer_key = env!("PROXYCONF_CERTIFICATE_ISSUER_KEY", :string)

File.exists?(certificate_issuer_key) ||
  raise "File stored in environment variable PROXYCONF_CERTIFICATE_ISSUER_KEY does not exist or is not accessible by ProxyConf"

config :proxyconf, ProxyConf.LocalCA,
  cache_reload_interval: 300_000,
  validity_days: 2,
  rotation_period_hours: 24,
  issuer_cert: certificate_issuer_cert,
  issuer_key: certificate_issuer_key

config :proxyconf, ProxyConf.Repo,
  # ssl: true,
  url: database_url,
  pool_size: env!("POOL_SIZE", :integer, 10),
  socket_options: maybe_ipv6

config :proxyconf, ProxyConf.Vault, encryption_key_fn: fn -> db_encryption_key end

config :proxyconf, ProxyConfWeb.Endpoint,
  server: true,
  https: [
    ip: {0, 0, 0, 0},
    port: mgmt_api_port,
    keyfile: Path.absname(mgmt_api_key),
    certfile: Path.absname(mgmt_api_certificate),
    cacertfile: Path.absname(mgmt_api_ca_certificate),
    cipher_suite: :strong,
    secure_renegotiate: true,
    reuse_sessions: true,
    protocol_options: [
      server_name: "ProxyConf"
    ]
  ]

config :ex_control_plane, :adapter_mod, ProxyConf.Adapter

config :ex_control_plane,
       :grpc_endpoint_port,
       env!("PROXYCONF_GRPC_ENDPOINT_PORT", :integer, 18000)

config :ex_control_plane, :grpc_server_opts,
  cred:
    GRPC.Credential.new(
      ssl: [
        certfile: Path.absname(control_plane_certificate),
        keyfile: Path.absname(control_plane_key),
        cacertfile: Path.absname(control_plane_ca_certificate),
        verify: :verify_peer,
        fail_if_no_peer_cert: true
      ]
    )

config :proxyconf, ProxyConf.OAuth.JwtSigner,
  keyfile: Path.absname(mgmt_api_jwt_signer_key),
  kid: "proxyconf",
  issuer: "proxyconf"

config :proxyconf,
  #  config_extensions:
  #    env!("PROXYCONF_CONFIG_EXTENSIONS", "Elixir.ProxyConfValidator.Store")
  #    |> String.split(",", trim: true)
  #    |> Enum.map(fn module -> {String.to_atom(module), :config_extension} end),
  #  external_spec_handlers:
  #    env!("PROXYCONF_EXTERNAL_SPEC_HANDLERS", "Elixir.ProxyConfValidator.Store")
  #    |> String.split(",", trim: true)
  #    |> Enum.map(fn module -> {String.to_atom(module), :handle_spec} end),
  # upstream_ca_bundle must point to cert bundle that the envoy process has access to
  upstream_ca_bundle: upstream_ca_bundle,
  mgmt_api_ca_certificate: mgmt_api_ca_certificate

# config :proxyconf_validator,
#  http_endpoint_name: env!("PROXYCONF_VALIDATOR_HTTP_ENDPOINT_NAME", "localhost"),
#  http_endpoint_port:
#    env!("PROXYCONF_VALIDATOR_HTTP_ENDPOINT_PORT", "19000") |> String.to_integer()

config :proxyconf_commons,
  default_api_port: mgmt_api_port,
  default_downstream_security_auth: %{
    "type" => "jwt",
    "provider-config" => %{
      "issuer" => "proxyconf",
      "audiences" => ["demo"],
      "forward" => false,
      "remote_jwks" => %{
        "http_uri" => %{
          "uri" => "https://127.0.0.1:#{mgmt_api_port}/api/jwks.json",
          "timeout" => "1s"
        },
        "cache_duration" => %{
          "seconds" => 300
        }
      }
    }
  },
  default_upstream_ca_bundle: upstream_ca_bundle,
  upstream_ca_bundle_resolver: fn %URI{host: host, port: port} ->
    case {mgmt_api_port, proxyconf_hostname} do
      {^port, ^host} ->
        %{"filename" => Path.absname(mgmt_api_ca_certificate)}

      {^port, "localhost"} ->
        %{"filename" => Path.absname(mgmt_api_ca_certificate)}

      _ ->
        %{"filename" => upstream_ca_bundle}
    end
  end
