defmodule ProxyConf.ConfigCache do
  @moduledoc """
    This module implements a GenServer handling changes of the OpenAPI
    specs, and pushing resource updates to the ProxyConf.Stream GenServers.
  """
  use GenServer
  alias ProxyConf.ConfigGenerator
  alias ProxyConf.MapPatch
  alias ProxyConf.Spec
  require Logger

  @cluster "type.googleapis.com/envoy.config.cluster.v3.Cluster"
  @listener "type.googleapis.com/envoy.config.listener.v3.Listener"
  @tls_secret "type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.Secret"
  @route_configuration "type.googleapis.com/envoy.config.route.v3.RouteConfiguration"

  @spec_table :config_cache_tbl_specs
  @resources_table :config_cache_tbl_resources
  def start_link(_args) do
    :ets.new(@spec_table, [:public, :named_table])
    :ets.new(@resources_table, [:public, :named_table])
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  # currently only used for testing
  def load_external_spec(spec_name, spec) do
    case GenServer.call(__MODULE__, {:load_external_spec, spec_name, spec}) do
      {:ok, cluster_id} ->
        wait_until_in_sync(cluster_id)

      error ->
        error
    end
  end

  def load_events(cluster_id, events) do
    case GenServer.multi_call(
           [node() | Node.list()],
           __MODULE__,
           {:load_events, cluster_id, events}
         ) do
      {_, []} ->
        wait_until_in_sync(cluster_id)

      _ ->
        :ok
    end
  end

  defp wait_until_in_sync(cluster_id) do
    if ProxyConf.Stream.in_sync(cluster_id) do
      :ok
    else
      Process.sleep(100)
      wait_until_in_sync(cluster_id)
    end
  end

  def init(_args) do
    {:ok,
     %{
       streams: %{},
       tref: nil,
       index: nil
     }, {:continue, nil}}
  end

  def handle_continue(_continue, state) do
    {:ok, {res, _}} =
      Spec.db_map_reduce(
        fn %Spec{
             cluster_id: cluster_id,
             api_id: api_id
           } = spec,
           acc ->
          # spec is coming directly from the database layer, it's already validated
          insert_validated_spec(spec)
          Logger.info(cluster: cluster_id, api_id: api_id, message: "Spec init")

          {{cluster_id, api_id}, acc}
        end,
        # acc
        [],
        # where clause
        []
      )

    Enum.group_by(res, fn {cluster_id, _} -> cluster_id end, fn {_, api_id} -> api_id end)
    |> Enum.each(fn {cluster_id, api_ids} ->
      cache_notify_resources(cluster_id, api_ids)
    end)

    {:noreply, state}
  end

  def handle_call({:load_events, cluster_id, events}, _from, state) do
    Enum.each(events, fn {event, api_id} ->
      update_spec_table(cluster_id, api_id, event)
      Logger.info(cluster: cluster_id, api_id: api_id, message: "Spec #{event}")
    end)

    {_, changed_apis} =
      Enum.reject(events, fn {event, _api_id} -> event == :deleted end)
      |> Enum.unzip()

    cache_notify_resources(cluster_id, changed_apis)

    {:reply, :ok, state}
  end

  def handle_call(req, _from, state) do
    Logger.error("Unhandled Request #{inspect(req)}")
    {:reply, {:error, :unhandled_request}, state}
  end

  defp insert_validated_spec(%Spec{} = spec, no_delete \\ false) do
    :ets.insert(
      @spec_table,
      {{spec.cluster_id, spec.api_id}, spec.hash, spec, DateTime.utc_now(), no_delete}
    )

    Application.get_env(:proxyconf, :external_spec_handlers, [])
    |> Enum.each(fn {module, function} ->
      apply(module, function, [spec])
    end)
  end

  defp update_spec_table(cluster_id, api_id, :deleted) do
    :ets.delete(@spec_table, {cluster_id, api_id})
    :ok
  end

  defp update_spec_table(cluster_id, api_id, _event) do
    case Spec.from_db(cluster_id, api_id) do
      {:error, reason} ->
        Logger.error(
          cluster: cluster_id,
          api: api_id,
          message: "Skip spec table update due to #{inspect(reason)}"
        )

      {:ok, %Spec{} = spec} ->
        insert_validated_spec(spec)
    end
  end

  def parse_spec_file(spec_filename, overrides \\ %{}) do
    with true <- File.exists?(spec_filename),
         ext <- Path.extname(spec_filename),
         {:ok, data} <- File.read(spec_filename),
         {:ok, parsed} <- parse_doc(ext, data),
         parsed <- DeepMerge.deep_merge(parsed, overrides),
         {:ok, internal_spec} <- Spec.from_oas3(spec_filename, parsed, data) do
      {:ok, internal_spec}
    else
      false -> {:error, :file_not_found}
      {error, false} -> {:error, error}
      e -> e
    end
  end

  defp parse_doc(".json", data), do: Jason.decode(data)

  defp parse_doc(yaml, data) when yaml in [".yaml", ".yml"],
    do: YamlElixir.read_from_string(data)

  defp cache_notify_resources(cluster_id, changed_apis) do
    {:ok, config} = ConfigGenerator.from_oas3_specs(cluster_id, changed_apis)

    resources =
      %{
        @listener => config.listeners,
        @cluster => config.clusters,
        @route_configuration => config.route_configurations,
        @tls_secret => config.tls_secret
      }
      |> apply_static_patches()
      |> apply_config_extensions()

    Enum.each(resources, fn {type, resources_for_type} ->
      hash = :erlang.phash2(resources_for_type)

      :ets.insert(
        @resources_table,
        {{cluster_id, type}, resources_for_type}
      )

      # not sending the resources to the stream pid, instead let the
      # the stream process fetch the resources if required
      ProxyConf.Stream.push_resource_changes(cluster_id, type, hash)
    end)
  end

  def get_resources(cluster_id, type_url) do
    case :ets.lookup(@resources_table, {cluster_id, type_url}) do
      [] -> []
      [{_, resources}] -> resources
    end
  end

  defp apply_static_patches(config) do
    default_patches_dir = Path.join(:code.priv_dir(:proxyconf), "config-patches")
    patches_dir = Application.get_env(:proxyconf, :config_patches, default_patches_dir)

    Enum.reduce(config, config, fn {type, configs_for_type}, acc ->
      patch_type = String.replace_prefix(type, "type.googleapis.com/", "")
      patch_location = Path.join(patches_dir, patch_type <> ".yaml")

      with true <- File.exists?(patch_location),
           {:ok, patch_data} <- File.read(patch_location),
           {:ok, patch} <- parse_doc(".yaml", patch_data) do
        Logger.debug("patch exists #{patch_location}")

        Map.put(
          acc,
          type,
          MapPatch.patch(configs_for_type, patch)
        )
      else
        false ->
          Logger.debug("no patch exists #{patch_location}")
          acc

        {:error, reason} ->
          Logger.error("Can't apply patch #{patch_location} due to #{inspect(reason)}")
          acc
      end
    end)
  end

  defp apply_config_extensions(config) do
    Application.get_env(:proxyconf, :config_extensions, [])
    |> Enum.reduce(config, fn {module, function}, acc ->
      patches = apply(module, function, [])

      Enum.reduce(patches, acc, fn {type, patch}, accacc ->
        if Map.has_key?(accacc, type) do
          config_for_type =
            Map.fetch!(accacc, type)
            |> MapPatch.patch(patch)

          Map.put(accacc, type, config_for_type)
        else
          Logger.warning("Invalid extension type #{type} in #{module}")

          accacc
        end
      end)
    end)
  end

  def iterate_specs(cluster_id, acc, iterator_fn) do
    :ets.foldl(
      fn {{_cluster_id, _api_id}, _hash, spec, _ts, _nodelete}, acc ->
        if cluster_id == spec.cluster_id do
          iterator_fn.(spec, acc)
        else
          acc
        end
      end,
      acc,
      @spec_table
    )
  end
end
