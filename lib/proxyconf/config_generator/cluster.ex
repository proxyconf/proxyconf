defmodule ProxyConf.ConfigGenerator.Cluster do
  alias ProxyConf.ConfigGenerator.ClusterLbEndpoint
  use ProxyConf.MapTemplate

  deftemplate(%{
    "name" => :name,
    "connect_timeout" => "0.25s",
    "type" => "STRICT_DNS",
    "lb_policy" => "ROUND_ROBIN",
    "load_assignment" => %{
      "cluster_name" => :name,
      "endpoints" => [
        %{
          "lb_endpoints" => :endpoints
        }
      ]
    }
  })

  def from_spec_gen(spec) do
    fn clusters ->
      Enum.uniq(clusters)
      |> Enum.map(fn {cluster_name, cluster_uri} ->
        eval(%{
          name: cluster_name,
          endpoints: [ClusterLbEndpoint.eval(%{host: cluster_uri.host, port: cluster_uri.port})]
        })
      end)
    end
  end

  def cluster_uri_from_oas3_server(api_id, server) do
    url = Map.fetch!(server, "url")

    url =
      Map.get(server, "variables", %{})
      |> Enum.reduce(url, fn {var_name, %{"default" => default}}, acc_url ->
        String.replace(acc_url, "{#{var_name}}", default)
      end)

    # - url: "{protocol}://{hostname}"
    case URI.parse(url) do
      %URI{host: nil} ->
        raise("invalid upstream server hostname in server url '#{server}'")

      %URI{port: nil} ->
        raise("invalid upstream server port in server url '#{server}'")

      %URI{} = uri ->
        {"#{api_id}::#{uri.host}:#{uri.port}", uri}
    end
  end
end
