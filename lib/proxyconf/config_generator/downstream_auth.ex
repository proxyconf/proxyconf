defmodule ProxyConf.ConfigGenerator.DownstreamAuth do
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
    :jwt_provider_config
  ])

  def from_spec_gen(%Spec{downstream_auth: "disabled"} = spec),
    do:
      %__MODULE__{
        api_id: spec.api_id,
        api_url: spec.api_url,
        auth_type: "disabled",
        clients: %{}
      }
      |> wrap_gen()

  def from_spec_gen(
        %Spec{downstream_auth: %{"auth_type" => "mtls", "config" => %{"clients" => clients}}} =
          spec
      ),
      do:
        %__MODULE__{
          api_id: spec.api_id,
          api_url: spec.api_url,
          auth_type: "mtls",
          clients: clients
        }
        |> wrap_gen()

  def from_spec_gen(
        %Spec{downstream_auth: %{"auth_type" => "basic", "config" => %{"clients" => clients}}} =
          spec
      ),
      # the official basic_auth support in envoy is configured either on a listener level or a route level, both are suboptimal, therefore we use the downstream Lua auth 
      do:
        %__MODULE__{
          api_id: spec.api_id,
          api_url: spec.api_url,
          auth_type: "basic",
          auth_field_name: "authorization",
          clients: clients
        }
        |> wrap_gen()

  def from_spec_gen(
        %Spec{
          downstream_auth: %{
            "auth_type" => "header",
            "config" => %{"name" => header_name, "clients" => clients}
          }
        } = spec
      ),
      do:
        %__MODULE__{
          api_id: spec.api_id,
          api_url: spec.api_url,
          auth_type: "header",
          auth_field_name: header_name,
          clients: clients
        }
        |> wrap_gen()

  def from_spec_gen(
        %Spec{
          downstream_auth: %{
            "auth_type" => "query",
            "config" => %{"name" => query_field_name, "clients" => clients}
          }
        } = spec
      ),
      do:
        %__MODULE__{
          api_id: spec.api_id,
          api_url: spec.api_url,
          auth_type: "query",
          auth_field_name: query_field_name,
          clients: clients
        }
        |> wrap_gen()

  def from_spec_gen(
        %Spec{
          downstream_auth: %{
            "auth_type" => "jwt",
            "config" => jwt_provider_config
          }
        } = spec
      ),
      do:
        %__MODULE__{
          api_id: spec.api_id,
          api_url: spec.api_url,
          auth_type: "jwt",
          jwt_provider_config:
            jwt_provider_config |> Map.put("payload_in_metadata", "jwt_payload")
        }
        |> wrap_gen()

  def from_spec_gen(_spec) do
    raise(
      "API doesn't configure downstream authentication, which isn't allowed. To disable downstream authentication (not recommended) you can specify 'x-proxyconf-downstream-auth' to 'disabled'"
    )
  end

  defp wrap_gen(res), do: fn -> res end

  def to_filter_metadata(spec) do
    case from_spec_gen(spec).() do
      %__MODULE__{} = config ->
        %{
          "api_id" => spec.api_id,
          "auth_type" => config.auth_type,
          "auth_field_name" => config.auth_field_name
        }

      _ ->
        %{}
    end
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

  def to_envoy_http_filter(configs) do
    configs_by_auth_type = Enum.group_by(configs, fn conig -> conig.auth_type end)
    jwt_configs = Map.get(configs_by_auth_type, "jwt", [])

    lua_configs =
      Map.get(configs_by_auth_type, "basic", []) ++
        Map.get(configs_by_auth_type, "header", []) ++ Map.get(configs_by_auth_type, "query", [])

    mtls_configs = Map.get(configs_by_auth_type, "mtls", [])

    rbac_filter = to_envoy_rbac_filter(configs)

    {jwt_filter, remote_jwks_clusters} = to_envoy_jwt_filter(jwt_configs)

    lua_filter = to_lua_filter(lua_configs)

    {List.flatten([jwt_filter, lua_filter, rbac_filter]), Enum.uniq(remote_jwks_clusters)}
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
    Enum.flat_map(config.clients, fn {client_id, principal_names} ->
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
                 "principals" => rbac_principals(config)
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
          if not is_nil(http_uri) do
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
          else
            {provider_config, remote_jwks_acc}
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

  defp to_lua_filter([]), do: []

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
