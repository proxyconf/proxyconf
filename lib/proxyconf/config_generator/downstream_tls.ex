defmodule ProxyConf.ConfigGenerator.DownstreamTls do
  @moduledoc """
    This module implements the generator for Downstream TLS context
    used by XDS/LDS
  """
  alias ProxyConf.Spec
  alias ProxyConf.ConfigGenerator.DownstreamAuth
  alias ProxyConf.ConfigGenerator.Listener
  alias ProxyConf.LocalCA

  def from_spec_gen(
        %Spec{
          cluster_id: cluster,
          api_url: %URI{scheme: "https", host: host} = _api_url,
          downstream_auth: %DownstreamAuth{auth_type: "mtls", trusted_ca: trusted_ca}
        } = spec
      ) do
    listener_name = Listener.name(spec)

    {&generate_mtls/1,
     %{host: host, cluster: cluster, listener_name: listener_name, trusted_ca: trusted_ca}}
  end

  def from_spec_gen(%Spec{
        cluster_id: cluster,
        api_url: %URI{scheme: "https", host: host} = _api_url
      }) do
    {&generate/1, %{host: host, cluster: cluster}}
  end

  def from_spec_gen(_spec), do: {fn _context -> [] end, %{}}

  def generate_mtls(context) do
    {crt, key} = LocalCA.server_cert(context.cluster, context.host).()

    [
      %{
        "name" => context.host,
        "tls_certificate" => %{
          "private_key" => %{
            "inline_string" => key
          },
          "certificate_chain" => %{
            "inline_string" => crt
          }
        }
      },
      %{
        "name" => "mtls-#{context.listener_name}",
        "validation_context" => %{
          "trusted_ca" => %{"inline_string" => File.read!(context.trusted_ca)}
        }
      }
    ]
  end

  def generate(context) do
    {crt, key} = LocalCA.server_cert(context.cluster, context.host).()

    [
      %{
        "name" => context.host,
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
