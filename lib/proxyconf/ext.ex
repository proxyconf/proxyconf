defmodule ProxyConf.Ext do
  @moduledoc """
    This module implements the ProxyConf OpenAPI Extension
  """
  require Logger

  @schema ProxyConf.Helpers.config_schema("config", %{
            type: :object,
            required: ["x-proxyconf"],
            title: "OpenAPI Extension for ProxyConf",
            properties: %{
              :"x-proxyconf" => %{
                type: :object,
                title: "ProxyConf API Config",
                additional_properties: false,
                required: [:security],
                properties: %{
                  api_id: %{
                    title: "API Identifier",
                    type: :string,
                    minLength: 1,
                    default: "The OpenAPI Spec filename is used as default"
                  },
                  url: %{title: "API URL", type: :string, format: :uri},
                  cluster: %{title: "Cluster Identifier", type: :string, minLength: 1},
                  listener: ProxyConf.ConfigGenerator.Listener.schema(),
                  security: %{
                    title: "Security Configuration",
                    type: :object,
                    additional_properties: false,
                    required: [:auth],
                    properties: %{
                      allowed_source_ips: %{
                        title: "Allowed Source IP Address Ranges",
                        type: :array,
                        default: ["127.0.0.1/8"],
                        items: %{
                          title: "IP Address Range in CIDR Notation",
                          type: :string,
                          format: :cidr
                        },
                        uniqueItems: true
                      },
                      auth: %{
                        title: "Authentication",
                        type: :object,
                        additional_properties: false,
                        required: [:downstream],
                        properties: %{
                          upstream: ProxyConf.ConfigGenerator.UpstreamAuth.schema(),
                          downstream: ProxyConf.ConfigGenerator.DownstreamAuth.schema()
                        }
                      }
                    }
                  },
                  routing: %{
                    type: :object,
                    additional_properties: false,
                    properties: %{
                      fail_fast_on_wrong_request: %{type: :boolean},
                      fail_fast_on_missing_query_parameter: %{type: :boolean},
                      fail_fast_on_missing_header_parameter: %{type: :boolean},
                      fail_fast_on_wrong_media_type: %{type: :boolean}
                    }
                  }
                }
              }
            }
          })

  def schema do
    @schema
  end

  def config_from_spec(filename, spec) when is_map(spec) do
    proxyconf = Map.fetch!(spec, "x-proxyconf")

    defaults(filename)
    |> DeepMerge.deep_merge(to_atom_map(proxyconf))
    |> update_in([:security, :allowed_source_ips], &to_cidrs/1)
    |> update_in([:url], &URI.parse/1)
  end

  defp defaults(filename) do
    api_id = Path.rootname(filename) |> Path.basename()

    api_url =
      default(
        :default_api_host,
        "http://localhost:#{Application.get_env(:proxyconf, :default_api_port, 8080)}/#{api_id}"
      )

    api_url_parsed = URI.parse(api_url)

    %{
      api_id: api_id,
      url:
        default(
          :default_api_host,
          "http://localhost:#{Application.get_env(:proxyconf, :default_api_port, 8080)}/#{api_id}"
        ),
      cluster: default(:default_cluster_id, "proxyconf-cluster"),
      listener: %{
        address: "127.0.0.1",
        port: api_url_parsed.port
      },
      security: %{allowed_source_ips: ["127.0.0.1/8"], auth: %{upstream: nil}}
    }
  end

  defp default(env_var, default) do
    Application.get_env(
      :proxyconf,
      env_var,
      default
    )
  end

  defp to_atom_map(map) when is_map(map) do
    Map.new(map, fn {k, v} when is_binary(k) ->
      {
        try do
          String.to_existing_atom(k)
        rescue
          _ -> k
        end,
        to_atom_map(v)
      }
    end)
  end

  defp to_atom_map(list) when is_list(list) do
    Enum.map(list, fn e -> to_atom_map(e) end)
  end

  defp to_atom_map(v) do
    v
  end

  defp to_cidrs(subnet) when is_binary(subnet), do: to_cidrs([subnet])

  defp to_cidrs(subnets) when is_list(subnets) do
    Enum.flat_map(subnets, fn subnet ->
      with [address_prefix, prefix_length] <- String.split(subnet, "/"),
           {prefix_length, ""} <- Integer.parse(prefix_length) do
        [%{"address_prefix" => address_prefix, "prefix_len" => prefix_length}]
      else
        _ ->
          Logger.warning(
            "Ignored invalid CIDR range in 'allowed_source_ips' configuration #{subnet}"
          )

          []
      end
    end)
  end
end
