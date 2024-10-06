defmodule ProxyConf.Helpers do
  @moduledoc false

  defmodule JsonSchemaFileLoader do
    @moduledoc false
    @doc false
    @behaviour Xema.Loader

    @impl Xema.Loader
    def fetch(uri) do
      path = String.replace_prefix("#{uri}", "file://", "priv/schemas/")

      File.read!(path)
      |> Jason.decode()
    end
  end
end
