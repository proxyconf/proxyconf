defmodule ProxyConf.DownstreamAuth do
  require Logger
  defstruct([:api_id, :auth_type, :auth_field_name, :hashes, :jwt_provider_config])

  @downstream_auth_extension_key "x-proxyconf-downstream-auth"
  def to_config(_api_id, %{@downstream_auth_extension_key => "disabled"}), do: :disabled

  def to_config(api_id, %{
        @downstream_auth_extension_key => %{
          "auth_type" => "header",
          "config" => %{"name" => header_name, "hashes" => hashes}
        }
      }),
      do: %__MODULE__{
        api_id: api_id,
        auth_type: "header",
        auth_field_name: header_name,
        hashes: hashes
      }

  def to_config(api_id, %{
        @downstream_auth_extension_key => %{
          "auth_type" => "query",
          "config" => %{"name" => query_field_name, "hashes" => hashes}
        }
      }),
      do: %__MODULE__{
        api_id: api_id,
        auth_type: "query",
        auth_field_name: query_field_name,
        hashes: hashes
      }

  @jwt_provider_ext "extensions.filters.http.jwt_authn.v3.JwtProvider"

  def to_config(api_id, %{
        @downstream_auth_extension_key => %{
          "auth_type" => "jwt",
          "config" => jwt_provider_config
        }
      }),
      do: %__MODULE__{api_id: api_id, auth_type: "jwt", jwt_provider_config: jwt_provider_config}

  def to_config(_api_id, _spec) do
    raise(
      "API doesn't configure downstream authentication, which isn't allowed. To disable downstream authentication (not recommended) you can specify '#{@downstream_auth_extension_key}' to 'disabled'"
    )
  end

  def to_filter_metadata(api_id, spec) do
    case to_config(api_id, spec) do
      %__MODULE__{} = config ->
        %{
          "api_id" => api_id,
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

  @external_resource "downstream_auth.lua"
  @lua_prelude [
    "package.path=\"\"\n\n",
    @lua_includes,
    File.read!("lib/proxyconf/downstream_auth.lua")
  ]

  def to_envoy_http_filter(configs) do
    configs = Enum.reject(configs, fn c -> c == :disabled end)

    {jwt_configs, other_configs} =
      Enum.split_with(configs, fn config -> config.auth_type == "jwt" end)

    {providers, rules} = to_envoy_jwt_config(jwt_configs)

    if Enum.empty?(other_configs) do
      [
        %{
          "name" => "envoy.filters.http.jwt_authn",
          "typed_config" => %{
            "@type" =>
              "type.googleapis.com/envoy.extensions.filters.http.jwt_authn.v3.JwtAuthentication",
            "providers" => providers,
            "rules" => rules
          }
        }
      ]
    else
      [
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
              "inline_string" => to_lua(configs)
            }
          }
        }
      ]
    end
  end

  defp to_envoy_jwt_configs(configs) do
    Enum.group_by(configs, fn config -> config.jwt_provider_config end, fn config ->
      %{
        api_id: config.api_id
      }
    end)
    |> Enum.reduce({%{}, []}, fn {provider_config, api_id_and_rules},
                                 {providers_acc, rules_acc} ->
      provider_name =
        "jwt-provider-#{:crypto.hash(:md5, :erlang.term_to_binary(provider_config)) |> Base.encode(16) |> String.slice(0, 10)}"
  {Map.put(providers_acc, provider_name, provider_config), 
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
