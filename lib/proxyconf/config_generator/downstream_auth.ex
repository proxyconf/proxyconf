defmodule ProxyConf.ConfigGenerator.DownstreamAuth do
  @moduledoc """
    This module implements the generator for the Lua based
    downstream authentication script as well as the depending
    RBAC filter that utilizes Lua Filter metadata resulted during
    authentication.

    JWT and mTLS authentication cases don't rely on a Lua script
    but also use the RBAC filter for the final authentication verdict.
  """
  require Logger
  alias ProxyConf.Spec
  alias ProxyConf.ConfigGenerator.Cluster
  alias ProxyConf.ConfigGenerator.ClusterLbEndpoint

  defstruct([
    :api_id,
    :api_url,
    :auth_type,
    :auth_field_name,
    :clients,
    :allowed_source_ips,
    :jwt_provider_config,
    :trusted_ca
  ])

  def config_from_json("disabled") do
    %__MODULE__{
      auth_type: "disabled",
      clients: %{}
    }
  end

  def config_from_json(%{"type" => auth_type} = json) when is_map(json) do
    %__MODULE__{
      auth_type: auth_type,
      auth_field_name:
        if auth_type == "basic" do
          "authorization"
        else
          Map.get(json, "name")
        end,
      clients: Map.get(json, "clients"),
      jwt_provider_config:
        if auth_type == "jwt" do
          Map.get(json, "provider_config")
          |> Map.put("payload_in_metadata", "jwt_payload")
        else
          nil
        end,
      trusted_ca: Map.get(json, "trusted_ca")
    }
  end

  def from_spec_gen(%Spec{downstream_auth: downstream_auth} = spec),
    do:
      %__MODULE__{
        downstream_auth
        | api_id: spec.api_id,
          api_url: spec.api_url,
          allowed_source_ips: spec.allowed_source_ips
      }
      |> wrap_gen()

  def from_spec_gen(spec) do
    raise(
      "API doesn't configure downstream authentication, which isn't allowed. To disable downstream authentication (not recommended) you can specify 'x-proxyconf -> security -> auth -> downstream' to 'disabled' has: #{inspect(spec.downstream_auth)}"
    )
  end

  defp wrap_gen(res), do: fn -> res end

  def to_filter_metadata(spec) do
    # this function is called by the route generator and injects
    # custom metadata available if a route matches
    %__MODULE__{} = config = from_spec_gen(spec).()

    %{
      "api_id" => spec.api_id,
      "auth_type" => config.auth_type,
      "auth_field_name" => config.auth_field_name
    }
  end

  @external_resource "lua/vendor/md5/md5.lua"
  @lua_includes Enum.reduce(["lua/vendor/md5/md5.lua"], [], fn f, code ->
                  module_name = Path.basename(f) |> String.replace_suffix(".lua", "")
                  module_code = File.read!(f)

                  module_loader = """
                  package.loaded["#{module_name}"] = package.loaded["#{module_name}"] or (function(...) #{module_code} end)("#{module_name}") or package.loaded["#{module_name}"] or true
                  """

                  [module_loader, "\n" | code]
                end)
                |> :erlang.iolist_to_binary()

  @external_resource Path.join(__DIR__, "downstream_auth.lua")
  @lua_prelude [
    "package.path=\"\"\n\n",
    @lua_includes,
    File.read!("lib/proxyconf/config_generator/downstream_auth.lua")
  ]

  def to_envoy_http_filter(downstream_auth) do
    configs_by_auth_type = Enum.group_by(downstream_auth, fn config -> config.auth_type end)
    jwt_configs = Map.get(configs_by_auth_type, "jwt", [])

    lua_configs =
      Map.get(configs_by_auth_type, "basic", []) ++
        Map.get(configs_by_auth_type, "header", []) ++ Map.get(configs_by_auth_type, "query", [])

    rbac_filter = to_envoy_rbac_filter(downstream_auth)

    {jwt_filter, remote_jwks_clusters} = to_envoy_jwt_filter(jwt_configs)

    lua_filter = to_lua_filter(lua_configs)

    {List.flatten([jwt_filter, lua_filter, rbac_filter]), Enum.uniq(remote_jwks_clusters)}
  end

  defp ensure_no_empty_principals([]), do: [%{"any" => false}]
  defp ensure_no_empty_principals(principals), do: principals

  defp rbac_source_ip_principals(%__MODULE__{allowed_source_ips: allowed_source_ips}) do
    Enum.map(allowed_source_ips, fn
      %{"address_prefix" => "0.0.0.0", "prefix_len" => 0} ->
        %{"any" => true}

      source_ip ->
        %{"remote_ip" => source_ip}
    end)
  end

  defp rbac_principals(%__MODULE__{auth_type: auth_type} = config)
       when auth_type in ["basic", "header", "query"] do
    Enum.map(config.clients, fn {client_id, _hashes} ->
      %{
        "metadata" => %{
          "filter" => "proxyconf.downstream_auth",
          "path" => [%{"key" => "client_id"}],
          "value" => %{"string_match" => %{"exact" => client_id}}
        }
      }
    end)
  end

  defp rbac_principals(%__MODULE__{auth_type: auth_type} = _config)
       when auth_type == "disabled" do
    [%{"any" => true}]
  end

  defp rbac_principals(%__MODULE__{auth_type: auth_type} = config)
       when auth_type == "mtls" do
    # The name of the principal. If set, The URI SAN or DNS SAN in that order is used from the certificate, otherwise the subject field is used. If unset, it applies to any user that is authenticated.
    Enum.flat_map(config.clients, fn {_client_id, principal_names} ->
      Enum.map(principal_names, fn principal_name ->
        %{"authenticated" => %{"principal_name" => %{"exact" => principal_name}}}
      end)
    end)
  end

  defp rbac_principals(%__MODULE__{auth_type: auth_type, jwt_provider_config: jwt_provider_config})
       when auth_type == "jwt" do
    audiences_principals =
      Enum.map(Map.get(jwt_provider_config, "audiences", []), fn aud ->
        %{
          "metadata" => %{
            "filter" => "envoy.filters.http.jwt_authn",
            "path" => [%{"key" => "jwt_payload"}, %{"key" => "aud"}],
            "value" => %{"string_match" => %{"exact" => aud}}
          }
        }
      end)

    subject_principals =
      Enum.map(Map.get(jwt_provider_config, "subjects", []), fn sub ->
        %{
          "metadata" => %{
            "filter" => "envoy.filters.http.jwt_authn",
            "path" => [%{"key" => "jwt_payload"}, %{"key" => "sub"}],
            "value" => %{"string_match" => %{"exact" => sub}}
          }
        }
      end)

    audiences_principals ++ subject_principals
  end

  defp to_envoy_rbac_filter(configs) do
    %{
      "name" => "envoy.filters.http.rbac",
      "typed_config" => %{
        "@type" => "type.googleapis.com/envoy.extensions.filters.http.rbac.v3.RBAC",
        "rules" => %{
          "action" => "ALLOW",
          "policies" =>
            Map.new(configs, fn config ->
              {config.api_id,
               %{
                 "permissions" => [
                   %{"url_path" => %{"path" => %{"prefix" => config.api_url.path}}}
                 ],
                 "principals" => [
                   %{
                     "and_ids" => %{
                       "ids" => [
                         %{
                           "or_ids" => %{
                             "ids" => rbac_principals(config) |> ensure_no_empty_principals()
                           }
                         },
                         %{
                           "or_ids" => %{
                             "ids" =>
                               rbac_source_ip_principals(config) |> ensure_no_empty_principals()
                           }
                         }
                       ]
                     }
                   }
                 ]
               }}
            end)
        }
      }
    }
  end

  defp to_envoy_jwt_filter([]), do: {[], []}

  defp to_envoy_jwt_filter(configs) do
    {providers, rules, jwt_clusters} =
      Enum.group_by(configs, fn config -> config.jwt_provider_config end, fn config ->
        config.api_url.path
      end)
      |> Enum.reduce({%{}, [], []}, fn {provider_config, paths},
                                       {providers_acc, rules_acc, remote_jwks_acc} ->
        provider_name =
          "jwt-provider-#{:crypto.hash(:md5, :erlang.term_to_binary(provider_config)) |> Base.encode16() |> String.slice(0, 10)}"

        rules_acc =
          Enum.uniq(paths)
          |> Enum.reduce(rules_acc, fn path, rules_acc ->
            [
              %{"match" => %{"prefix" => path}, "requires" => %{"provider_name" => provider_name}}
              | rules_acc
            ]
          end)

        http_uri = get_in(provider_config, ["remote_jwks", "http_uri", "uri"])

        provider_config =
          Map.put(provider_config, "failed_status_in_metadata", "proxyconf.downstream_auth")

        {provider_config, remote_jwks_acc} =
          if is_nil(http_uri) do
            {provider_config, remote_jwks_acc}
          else
            {cluster_name, cluster_uri} =
              Cluster.cluster_uri_from_oas3_server("internal-jwks", %{"url" => http_uri})

            {put_in(provider_config, ["remote_jwks", "http_uri", "cluster"], cluster_name),
             [
               Cluster.eval(%{
                 name: cluster_name,
                 endpoints: [
                   ClusterLbEndpoint.eval(%{host: cluster_uri.host, port: cluster_uri.port})
                 ]
               })
               | remote_jwks_acc
             ]}
          end

        {Map.put(providers_acc, provider_name, provider_config), rules_acc, remote_jwks_acc}
      end)

    {[
       %{
         "name" => "envoy.filters.http.jwt_authn",
         "typed_config" => %{
           "@type" =>
             "type.googleapis.com/envoy.extensions.filters.http.jwt_authn.v3.JwtAuthentication",
           "providers" => providers,
           "rules" => rules
         }
       }
     ], jwt_clusters}
  end

  defp to_lua_filter(configs) do
    [
      %{
        "name" => "envoy.filters.http.lua",
        "typed_config" => %{
          "@type" => "type.googleapis.com/envoy.extensions.filters.http.lua.v3.Lua",
          "default_source_code" => %{
            "inline_string" =>
              [
                @lua_prelude
                | Enum.map_join(
                    configs,
                    "\n",
                    fn %__MODULE__{} = config ->
                      hashes =
                        Enum.map_join(config.clients, ",\n ", fn {client_id, hashes} ->
                          Enum.map_join(hashes, ",\n ", fn hash ->
                            "[\"#{hash}\"] = {client_id=\"#{client_id}\"}"
                          end)
                        end)

                      """
                      Config[to_key("#{config.api_id}", "#{config.auth_type}", "#{config.auth_field_name}")] = {#{hashes}}
                      """
                    end
                  )
              ]
              |> :erlang.iolist_to_binary()
          }
        }
      }
    ]
  end
end
