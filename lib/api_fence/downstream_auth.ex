defmodule ApiFence.DownstreamAuth do
  require Logger
  defstruct([:api_id, :auth_type, :auth_field_name, :hashes])

  @downstream_auth_extension_key "x-api-fence-downstream-auth"
  def to_config(api_id, %{@downstream_auth_extension_key => "disabled"}), do: []

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

  def to_config(_api_id, _spec) do
    raise(
      "API doesn't configure downstream authentication, which isn't allowed. To disable downstream authentication (not recommended) you can specify '#{@downstream_auth_extension_key}' to 'disabled'"
    )
  end

  def to_filter_metadata(api_id, spec) do
    config = to_config(api_id, spec)

    %{
      "api_id" => api_id,
      "auth_type" => config.auth_type,
      "auth_field_name" => config.auth_field_name
    }
  end

  @external_resource "lua/vendor/md4/md5.lua"
  @lua_includes Enum.reduce(["lua/vendor/md5/md5.lua"], [], fn f, code ->
                  module_name = Path.basename(f) |> String.replace_suffix(".lua", "")
                  module_code = File.read!(f)

                  module_loader = """
                  package.loaded["#{module_name}"] = package.loaded["#{module_name}"] or (function(...) #{module_code} end)("#{module_name}") or package.loaded["#{module_name}"] or true
                  """

                  [module_loader, "\n" | code]
                end)
                |> :erlang.iolist_to_binary()

  @external_resource "lib/api_fence/downstream_auth.lua"
  @lua_prelude [
    "package.path=\"\"\n\n",
    @lua_includes,
    File.read!("lib/api_fence/downstream_auth.lua")
  ]
  def to_lua(configs) do
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
