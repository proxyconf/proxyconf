defmodule ProxyConf.Commons.Gen.Listener do
  @moduledoc """
    This implements the config generator for the listener resource
  """

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
      description: The port is extracted from the specified `url` property if it is explicitely provided as part of the url. E.g. the implicit ports 80/443 for http/https are replaced by the default `8080`.
      default: 8080
  """
  @type tcp_port() :: 1..65535

  @typedoc """
      title: Listener Configuration
      description: The `listener` object configures the Envoy listener used to serve this API. Depending on the specified `url` property a TLS context is configured.
  """
  @type t :: %{
          address: ip_address(),
          port: tcp_port()
        }

  def name(spec) do
    "#{spec.listener_address}:#{spec.listener_port}"
  end

  def from_spec_gen(spec) do
    listener_name = name(spec)

    {&generate/2,
     %{
       listener_name: listener_name,
       address: spec.listener_address,
       port: spec.listener_port
     }}
  end

  defp generate(filter_chains, context) do
    %{
      "name" => context.listener_name,
      "address" => %{
        "socket_address" => %{
          "address" => context.address,
          "port_value" => context.port
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
      "filter_chains" => filter_chains
    }
  end
end
