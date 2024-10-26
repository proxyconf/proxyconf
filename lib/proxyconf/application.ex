defmodule ProxyConf.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      ProxyConf.LocalCA,
      ProxyConf.LocalJwtProvider,
      ProxyConf.Cron,
      DynamicSupervisor.child_spec(name: ProxyConf.StreamSupervisor),
      Registry.child_spec(keys: :unique, name: ProxyConf.StreamRegistry),
      ProxyConf.ConfigCache,
      {GRPC.Server.Supervisor,
       endpoint: ProxyConf.Endpoint,
       port: Application.fetch_env!(:proxyconf, :grpc_endpoint_port),
       start_server: true,
       cred:
         GRPC.Credential.new(
           ssl: [
             certfile: Application.fetch_env!(:proxyconf, :control_plane_certificate),
             keyfile: Application.fetch_env!(:proxyconf, :control_plane_private_key),
             cacertfile: Application.fetch_env!(:proxyconf, :ca_certificate),
             secure_renegotiate: true,
             reuse_sessions: true,
             verify: :verify_peer,
             fail_if_no_peer_cert: true
           ]
         )},
      {Plug.Cowboy, scheme: :http, plug: ProxyConf.Http, port: 4040}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ProxyConf.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
