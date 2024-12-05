import Config

# Configure your database
config :proxyconf, ProxyConf.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :proxyconf, ProxyConfWeb.Endpoint,
  https: [port: 4002],
  secret_key_base: "dJfSBc9SJvihaGuOREDm2P6UQrST8z4qum6XCnf/i4XIYEPTF7VtfE9q5KrEyg1Q"

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
