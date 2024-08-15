defmodule ProxyConf.ConfigGenerator.DownstreamAuth do
  require Logger
  alias ProxyConf.Spec
  alias ProxyConf.ConfigGenerator.Cluster
  alias ProxyConf.ConfigGenerator.ClusterLbEndpoint
  defstruct([:api_id, :api_url, :auth_type, :auth_field_name, :hashes, :jwt_provider_config])

  def from_spec_gen(%Spec{downstream_auth: "disabled"}), do: :disabled |> wrap_gen()

  def from_spec_gen(
        %Spec{downstream_auth: %{"auth_type" => "basic", "config" => %{"hashes" => hashes}}} =
          spec
      ),
      # the official basic_auth support in envoy is configured either on a listener level or a route level, both are suboptimal, therefore we use the downstream Lua auth 
      do:
        %__MODULE__{
          api_id: spec.api_id,
          api_url: spec.api_url,
          auth_type: "basic",
          auth_field_name: "authorization",
          hashes: hashes
        }
        |> wrap_gen()

  def from_spec_gen(
        %Spec{
          downstream_auth: %{
            "auth_type" => "header",
            "config" => %{"name" => header_name, "hashes" => hashes}
          }
        } = spec
      ),
      do:
        %__MODULE__{
          api_id: spec.api_id,
          api_url: spec.api_url,
          auth_type: "header",
          auth_field_name: header_name,
          hashes: hashes
        }
        |> wrap_gen()

  def from_spec_gen(
        %Spec{
          downstream_auth: %{
            "auth_type" => "query",
            "config" => %{"name" => query_field_name, "hashes" => hashes}
          }
        } = spec
      ),
      do:
        %__MODULE__{
          api_id: spec.api_id,
          api_url: spec.api_url,
          auth_type: "query",
          auth_field_name: query_field_name,
          hashes: hashes
        }
        |> wrap_gen()

  @jwt_provider_ext "extensions.filters.http.jwt_authn.v3.JwtProvider"

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
          jwt_provider_config: jwt_provider_config
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
    configs = Enum.reject(configs, fn c -> c == :disabled end)

    {jwt_configs, static_configs} =
      Enum.split_with(configs, fn config -> config.auth_type == "jwt" end)

    {providers, rules, remote_jwks_clusters} = to_envoy_jwt_config(jwt_configs)

    remote_jwks_clusters = Enum.uniq(remote_jwks_clusters)

    if Enum.empty?(static_configs) do
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
       ], remote_jwks_clusters}
    else
      {[
         %{
           "name" => "envoy.filters.http.jwt_authn",
           "typed_config" => %{
             "@type" =>
               "type.googleapis.com/envoy.extensions.filters.http.jwt_authn.v3.JwtAuthentication",
             "providers" => providers,
             "rules" => rules
           }
         },
         %{
           "name" => "envoy.filters.http.lua",
           "typed_config" => %{
             "@type" => "type.googleapis.com/envoy.extensions.filters.http.lua.v3.Lua",
             "default_source_code" => %{
               "inline_string" => to_lua(static_configs)
             }
           }
         }
       ], remote_jwks_clusters}
    end
  end

  defp to_envoy_jwt_config(configs) do
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
  end

  defp to_lua(configs) do
    [
      @lua_prelude
      | Enum.map_join(
          configs,
          "\n",
          fn %__MODULE__{} = config ->
            hashes =
              Enum.map_join(config.hashes, ",\n  ", fn hash -> "[\"#{hash}\"] = {allow=true}" end)

            """
            Config[to_key("#{config.api_id}", "#{config.auth_type}", "#{config.auth_field_name}")] = {#{hashes}}
            """
          end
        )
    ]
    |> :erlang.iolist_to_binary()
  end
end
