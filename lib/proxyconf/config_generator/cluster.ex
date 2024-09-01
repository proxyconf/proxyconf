defmodule ProxyConf.ConfigGenerator.Cluster do
  alias ProxyConf.ConfigGenerator.ClusterLbEndpoint
  use ProxyConf.MapTemplate

  deftemplate(%{
    "name" => :name,
    "connect_timeout" => %{"seconds" => 5},
    "type" => "STRICT_DNS",
    "lb_policy" => "ROUND_ROBIN",
    "http2_protocol_options" => %{
      # recommended config for untrusted upstreams
      "initial_connection_window_size" => 1_048_576.0,
      "initial_stream_window_size" => 65536.0
    },
    "load_assignment" => %{
      "cluster_name" => :name,
      "endpoints" => [
        %{
          "lb_endpoints" => :endpoints
        }
      ]
    }
  })

  def from_spec_gen(_spec) do
    fn clusters ->
      Enum.uniq(clusters)
      |> Enum.map(fn {cluster_name, cluster_uri} ->
        eval(%{
          name: cluster_name,
          endpoints: [ClusterLbEndpoint.eval(%{host: cluster_uri.host, port: cluster_uri.port})]
        })
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
                        "filename" => "/etc/ssl/certs/ca-certificates.crt"
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
        {"#{uri.host}:#{uri.port}", uri}
    end
  end
end
