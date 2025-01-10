defmodule ProxyConf.Commons.Gen.RouteConfiguration do
  @moduledoc """
    This module implements the config generator for the route configuration
  """

  def from_spec_gen(_spec) do
    {&generate/3, %{}}
  end

  defp generate(%{host: vhost_name, listener: listener_name}, vhosts, _context) do
    %{
      "virtual_hosts" => vhosts,
      "name" => name(listener_name, vhost_name),
      "internal_only_headers" => ["x-proxyconf-api-id"]
    }
  end

  def name(listener_name, vhost) do
    "#{listener_name}::#{vhost}"
  end
end
