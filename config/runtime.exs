import Config

downstream_tls_path = System.get_env("PROXYCONF_SERVER_DOWNSTREAM_TLS_PATH", "/tmp/proxyconf")

config :proxyconf,
  config_directories:
    System.get_env("PROXYCONF_CONFIG_DIRS", "") |> String.split(",", trim: true),
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
  ca_certificate:
    System.get_env("PROXYCONF_CA_CERTIFICATE", Path.join(downstream_tls_path, "ca-cert.pem")),
  ca_private_key:
    System.get_env(
      "PROXYCONF_CA_PRIVATE_KEY",
      Path.join(downstream_tls_path, "ca-private-key.pem")
    ),
  control_plane_certificate:
    System.get_env(
      "PROXYCONF_CONTROL_PLANE_CERTIFICATE",
      Path.join(downstream_tls_path, "proxyconf-ctrlplane.crt")
    ),
  control_plane_private_key:
    System.get_env(
      "PROXYCONF_CONTROL_PLANE_PRIVATE_KEY",
      Path.join(downstream_tls_path, "proxyconf-ctrlplane.key")
    ),
  downstream_tls_path: downstream_tls_path,
  # At this point it is expected that the following CA Bundle is available in the Envoy container
  upstream_ca_bundle:
    System.get_env("PROXYCONF_UPSTREAM_CA_BUNDLE", "/etc/ssl/certs/ca-certificates.crt")

# config :proxyconf_validator,
#  http_endpoint_name: System.get_env("PROXYCONF_VALIDATOR_HTTP_ENDPOINT_NAME", "localhost"),
#  http_endpoint_port:
#    System.get_env("PROXYCONF_VALIDATOR_HTTP_ENDPOINT_PORT", "19000") |> String.to_integer()
config :proxyconf, ProxyConf.Cron,
  jobs: System.get_env("PROXYCONF_CRONTAB") |> File.read() |> ProxyConf.Cron.to_config()
