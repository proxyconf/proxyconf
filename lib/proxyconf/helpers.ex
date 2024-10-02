defmodule ProxyConf.Helpers do
  @moduledoc false

  @schema_path "docs/schemas"
  def config_schema(name, schema) when is_map(schema) do
    json = Jason.encode!(schema)
    File.write!(Path.join(@schema_path, name <> ".schema.json"), json)
    Jason.decode!(json)
  end
end
