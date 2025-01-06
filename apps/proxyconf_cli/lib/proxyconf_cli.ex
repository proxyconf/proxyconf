defmodule ProxyConf.CLI do
  @moduledoc """
  Documentation for `ProxyConf.CLI`.
  """

  alias ProxyConf.Commons.ConfigGenerator
  alias ProxyConf.Commons.Spec

  @doc """
  Hello world.

  ## Examples

      iex> ProxyConf.CLI.hello()
      :world

  """
  def hello do
    :world
  end

  def start(_type, _args) do
    args = Burrito.Util.Args.argv()
    IO.puts("CLI =========================> #{inspect(args)}")

    case args do
      ["static", path, template_vars, out] ->
        template_vars =
          String.split(template_vars, ",")
          |> Map.new(fn kv ->
            [k, v] = String.split(kv, "=")
            {String.trim(k), String.trim(v)}
          end)

        case iterate_directory_contents(path, Path.basename(path), template_vars) do
          {specs, []} ->
            config =
              ConfigGenerator.static_config_generation(specs)

            File.write!(out, config)

          {_, errors} ->
            Enum.each(errors, fn {filename, error} ->
              IO.puts("Error #{filename}: #{error}")
            end)
        end

      _ ->
        :ok
    end
  end

  defp iterate_directory_contents(path, cluster_id, template_vars) do
    directory_spec_provider = fn iterator_fn, iterator_acc ->
      File.ls!(path)
      |> Enum.reject(&File.dir?/1)
      |> Enum.reduce(iterator_acc, fn f, acc ->
        iterator_fn.(f, fn -> File.read!(Path.join(path, f)) end, acc)
      end)
    end

    Spec.to_specs(directory_spec_provider, cluster_id, template_vars)
  end
end
