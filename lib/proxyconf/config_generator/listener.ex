defmodule ProxyConf.ConfigGenerator.Listener do
  use ProxyConf.MapTemplate
  alias ProxyConf.ConfigGenerator.DownstreamAuth
  alias ProxyConf.ConfigGenerator.DownstreamTls

  deftemplate(%{
    "name" => :listener_name,
    "address" => %{
      "socket_address" => %{
        "address" => :address,
        "port_value" => :port
      }
    },
    "filter_chains" => [
      %{
        "transport_socket" => :transport_socket,
        "filters" => [
          %{
            "name" => "envoy.filters.network.http_connection_manager",
            "typed_config" => %{
              "@type" =>
                "type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager",
              "stat_prefix" => "proxyconf",
              "codec_type" => "AUTO",
              "strip_matching_host_port" => true,
              "rds" => %{
                "config_source" => %{
                  "ads" => %{},
                  "resource_api_version" => "V3"
                },
                "route_config_name" => :listener_name
              },
              # "route_config" => %{
              #  "name" => "local_route",
              #  "virtual_hosts" => :virtual_hosts
              # },
              "http_filters" =>
                [
                  :downstream_auth,
                  %{
                    "name" => "envoy.filters.http.router",
                    "typed_config" => %{
                      "@type" =>
                        "type.googleapis.com/envoy.extensions.filters.http.router.v3.Router"
                    }
                  }
                ]
                |> List.flatten()
            }
          }
        ]
      }
    ]
  })

  def name(spec) do
    "#{spec.listener_address}:#{spec.listener_port}"
  end

  def from_spec_gen(spec) do
    listener_name = name(spec)

    fn vhosts, downstream_auth, downstream_tls ->
      {downstream_auth_listener_config, downstream_auth_cluster_config} =
        DownstreamAuth.to_envoy_http_filter(downstream_auth)

      transport_socket = DownstreamTls.to_envoy_transport_socket(downstream_tls)

      %{"filter_chains" => filter_chains} =
        listener =
        %{
          listener_name: listener_name,
          address: spec.listener_address,
          port: spec.listener_port,
          virtual_hosts: vhosts,
          transport_socket: transport_socket,
          downstream_auth: downstream_auth_listener_config
        }
        |> eval()

      filter_chains =
        Enum.map(filter_chains, fn %{"transport_socket" => transport_socket} = filter_chain ->
          if is_nil(transport_socket) do
            Map.delete(filter_chain, "transport_socket")
          else
            filter_chain
          end
        end)

      {Map.put(listener, "filter_chains", filter_chains), downstream_auth_cluster_config}
    end
  end
end
