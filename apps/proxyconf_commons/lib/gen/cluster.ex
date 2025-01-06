defmodule ProxyConf.Commons.Gen.Cluster do
  @moduledoc """
    Thid module implements the cluster resource.
  """
  alias ProxyConf.Commons.Gen.ClusterLbEndpoint

  def from_spec_gen(_spec) do
    {&generate/2, %{}}
  end

  defp generate(clusters, _context) do
    Enum.uniq(clusters)
    |> Enum.map(fn {cluster_name, cluster_uri} ->
      %{
        "name" => cluster_name,
        "type" => "STRICT_DNS",
        "lb_policy" => "ROUND_ROBIN",
        "load_assignment" => %{
          "cluster_name" => cluster_name,
          "endpoints" => [
            %{
              "lb_endpoints" => [
                ClusterLbEndpoint.eval(%{host: cluster_uri.host, port: cluster_uri.port})
              ]
            }
          ]
        }
      }
      |> Map.merge(
        if cluster_uri.scheme == "https" do
          %{
            "transport_socket" => %{
              "name" => "envoy.transport_sockets.tls",
              "typed_config" => %{
                "@type" =>
                  "type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext",
                "sni" => cluster_uri.host,
                "common_tls_context" => %{
                  "validation_context" => %{
                    "trusted_ca" => %{
                      "filename" =>
                        if mgmt_api?(cluster_uri) do
                          Application.fetch_env!(:proxyconf, :mgmt_api_ca_certificate)
                        else
                          Application.fetch_env!(:proxyconf, :upstream_ca_bundle)
                        end
                    }
                  }
                }
              }
            }
          }
        else
          %{}
        end
      )
    end)
  end

  defp mgmt_api?(%URI{host: host, port: port}) do
    case {Application.fetch_env!(:proxyconf, :mgmt_api_port),
          Application.fetch_env!(:proxyconf, :hostname)} do
      {^port, ^host} -> true
      {^port, "localhost"} when host == "127.0.0.1" -> true
      _ -> false
    end
  end

  def cluster_uri_from_oas3_server(_api_id, server) do
    url = Map.fetch!(server, "url")

    url =
      Map.get(server, "variables", %{})
      |> Enum.reduce(url, fn {var_name, %{"default" => default}}, acc_url ->
        String.replace(acc_url, "{#{var_name}}", default)
      end)

    # - url: "{protocol}://{hostname}"
    case URI.parse(url) do
      %URI{host: nil} ->
        raise("invalid upstream server hostname in server url '#{url}'")

      %URI{port: nil} ->
        raise("invalid upstream server port in server url '#{url}'")

      %URI{} = uri ->
        {"#{uri.scheme}://#{uri.host}:#{uri.port}", uri}
    end
  end
end
