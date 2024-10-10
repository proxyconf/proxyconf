defmodule ProxyConf.ConfigGenerator.Listener do
  @moduledoc """
    This implements the config generator for the listener resource
  """
  use ProxyConf.MapTemplate

  @typedoc """
      title: IPv4
      description: IPv4 TCP Listener Address
      format: ipv4
  """
  @type ipv4() :: String.t()

  @typedoc """
      title: IPv6
      description: IPv6 TCP Listener Address
      format: ipv6
  """
  @type ipv6() :: String.t()

  @typedoc """
      title: Listener Address
      description: The IP address Envoy listens for new TCP connections
      default: 127.0.0.1
  """
  @type ip_address() :: ipv4() | ipv6()

  @typedoc """
      title: Listener Port
      description: The port is extracted from the `api_url` if it is explicitely provided as part of the url. E.g. the implicit ports 80/443 for http/https are replaced by the default `8080`.
      default: 8080
  """
  @type tcp_port() :: 1..65535

  @typedoc """
      title: Listener Configuration
      description: The `listener` object configures the Envoy listener used to serve this API. Depending on the provided `api_url` a TLS context is configured.
  """
  @type t :: %{
          address: ip_address(),
          port: tcp_port()
        }

  deftemplate(%{
    "name" => :listener_name,
    "address" => %{
      "socket_address" => %{
        "address" => :address,
        "port_value" => :port
      }
    },
    "listener_filters" => [
      %{
        "name" => "envoy.filters.listener.tls_inspector",
        "typed_config" => %{
          "@type" =>
            "type.googleapis.com/envoy.extensions.filters.listener.tls_inspector.v3.TlsInspector"
        }
      }
    ],
    "filter_chains" => :filter_chains
  })

  def name(spec) do
    "#{spec.listener_address}:#{spec.listener_port}"
  end

  def from_spec_gen(spec) do
    listener_name = name(spec)

    fn filter_chains ->
      %{
        listener_name: listener_name,
        address: spec.listener_address,
        port: spec.listener_port,
        filter_chains: filter_chains
      }
      |> eval()
    end
  end
end
