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
                    "trusted_ca" => upstream_ca_bundle(cluster_uri)
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

  defp upstream_ca_bundle(cluster_uri) do
    resolver =
      Application.get_env(
        :proxyconf_commons,
        :upstream_ca_bundle_resolver,
        &local_bundle_resolver/1
      )

    resolver.(cluster_uri)
  end

  def local_bundle_resolver(_uri) do
    %{"filename" => Application.fetch_env!(:proxyconf_commons, :default_upstream_ca_bundle)}
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
