defmodule ProxyConf.Commons.Gen.HttpConnectionManager do
  @moduledoc """
    This implements the config generator for the Http Connection Manager
  """
  use ProxyConf.Commons.MapTemplate

  @type server_name() :: String.t()
  @type server_header_transformation() :: :OVERWRITE | :APPEND_IF_ABSENT | :PASS_THROUGH
  @type headers_with_underscores_action() :: :ALLOW | :REJECT_REQUEST | :DROP_HEADER

  @type uint_32_value() :: non_neg_integer()
  @type duration() :: %{
          seconds: uint_32_value()
        }

  @typedoc """
    Additional settings for HTTP requests handled by the connection manager. These will be applicable to both HTTP1 and HTTP2 requests.
  """
  @type common_http_protocol_options() :: %{
          idle_timeout: nil | duration(),
          max_connection_duration: nil | duration(),
          max_headers_count: nil | uint_32_value(),
          max_response_headers_kb: nil | uint_32_value(),
          max_stream_duration: nil | duration(),
          headers_with_underscores_action: nil | headers_with_underscores_action(),
          max_requests_per_connection: nil | uint_32_value()
        }

  @typedoc """
      title: Http Connection Manager Configuration
      description: The `http-connection-manager` object configures the Envoy HttpConnectionManager used to serve this API. ProxyConf automatically configures a filter chain per VHost/Listener, enabling that specific http connection manager configurations can exist per filter chain.
  """
  @type t() :: %{
          server_name: nil | server_name(),
          server_header_transformation: nil | server_header_transformation(),
          common_http_protocol_options: nil | common_http_protocol_options()
        }

  deftemplate(%{
    "name" => "envoy.filters.network.http_connection_manager",
    "typed_config" => %{
      "@type" =>
        "type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager",
      "stat_prefix" => "proxyconf",
      "codec_type" => "AUTO",
      "strip_matching_host_port" => true,
      "upgrade_configs" => [
        %{"upgrade_type" => "websocket", "enabled" => false}
      ],
      "rds" => %{
        "config_source" => %{
          "ads" => %{},
          "resource_api_version" => "V3"
        },
        "route_config_name" => :route_config_name
      },
      "http_filters" =>
        [
          :http_filters,
          %{
            "name" => "envoy.filters.http.cors",
            "typed_config" => %{
              "@type" => "type.googleapis.com/envoy.extensions.filters.http.cors.v3.Cors"
            }
          },
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
  })

  def config_from_json(nil), do: %{}

  def config_from_json(config) when is_map(config) do
    Map.new(config, fn {k, v} -> {Recase.to_snake(k), config_from_json(v)} end)
  end

  def config_from_json(config) when is_list(config) do
    Enum.map(config, fn v -> config_from_json(v) end)
  end

  def config_from_json(v), do: v

  def to_envoy_http_connection_manager(
        http_connection_manager_override,
        route_config_name,
        http_filters
      ) do
    eval(%{route_config_name: route_config_name, http_filters: http_filters})
    |> DeepMerge.deep_merge(%{"typed_config" => http_connection_manager_override})
  end
end
