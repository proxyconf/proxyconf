defmodule ProxyConf.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    children =
      [
        ProxyConf.Vault,
        ProxyConf.Repo,
        {ProxyConf.LocalCA, Application.fetch_env!(:proxyconf, ProxyConf.LocalCA)},
        {ProxyConf.OAuth.JwtSigner,
         Application.fetch_env!(:proxyconf, ProxyConf.OAuth.JwtSigner)},
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
           Application.fetch_env!(:proxyconf, ProxyConf.GRPC.Credential)
           |> GRPC.Credential.new()},
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
