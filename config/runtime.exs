import Config

if Config.config_env() in [:test, :dev] and File.exists?(".proxyconf.env") do
  DotenvParser.load_file(".proxyconf.env")
end

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
    String.to_integer(System.get_env("PROXYCONF_MGMT_API_PORT") || "4000")
  end

proxyconf_hostname = System.get_env("PROXYCONF_HOSTNAME") || "localhost"

config :proxyconf, :hostname, proxyconf_hostname
config :proxyconf, :mgmt_api_port, mgmt_api_port

if config_env() == :prod do
  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: openssl rand 32 | base64
      """

  System.get_env("DB_ENCRYPTION_KEY") ||
    raise """
    environment variable DB_ENCRYPTION_KEY is missing.
    You can generte one by calling: openssl rand 32 | base64
    """

  config :proxyconf, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

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

database_url =
  System.get_env("PROXYCONF_DATABASE_URL") ||
    raise """
    environment variable PROXYCONF_DATABASE_URL is missing.
    For example: ecto://USER:PASS@HOST/DATABASE
    """

maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

downstream_tls_path = System.get_env("PROXYCONF_SERVER_DOWNSTREAM_TLS_PATH", "/tmp/proxyconf")

control_plane_ca_certificate =
  System.get_env("PROXYCONF_CA_CERTIFICATE") ||
    raise "environment variable PROXYCONF_CA_CERTIFICATE is missing!"

File.exists?(control_plane_ca_certificate) ||
  raise "File stored in environment variable PROXYCONF_CA_CERTIFICATE does not exist or is not accessible by ProxyConf"

control_plane_certificate =
  System.get_env("PROXYCONF_CONTROL_PLANE_CERTIFICATE") ||
    raise "environment variable PROXYCONF_CONTROL_PLANE_CERTIFICATE is missing!"

File.exists?(control_plane_certificate) ||
  raise "File stored in environment variable PROXYCONF_CONTROL_PLANE_CERTIFICATE does not exist or is not accessible by ProxyConf"

control_plane_key =
  System.get_env("PROXYCONF_CONTROL_PLANE_PRIVATE_KEY") ||
    raise "environment variable PROXYCONF_CONTROL_PLANE_PRIVATE_KEY is missing!"

File.exists?(control_plane_key) ||
  raise "File stored in environment variable PROXYCONF_CONTROL_PLANE_PRIVATE_KEY does not exist or is not accessible by ProxyConf"

mgmt_api_ca_certificate =
  System.get_env("PROXYCONF_MGMT_API_CA_CERTIFICATE", control_plane_ca_certificate)

File.exists?(mgmt_api_ca_certificate) ||
  raise "File stored in environment variable PROXYCONF_MGMT_API_CA_CERTIFICATE does not exist or is not accessible by ProxyConf"

mgmt_api_certificate =
  System.get_env("PROXYCONF_MGMT_API_CERTIFICATE", control_plane_certificate)

File.exists?(mgmt_api_certificate) ||
  raise "File stored in environment variable PROXYCONF_MGMT_API_CERTIFICATE does not exist or is not accessible by ProxyConf"

mgmt_api_key =
  System.get_env("PROXYCONF_MGMT_API_PRIVATE_KEY", control_plane_key)

File.exists?(mgmt_api_key) ||
  raise "File stored in environment variable PROXYCONF_MGMT_API_PRIVATE_KEY does not exist or is not accessible by ProxyConf"

upstream_ca_bundle =
  System.get_env("PROXYCONF_UPSTREAM_CA_BUNDLE") ||
    raise "environment variable PROXYCONF_UPSTREAM_CA_BUNDLE is missing!"

File.exists?(upstream_ca_bundle) ||
  raise "File stored in environment variable PROXYCONF_UPSTREAM_CA_BUNDLE does not exist or is not accessible by ProxyConf"

mgmt_api_jwt_signer_key = System.get_env("PROXYCONF_MGMT_API_JWT_SIGNER_KEY", mgmt_api_key)

File.exists?(mgmt_api_jwt_signer_key) ||
  raise "File stored in environment variable PROXYCONF_MGMT_API_JWT_SIGNER_KEY does not exist or is not accessible by ProxyConf"

certificate_issuer_cert = System.fetch_env!("PROXYCONF_CERTIFICATE_ISSUER_CERT")

File.exists?(certificate_issuer_cert) ||
  raise "File stored in environment variable PROXYCONF_CERTIFICATE_ISSUER_CERT does not exist or is not accessible by ProxyConf"

certificate_issuer_key = System.fetch_env!("PROXYCONF_CERTIFICATE_ISSUER_KEY")

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
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  socket_options: maybe_ipv6

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

config :proxyconf, ProxyConf.GRPC.Credential,
  ssl: [
    certfile: Path.absname(control_plane_certificate),
    keyfile: Path.absname(control_plane_key),
    cacertfile: Path.absname(control_plane_ca_certificate),
    verify: :verify_peer,
    fail_if_no_peer_cert: true
  ]

config :proxyconf, ProxyConf.OAuth.JwtSigner,
  keyfile: Path.absname(mgmt_api_jwt_signer_key),
  kid: "proxyconf",
  issuer: "proxyconf"

config :proxyconf,
  grpc_endpoint_port:
    System.get_env("PROXYCONF_GRPC_ENDPOINT_PORT", "18000") |> String.to_integer(),
  #  config_extensions:
  #    System.get_env("PROXYCONF_CONFIG_EXTENSIONS", "Elixir.ProxyConfValidator.Store")
  #    |> String.split(",", trim: true)
  #    |> Enum.map(fn module -> {String.to_atom(module), :config_extension} end),
  #  external_spec_handlers:
  #    System.get_env("PROXYCONF_EXTERNAL_SPEC_HANDLERS", "Elixir.ProxyConfValidator.Store")
  #    |> String.split(",", trim: true)
  #    |> Enum.map(fn module -> {String.to_atom(module), :handle_spec} end),
  # upstream_ca_bundle must point to cert bundle that the envoy process has access to
  upstream_ca_bundle: upstream_ca_bundle,
  mgmt_api_ca_certificate: mgmt_api_ca_certificate

# config :proxyconf_validator,
#  http_endpoint_name: System.get_env("PROXYCONF_VALIDATOR_HTTP_ENDPOINT_NAME", "localhost"),
#  http_endpoint_port:
#    System.get_env("PROXYCONF_VALIDATOR_HTTP_ENDPOINT_PORT", "19000") |> String.to_integer()
config :proxyconf, ProxyConf.Cron,
  jobs:
    System.get_env("PROXYCONF_CRONTAB", Path.join(:code.priv_dir(:proxyconf), "crontab"))
    |> File.read()
    |> ProxyConf.Cron.to_config()
