defmodule ProxyConf.ConfigGenerator.Listener do
  @moduledoc """
    This implements the config generator for the listener resource
  """
  use ProxyConf.MapTemplate

  def schema,
    do: %{
      title: "Listener Configuration",
      type: :object,
      additional_properties: false,
      properties: %{
        address: %{
          default: "127.0.0.1",
          oneOf: [
            %{title: "IPv4 TCP Listener Address", type: :string, format: :ipv4},
            %{title: "IPv6 TCP Listener Address", type: :string, format: :ipv6}
          ]
        },
        port: %{
          title: "TCP Listener Port",
          description:
            "The port is extracted from the `api_url` if it is explicitely provided as part of the url. E.g. the implicit ports 80/443 for http/https are replaced by the default `8080`.",
          default: 8080,
          type: :integer,
          minimum: 1,
          maximum: 65_535
        }
      }
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
