import Config

config :proxyconf,
  config_directories:
    System.get_env("PROXYCONF_CONFIG_DIRS", "") |> String.split(",", trim: true),
  grpc_endpoint_port:
    System.get_env("PROXYCONF_GRPC_ENDPOINT_PORT", "18000") |> String.to_integer(),
  config_extensions:
    System.get_env("PROXYCONF_CONFIG_EXTENSIONS", "Elixir.ProxyConfValidator.Store")
    |> String.split(",", trim: true)
    |> Enum.map(fn module -> {String.to_atom(module), :config_extension} end),
  external_spec_handlers:
    System.get_env("PROXYCONF_EXTERNAL_SPEC_HANDLERS", "Elixir.ProxyConfValidator.Store")
    |> String.split(",", trim: true)
    |> Enum.map(fn module -> {String.to_atom(module), :handle_spec} end),
  ca_certificate: System.get_env("PROXYCONF_CA_CERTIFICATE", "/tmp/proxyconf/ca-cert.pem"),
  ca_private_key: System.get_env("PROXYCONF_CA_PRIVATE_KEY", "/tmp/proxyconf/ca-private-key.pem"),
  server_certificate:
    System.get_env("PROXYCONF_SERVER_CERTIFICATE", "/tmp/proxyconf/server-cert.pem"),
  server_private_key:
    System.get_env("PROXYCONF_SERVER_PRIVATE_KEY", "/tmp/proxyconf/server-private-key.pem")

config :proxyconf_validator,
  http_endpoint_name: System.get_env("PROXYCONF_VALIDATOR_HTTP_ENDPOINT_NAME", "localhost"),
  http_endpoint_port:
    System.get_env("PROXYCONF_VALIDATOR_HTTP_ENDPOINT_PORT", "19000") |> String.to_integer()
