defmodule ProxyConf.ConfigGenerator.DownstreamTls do
  alias ProxyConf.Spec
  alias ProxyConf.LocalCA

  def from_spec_gen(%Spec{
        api_url: %URI{scheme: "https"} = api_url
      }) do
    splitted_host = String.split(api_url.host, ".")

    {hostnames, _} =
      Enum.map_reduce(splitted_host, splitted_host, fn
        _, [_ | host_acc] = host when length(host_acc) > 1 ->
          {Enum.join(host, "."), host_acc}

        _, host ->
          {Enum.join(host, "."), []}
      end)

    fn ->
      Enum.flat_map(hostnames, fn hostname ->
        {crt, key} = LocalCA.server_cert(hostname).()

        [
          %{
            "name" => hostname,
            "tls_certificate" => %{
              "private_key" => %{
                "inline_string" => key
              },
              "certificate_chain" => %{
                "inline_string" => crt
              }
            }
          }
        ]
      end)
    end
  end

  def from_spec_gen(_spec), do: fn -> [] end

  def to_envoy_transport_socket([]), do: nil

  def to_envoy_transport_socket(downstream_tls) do
    # called by listener template
    %{
      "name" => "envoy.transport.socket.tls",
      "typed_config" => %{
        "@type" =>
          "type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.DownstreamTlsContext",
        "common_tls_context" => %{
          # TODO additional configs from global TLS Conig
          "tls_certificate_sds_secret_configs" =>
            Enum.map(downstream_tls, fn %{"name" => name} ->
              %{
                "name" => name,
                "sds_config" => %{"ads" => %{}, "resource_api_version" => "V3"}
              }
            end)
        }
      }
    }
  end
end
