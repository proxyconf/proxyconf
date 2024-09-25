defmodule ProxyConf.ConfigGenerator.FilterChain do
  @moduledoc """
    This module implements the filter chain resource.

    One filter chain per VHost is generated.
  """
  use ProxyConf.MapTemplate
  alias ProxyConf.ConfigGenerator.DownstreamAuth
  alias ProxyConf.ConfigGenerator.DownstreamTls
  alias ProxyConf.ConfigGenerator.VHost
  alias ProxyConf.ConfigGenerator.Listener
  alias ProxyConf.ConfigGenerator.RouteConfiguration

  deftemplate(%{
    "name" => :route_config_name,
    "transport_socket" => :transport_socket,
    "filter_chain_match" => %{
      "server_names" => :server_names,
      "direct_source_prefix_ranges" => :allowed_source_ip_ranges
    },
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
            "route_config_name" => :route_config_name
          },
          "http_filters" =>
            [
              :downstream_auth,
              %{
                "name" => "envoy.filters.http.router",
                "typed_config" => %{
                  "@type" => "type.googleapis.com/envoy.extensions.filters.http.router.v3.Router",
                  "suppress_envoy_headers" => true
                }
              }
            ]
            |> List.flatten()
        }
      }
    ]
  })

  def from_spec_gen(spec) do
    listener_name = Listener.name(spec)

    fn vhost, source_ip_ranges, downstream_auth, downstream_tls ->
      {downstream_auth_listener_config, downstream_auth_cluster_config} =
        DownstreamAuth.to_envoy_http_filter(downstream_auth)

      transport_socket =
        DownstreamTls.to_envoy_transport_socket(listener_name, downstream_auth, downstream_tls)

      server_names = VHost.server_names(vhost)

      %{"transport_socket" => transport_socket} =
        filter_chain =
        %{
          server_names: [server_names |> List.first()],
          transport_socket: transport_socket,
          allowed_source_ip_ranges: source_ip_ranges,
          downstream_auth: downstream_auth_listener_config,
          route_config_name: RouteConfiguration.name(listener_name, List.first(server_names))
        }
        |> eval()

      filter_chain =
        if is_nil(transport_socket) do
          {_, filter_chain} =
            Map.delete(filter_chain, "transport_socket")
            |> pop_in(["filter_chain_match", "server_names"])

          filter_chain
        else
          filter_chain
        end

      {filter_chain, downstream_auth_cluster_config}
    end
  end
end
