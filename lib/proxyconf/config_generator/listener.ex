defmodule ProxyConf.ConfigGenerator.Listener do
  use ProxyConf.MapTemplate
  alias ProxyConf.ConfigGenerator.DownstreamAuth

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

    fn vhosts, downstream_auth ->
      {downstream_auth_listener_config, downstream_auth_cluster_config} =
        DownstreamAuth.to_envoy_http_filter(downstream_auth)

      {%{
         listener_name: listener_name,
         address: spec.listener_address,
         port: spec.listener_port,
         virtual_hosts: vhosts,
         downstream_auth: downstream_auth_listener_config
       }
       |> eval(), downstream_auth_cluster_config}
    end
  end
end
