defmodule ProxyConf.ConfigGenerator.RouteConfiguration do
  @moduledoc """
    This module implements the config generator for the route configuration
  """
  use ProxyConf.MapTemplate

  deftemplate(%{
    "virtual_hosts" => :virtual_hosts,
    "name" => :name,
    "internal_only_headers" => ["x-proxyconf-api-id"]
  })

  def from_spec_gen(_spec) do
    fn %{host: vhost_name, listener: listener_name}, [vhost] ->
      %{name: name(listener_name, vhost_name), virtual_hosts: [vhost]} |> eval()
    end
  end

  def name(listener_name, vhost) do
    "#{listener_name}::#{vhost}"
  end
end
