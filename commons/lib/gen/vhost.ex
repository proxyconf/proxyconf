defmodule ProxyConf.Commons.Gen.VHost do
  @moduledoc """
    This module implements a config generator for the VHost used as part of XDS/LDS
  """

  def from_spec_gen(spec) do
    [host | _] = server_names = to_server_names(spec.api_url)
    {&generate/2, %{host: host, domains: server_names}}
  end

  defp generate(routes, context) do
    %{
      "name" => context.host,
      "domains" => context.domains,
      "routes" => routes
    }
  end

  def server_names(%{"domains" => domains}) do
    domains
  end

  defp to_server_names(%URI{host: host, port: port}) do
    [host, "#{host}:#{port}"]
  end
end
