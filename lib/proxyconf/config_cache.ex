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
  @valid_oas3_file_extensions [".json", ".yaml", ".yml"]
  @external_resource "priv/schemas/proxyconf.json"
  @ext_schema File.read!("priv/schemas/proxyconf.json") |> Jason.decode!()

  @merge_resolver fn
    _, l, r when is_list(l) and is_list(r) ->
      Enum.uniq(l ++ r)

    _, _, _ ->
      DeepMerge.continue_deep_merge()
  end

  @oas3_0_schema File.read!("priv/schemas/oas3_0.json")
                 |> Jason.decode!()
                 |> DeepMerge.deep_merge(@ext_schema, @merge_resolver)
                 |> JsonXema.new()

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

  defp wait_until_in_sync(cluster_id) do
    if ProxyConf.Stream.in_sync(cluster_id) do
      :ok
    else
      Process.sleep(100)
      wait_until_in_sync(cluster_id)
    end
  end

  def init(_args) do
    config_directories = Application.fetch_env!(:proxyconf, :config_directories)
    {:ok, _pid} = FileSystem.start_link(dirs: config_directories, name: :oas3_watcher)
    FileSystem.subscribe(:oas3_watcher)
    Process.send(self(), :reload, [])

    {:ok,
     %{
       streams: %{},
       tref: nil,
       config_directories: config_directories
     }}
  end

  def handle_info({:file_event, _watcher_pid, {path, events}}, state) do
    extname = Path.extname(path)

    if extname in @valid_oas3_file_extensions and
         List.first(events) in [:created, :modified, :deleted] do
    end

    if state.tref do
      Process.cancel_timer(state.tref)
    end

    tref = Process.send_after(self(), :reload, 5000)
    {:noreply, %{state | tref: tref}}
  end

  def handle_info(:reload, state) do
    config_files =
      Enum.flat_map(state.config_directories, fn directory ->
        File.ls!(directory) |> Enum.map(fn f -> Path.join(directory, f) end)
      end)

    changes =
      Enum.reduce(config_files, %{}, fn filename, changes_acc ->
        update_result = maybe_update_spec_table(filename)

        case update_result do
          :ignored ->
            changes_acc

          :unchanged ->
            changes_acc

          {:changed, cluster_id} ->
            Map.update(changes_acc, cluster_id, [], fn changed_files ->
              [filename | changed_files]
            end)
        end
      end)

    Enum.each(changes, fn {cluster_id, changed_files} ->
      Logger.info(
        cluster: cluster_id,
        message: "Changed specs #{Enum.join(changed_files, ", ")}"
      )

      cache_notify_resources(cluster_id, changed_files)
    end)

    {:noreply, %{state | tref: nil}}
  end

  def handle_call({:load_external_spec, spec_name, spec}, _from, state)
      when is_map(spec) do
    case validate_spec(spec_name, spec, :erlang.term_to_binary(spec)) do
      {:ok, %Spec{} = spec} ->
        Logger.notice(
          file_name: spec_name,
          api_id: spec.api_id,
          message: "loading external spec"
        )

        insert_validated_spec(spec)
        cache_notify_resources(spec.cluster_id, %{spec_name => :external})
        {:reply, {:ok, spec.cluster_id}, state}

      error ->
        Logger.error("Can't load external spec #{spec_name} due to #{inspect(error)}")
        {:reply, error, state}
    end
  end

  defp insert_validated_spec(%Spec{} = spec, no_delete \\ false) do
    :ets.insert(
      @spec_table,
      {spec.filename, spec.hash, spec, DateTime.utc_now(), no_delete}
    )

    Application.get_env(:proxyconf, :external_spec_handlers, [])
    |> Enum.each(fn {module, function} ->
      apply(module, function, [spec])
    end)
  end

  defp maybe_update_spec_table(filename) do
    extname = Path.extname(filename) |> String.downcase()

    with {:extname, true} <- {:extname, extname in @valid_oas3_file_extensions},
         {:ok, data} <- File.read(filename),
         hash <- Spec.gen_hash(data),
         {:hash, ^hash, _data} <-
           {:hash, compat_lookup_element(@spec_table, filename, 2, nil), data} do
      :unchanged
    else
      {:hash, old_hash, data} when is_binary(old_hash) or is_nil(old_hash) ->
        parse_result = parse_spec(extname, data)
        result = validate_spec(filename, parse_result, data)

        case result do
          {:ok, %Spec{} = spec} when old_hash == nil ->
            insert_validated_spec(spec)

            Logger.info(
              cluster: spec.cluster_id,
              api: spec.api_id,
              message: "Loaded new spec from #{spec.filename}"
            )

            {:changed, spec.cluster_id}

          {:ok, %Spec{} = spec} ->
            insert_validated_spec(spec)

            Logger.info(
              cluster: spec.cluster_id,
              api: spec.api_id,
              message: "Loaded updated spec from #{spec.filename}"
            )

            {:changed, spec.cluster_id}

          {:error, reason} ->
            Logger.warning(
              message: "Validation error when parsing spec #{filename} due to #{reason}"
            )

            :ignored
        end

      {:extname, false} ->
        Logger.info(
          "Don't load file #{filename} only #{inspect(@valid_oas3_file_extensions)} are allowed"
        )

        :ignored

      {:error, reason} ->
        Logger.error("Loading error when loading spec #{filename} due to #{inspect(reason)}")
        :ignored
    end
  end

  def compat_lookup_element(table, key, pos, default) do
    try do
      :ets.lookup_element(table, key, pos)
    rescue
      _ ->
        default
    end
  end

  def parse_spec_file(spec_filename, overrides \\ %{}) do
    with true <- File.exists?(spec_filename),
         ext <- Path.extname(spec_filename),
         {:ok, data} <- File.read(spec_filename),
         {:ok, parsed} <- parse_spec(ext, data),
         parsed <- DeepMerge.deep_merge(parsed, overrides),
         {:ok, internal_spec} <- validate_spec(spec_filename, parsed, data) do
      {:ok, internal_spec}
    else
      false -> {:error, :file_not_found}
      {error, false} -> {:error, error}
      e -> e
    end
  end

  defp parse_spec(".json", data), do: Jason.decode(data)

  defp parse_spec(yaml, data) when yaml in [".yaml", ".yml"],
    do: YamlElixir.read_from_string(data)

  defp validate_spec(filename, {:ok, spec}, data), do: validate_spec(filename, spec, data)
  defp validate_spec(_filename, {:error, reason}, _), do: {:error, reason}

  defp validate_spec(filename, spec, data) do
    case JsonXema.validate(@oas3_0_schema, spec) do
      :ok ->
        Spec.from_oas3(filename, spec, data)

      {:error, %JsonXema.ValidationError{} = error} ->
        {:error, JsonXema.ValidationError.message(error)}
    end
  end

  def add_spec(spec_file) do
    if File.exists?(spec_file) do
      GenServer.call(__MODULE__, {:add_spec, spec_file})
    end
  end

  defp cache_notify_resources(cluster_id, changed_files) do
    {:ok, config} = ConfigGenerator.from_oas3_specs(cluster_id, changed_files)

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
      patch_location = Path.join(patches_dir, patch_type <> ".json")

      with true <- File.exists?(patch_location),
           {:ok, patch_data} <- File.read(patch_location),
           {:ok, patch} <- Jason.decode(patch_data) do
        Logger.debug("patch exists #{patch_location}")

        Map.put(
          acc,
          type,
          MapPatch.patch(configs_for_type, patch)
        )
      else
        false ->
          Logger.error("no patch exists #{patch_location}")
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
      fn {_filename, _hash, spec, _ts, _nodelete}, acc ->
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
