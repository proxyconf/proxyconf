defmodule ProxyConf.Commons.OaiOverlay do
  defstruct([:title, :version, :extends, :actions])

  defmodule Action do
    defstruct([:description, :target, :update, :remove])
  end

  def parse(overlay) do
    %{
      "overlay" => "1.0.0",
      "info" => %{"title" => title, "version" => version},
      "actions" => actions
    } = overlay

    extends = Map.get(overlay, "extends", "*")

    actions =
      Enum.map(actions, fn %{"target" => target} = action ->
        %ProxyConf.Commons.OaiOverlay.Action{
          target: target,
          description: Map.get(action, "description"),
          update: Map.get(action, "update"),
          remove: Map.get(action, "remove", false)
        }
      end)

    {:ok,
     %ProxyConf.Commons.OaiOverlay{
       title: title,
       version: version,
       extends: extends,
       actions: actions
     }}
  rescue
    _ ->
      {:error, "invalid overlay"}
  end

  def prepare_overlays(overlay_data) do
    Enum.flat_map_reduce(overlay_data, [], fn {filename, data}, errors ->
      case parse(data) do
        {:ok, overlay} -> {[overlay], errors}
        {:error, reason} -> {[], [{filename, reason} | errors]}
      end
    end)
  end

  def overlay(spec_data, overlays) do
    overlays =
      Enum.group_by(overlays, fn %ProxyConf.Commons.OaiOverlay{extends: extends} -> extends end)

    all_overlay = Map.get(overlays, "*", [])

    Enum.map(spec_data, fn {filename, data} ->
      data = apply_overlay(data, all_overlay)

      case Map.get(overlays, filename) do
        nil -> {filename, data}
        overlay -> {filename, apply_overlay(data, overlay)}
      end
    end)
  end

  def apply_overlay(data, overlays_for_file) do
    Enum.reduce(overlays_for_file, data, fn %ProxyConf.Commons.OaiOverlay{actions: actions},
                                            acc ->
      Enum.reduce(actions, acc, fn
        %ProxyConf.Commons.OaiOverlay.Action{target: target, update: update, remove: false},
        acc ->
          {:ok, data} =
            Warpath.update(acc, target, fn actual -> DeepMerge.deep_merge(actual, update) end)

          data

        %ProxyConf.Commons.OaiOverlay.Action{target: target, remove: true}, acc ->
          {:ok, data} = Warpath.delete(acc, target)
          data
      end)
    end)
  end
end
