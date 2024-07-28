import Config

config :api_fence,
  config_directories:
    System.get_env("API_FENCE_CONFIG_DIRS", "test/oas3") |> String.split(",", trim: true),
  grpc_endpoint_port:
    System.get_env("API_FENCE_GRPC_ENDPOINT_PORT", "18000") |> String.to_integer(),
  config_extensions:
    System.get_env("API_FENCE_CONFIG_EXTENSIONS", "Elixir.ApiFenceValidator.Store")
    |> String.split(",", trim: true)
    |> Enum.map(fn module -> {String.to_atom(module), :config_extension} end),
  external_spec_handlers:
    System.get_env("API_FENCE_EXTERNAL_SPEC_HANDLERS", "Elixir.ApiFenceValidator.Store")
    |> String.split(",", trim: true)
    |> Enum.map(fn module -> {String.to_atom(module), :handle_spec} end),
  ca_certificate: System.get_env("API_FENCE_CA_CERTIFICATE", "/tmp/api-fence/ca-cert.pem"),
  ca_private_key: System.get_env("API_FENCE_CA_PRIVATE_KEY", "/tmp/api-fence/ca-private-key.pem"),
  server_certificate:
    System.get_env("API_FENCE_SERVER_CERTIFICATE", "/tmp/api-fence/server-cert.pem"),
  server_private_key:
    System.get_env("API_FENCE_SERVER_PRIVATE_KEY", "/tmp/api-fence/server-private-key.pem")

config :api_fence_validator,
  http_endpoint_name: System.get_env("API_FENCE_VALIDATOR_HTTP_ENDPOINT_NAME", "localhost"),
  http_endpoint_port:
    System.get_env("API_FENCE_VALIDATOR_HTTP_ENDPOINT_PORT", "19000") |> String.to_integer()
