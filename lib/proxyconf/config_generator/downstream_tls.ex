defmodule ProxyConf.ConfigGenerator.DownstreamTls do
  alias ProxyConf.Spec
  alias ProxyConf.ConfigGenerator.Listener
  alias ProxyConf.LocalCA

  def from_spec_gen(
        %Spec{
          api_url: %URI{scheme: "https", host: host} = _api_url
        } = spec
      ) do
    listener_name = Listener.name(spec)

    trusted_ca =
      case Map.get(spec, :downstream_auth) do
        %{"auth_type" => "mtls", "config" => config} ->
          Map.get(config, "trusted_ca", Application.fetch_env!(:proxyconf, :ca_certificate))

        _ ->
          nil
      end

    fn ->
      {crt, key} = LocalCA.server_cert(host).()

      [
        %{
          "name" => host,
          "tls_certificate" => %{
            "private_key" => %{
              "inline_string" => key
            },
            "certificate_chain" => %{
              "inline_string" => crt
            }
          }
        }
        | maybe_mtls_trusted_ca(listener_name, trusted_ca)
      ]
    end
  end

  def from_spec_gen(_spec), do: fn -> [] end

  defp maybe_mtls_trusted_ca(_, nil), do: []

  defp maybe_mtls_trusted_ca(listener_name, trusted_ca) do
    ca_certs = File.read!(trusted_ca)

    [
      %{
        "name" => "mtls-#{listener_name}",
        "validation_context" => %{
          "trusted_ca" => %{"inline_string" => ca_certs}
        }
      }
    ]
  end

  def to_envoy_transport_socket(_listener_name, _downstream_auth, []), do: nil

  def to_envoy_transport_socket(listener_name, downstream_auth, downstream_tls) do
    configs_by_auth_type = Enum.group_by(downstream_auth, fn config -> config.auth_type end)
    mtls_configs = Map.get(configs_by_auth_type, "mtls")
    # called by listener template
    %{
      "name" => "envoy.transport.socket.tls",
      "typed_config" => %{
        "@type" =>
          "type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.DownstreamTlsContext",
        "require_client_certificate" => true,
        "common_tls_context" =>
          %{
            # TODO additional configs from global TLS Conig
            "tls_certificate_sds_secret_configs" =>
              Enum.reject(downstream_tls, fn %{"name" => name} ->
                String.starts_with?(name, "mtls-")
              end)
              |> Enum.map(fn %{"name" => name} ->
                %{
                  "name" => name,
                  "sds_config" => %{"ads" => %{}, "resource_api_version" => "V3"}
                }
              end)
          }
          |> Map.merge(
            if mtls_configs != nil do
              %{
                "validation_context_sds_secret_config" => %{
                  "name" => "mtls-#{listener_name}",
                  "sds_config" => %{"ads" => %{}, "resource_api_version" => "V3"}
                }
              }
            else
              %{}
            end
          )
      }
    }
  end
end
