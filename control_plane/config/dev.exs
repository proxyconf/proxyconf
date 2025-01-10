import Config

# Configure your database
config :proxyconf, ProxyConf.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "proxyconf_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# For development, we disable any cache and enable
# debugging and code reloading.
# The watchers configuration can be used to run external
# watchers to your application. For example, we can use it
# to bundle .js and .css sources.
config :proxyconf, ProxyConfWeb.Endpoint,
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "hy/t4F8nirnZb2OCEls4b7Uqr6adfG2tqtdvX7ITsUKnUf7SqoptEka57IgmtjF8",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:proxyconf, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:proxyconf, ~w(--watch)]}
  ]

# Watch static and templates for browser reloading.
config :proxyconf, ProxyConfWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/proxyconf_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# Enable dev routes for dashboard and mailbox
config :proxyconf, dev_routes: true

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  # Include HEEx debug annotations as HTML comments in rendered markup
  debug_heex_annotations: true,
  # Enable helpful, but potentially expensive runtime checks
  enable_expensive_runtime_checks: true
