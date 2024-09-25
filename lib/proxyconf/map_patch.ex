defmodule ProxyConf.MapPatch do
  @moduledoc """
  A simplified yet very powerful alternative to JSON patch
  """
  def patch(map, list_of_patches) when is_list(list_of_patches) do
    Enum.reduce(list_of_patches, map, fn p, acc ->
      patch(acc, p)
    end)
  end

  @doc """
  iex> ProxyConf.MapPatch.patch(%{"a" => %{"b" => [%{"c" => 10}, %{"c" => 20}]}}, %{op: "put_in", path: "a/b/*/c", value: 100})
  %{"a" => %{"b" => [%{"c" => 100}, %{"c" => 100}]}}

  iex> ProxyConf.MapPatch.patch(%{"a" => %{"b" => [%{"c" => 10}, %{"c" => 20}]}}, %{op: "update_in", path: "a/b/*/c", value_fn: fn i -> i * 10 end})
  %{"a" => %{"b" => [%{"c" => 100}, %{"c" => 200}]}}

  iex> ProxyConf.MapPatch.patch(%{"a" => %{"b" => [%{"c" => 10}, %{"c" => 20}]}}, %{op: "delete_in", path: "a/b/~first"})
  %{"a" => %{"b" => [%{"c" => 20}]}}

  iex> ProxyConf.MapPatch.patch(%{"a" => %{"b" => [%{"c" => 10}, %{"c" => 20}]}}, %{op: "delete_in", path: "a/b/~last"})
  %{"a" => %{"b" => [%{"c" => 10}]}}

  iex> ProxyConf.MapPatch.patch(%{"a" => %{"b" => [%{"c" => 10}, %{"c" => 20}]}}, %{op: "merge_in", path: "a/b/~last", value: %{"d" => 123}})
  %{"a" => %{"b" => [%{"c" => 10}, %{"c" => 20, "d" => 123}]}}
  """
  def patch(map, %{op: "put_in", path: path, value: value} = patch) do
    matcher = Map.get(patch, :match)
    path = to_path(path)
    item = get_in(map, path)

    if match_?(matcher, item) do
      put_in(map, path, value)
    else
      map
    end
  end

  def patch(map, %{op: "update_in", path: path, value_fn: value_fn} = patch) do
    matcher = Map.get(patch, :match)
    path = to_path(path)
    item = get_in(map, path)

    if match_?(matcher, item) do
      update_in(map, path, value_fn)
    else
      map
    end
  end

  def patch(map, %{op: "delete_in", path: path} = patch) do
    matcher = Map.get(patch, :match)
    path = to_path(path)
    item = get_in(map, path)

    if match_?(matcher, item) do
      {_, map} = pop_in(map, path)
      map
    else
      map
    end
  end

  def patch(map, %{op: "merge_in", path: path, value: value} = patch) do
    matcher = Map.get(patch, :match)
    path = to_path(path)
    item = get_in(map, path)

    if match_?(matcher, item) do
      update_in(map, path, fn v -> DeepMerge.deep_merge(v, value) end)
    else
      map
    end
  end

  def patch(map, %{"op" => _, "path" => _} = patch) do
    # patch loaded from json
    patch(map, Enum.map(patch, fn {k, v} -> {String.to_existing_atom(k), v} end) |> Map.new())
  end

  defp to_match_paths(matcher, path \\ [])

  defp to_match_paths(matcher, path) when is_map(matcher) do
    Enum.map(matcher, fn {k, v} ->
      to_match_paths(v, [k | path])
    end)
    |> List.flatten()
  end

  defp to_match_paths(v, path), do: {Enum.reverse(path), v}

  defp match_?(nil, _), do: true

  defp match_?(matcher, item) when is_map(matcher) do
    to_match_paths(matcher)
    |> Enum.all?(fn {path, val} ->
      dyn_get_in(item, path) == val
    end)
  end

  defp dyn_get_in(v, []), do: v

  defp dyn_get_in(item, [k | path]) when is_map(item) do
    dyn_get_in(Map.get(item, k), path)
  end

  defp dyn_get_in(item, [k | path]) when is_list(item) and is_integer(k) do
    dyn_get_in(Enum.at(item, k), path)
  end

  defp dyn_get_in(_, _), do: nil

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
