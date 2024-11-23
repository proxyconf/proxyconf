defmodule ProxyConf.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      ProxyConf.Repo,
      ProxyConf.LocalCA,
      ProxyConf.LocalJwtProvider,
      ProxyConf.OAuth.JwtSigner,
      ProxyConf.Cron,
      DynamicSupervisor.child_spec(name: ProxyConf.StreamSupervisor),
      Registry.child_spec(keys: :unique, name: ProxyConf.StreamRegistry),
      ProxyConf.ConfigCache,
      ProxyConfWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:proxyconf, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ProxyConf.PubSub},
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
      ProxyConfWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ProxyConf.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ProxyConfWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
