defmodule ApiFence.MapPatch do
  @moduledoc """
  A simplified yet very powerful alternative to JSON patch
  """
  def patch(map, list_of_patches) when is_list(list_of_patches) do
    Enum.reduce(list_of_patches, map, fn p, acc ->
      patch(acc, p)
    end)
  end

  @doc """
  iex> ApiFence.MapPatch.patch(%{"a" => %{"b" => [%{"c" => 10}, %{"c" => 20}]}}, %{op: "put_in", path: "a/b/*/c", value: 100})
  %{"a" => %{"b" => [%{"c" => 100}, %{"c" => 100}]}}

  iex> ApiFence.MapPatch.patch(%{"a" => %{"b" => [%{"c" => 10}, %{"c" => 20}]}}, %{op: "update_in", path: "a/b/*/c", value_fn: fn i -> i * 10 end})
  %{"a" => %{"b" => [%{"c" => 100}, %{"c" => 200}]}}

  iex> ApiFence.MapPatch.patch(%{"a" => %{"b" => [%{"c" => 10}, %{"c" => 20}]}}, %{op: "delete_in", path: "a/b/~first"})
  %{"a" => %{"b" => [%{"c" => 20}]}}

  iex> ApiFence.MapPatch.patch(%{"a" => %{"b" => [%{"c" => 10}, %{"c" => 20}]}}, %{op: "delete_in", path: "a/b/~last"})
  %{"a" => %{"b" => [%{"c" => 10}]}}
  """
  def patch(map, %{op: "put_in", path: path, value: value}) do
    path = to_path(path)
    put_in(map, path, value)
  end

  def patch(map, %{op: "update_in", path: path, value_fn: value_fn}) do
    path = to_path(path)
    get_in(map, path) |> IO.inspect(label: "object to update")
    update_in(map, path, value_fn)
  end

  def patch(map, %{op: "delete_in", path: path}) do
    path = to_path(path)
    {_, map} = pop_in(map, path)
    map
  end

  defp to_path(path) do
    Path.split(path)
    |> Enum.map(fn
      "*" ->
        Access.all()

      "~first" ->
        Access.at(0)

      "~last" ->
        Access.at(-1)

      k ->
        case String.split(k, "=") do
          [k, v] ->
            v = may_be_int(v)
            Access.filter(fn m -> Map.get(m, k) == v end)

          [k] ->
            case may_be_int(k) do
              i when is_integer(i) -> Access.at(i)
              k -> k
            end
        end
    end)
  end

  def may_be_int(s) do
    case Integer.parse(s) do
      {i, ""} -> i
      _ -> s
    end
  end
end
