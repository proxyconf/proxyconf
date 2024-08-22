defmodule ProxyConf.ConfigGenerator.Listener do
  use ProxyConf.MapTemplate

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
