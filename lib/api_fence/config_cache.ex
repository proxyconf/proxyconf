defmodule ApiFence.ConfigCache do
  use GenServer
  alias ApiFence.ConfigGenerator
  alias ApiFence.MapPatch
  require Logger

  @cluster "type.googleapis.com/envoy.config.cluster.v3.Cluster"
  @listener "type.googleapis.com/envoy.config.listener.v3.Listener"

  @spec_table :config_cache_tbl_specs
  @valid_oas3_file_extensions [".json", ".yaml", ".yml"]
  @oas3_0_schema File.read!("priv/schemas/oas3_0.json") |> Jason.decode!() |> JsonXema.new()
  @oas3_1_schema File.read!("priv/schemas/oas3_1.json") |> Jason.decode!() |> JsonXema.new()

  def start_link(_args) do
    :ets.new(@spec_table, [:public, :named_table])
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def load_external_parsed_spec(spec_name, spec) do
    GenServer.call(__MODULE__, {:load_external_parsed_spec, spec_name, spec})
  end

  def init(_args) do
    config_directories = Application.fetch_env!(:api_fence, :config_directories)
    {:ok, _pid} = FileSystem.start_link(dirs: config_directories, name: :oas3_watcher)
    FileSystem.subscribe(:oas3_watcher)
    Process.send(self(), :reload, [])

    {:ok,
     %{
       streams: %{},
       version: 1,
       resources: %{},
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
        # FIXME: remove below, this is here to always trigger a reload
        update_result = :changed

        case update_result do
          :ignored ->
            changes_acc

          :unchanged ->
            changes_acc

          :changed ->
            Map.put(changes_acc, filename, :changed)
        end
      end)

    if map_size(changes) > 0 do
      resources = resources(changes)
      streams = reply_resources(state.streams, resources)
      {:noreply, %{state | tref: nil, streams: streams, resources: resources}}
    else
      {:noreply, state}
    end
  end

  def handle_call({:load_external_parsed_spec, spec_name, spec}, _from, state)
      when is_map(spec) do
    case validate_spec(spec) do
      {:ok, spec} ->
        hash = spec_hash(Jason.encode!(spec))
        api_id = insert_validated_spec(spec_name, spec, hash)

        resources = resources(%{spec_name => :external})
        streams = reply_resources(state.streams, resources)
        {:reply, :ok, %{state | streams: streams, resources: resources}}

      error ->
        Logger.error("Can't load external spec #{spec_name} due to #{inspect(error)}")
        {:reply, error, state}
    end
  end

  def handle_call({:subscribe_stream, node_info, stream, type_url, version}, _from, state) do
    streams =
      case Map.get(state.streams, {node_info, type_url}) do
        %{stream: ^stream, version: ^version} = stream_config ->
          # nothing to do
          Logger.debug(
            "#{type_url} Acked version by #{node_info.cluster} node #{node_info.node_id} version #{version}"
          )

          state.streams

        %{stream: ^stream} ->
          Logger.info(
            "#{type_url} Duplicated subscribe from #{node_info.cluster} node #{node_info.node_id} version #{version}"
          )

          state.streams

        %{version: old_version} = stream_config when version == 0 ->
          Logger.info(
            "#{type_url} Reconnect #{node_info.cluster} node #{node_info.node_id} with previous version #{old_version}"
          )

          stream_config = %{stream: stream, version: 0}

          Map.merge(
            state.streams,
            reply_resources(
              %{{node_info, type_url} => stream_config},
              state.resources
            )
          )

        nil ->
          # new node
          Logger.info("#{type_url} Added #{node_info.cluster} node #{node_info.node_id}")
          stream_config = %{stream: stream, version: 0}

          Map.merge(
            state.streams,
            reply_resources(%{{node_info, type_url} => stream_config}, state.resources)
          )
      end

    {:reply, :ok, %{state | streams: streams}}
  end

  defp insert_validated_spec(filename, spec, hash, no_delete \\ false) do
    api_id = Map.get(spec, "x-api-fence-api-id", Path.rootname(filename) |> Path.basename())

    spec = Map.put(spec, "x-api-fence-api-id", api_id)

    :ets.insert(@spec_table, {filename, hash, api_id, spec, DateTime.utc_now(), no_delete})

    Application.get_env(:api_fence, :external_spec_handlers, [])
    |> Enum.each(fn {module, function} ->
      apply(module, function, [filename, api_id, spec])
    end)

    api_id
  end

  defp spec_hash(data) when is_binary(data) do
    :crypto.hash(:sha256, data) |> Base.encode64()
  end

  defp maybe_update_spec_table(filename) do
    extname = Path.extname(filename) |> String.downcase()

    with {:extname, true} <- {:extname, extname in @valid_oas3_file_extensions},
         {:ok, data} <- File.read(filename),
         hash <- spec_hash(data),
         {:hash, _new_hash, ^hash, _data} <-
           {:hash, hash, compat_lookup_element(@spec_table, filename, 2, nil), data} do
      :unchanged
    else
      {:hash, new_hash, old_hash, data} when is_binary(old_hash) or is_nil(old_hash) ->
        result =
          parse_spec(extname, data)
          |> validate_spec()

        case result do
          {:ok, spec} when old_hash == nil ->
            api_id = insert_validated_spec(filename, spec, new_hash)
            Logger.info("Loaded new spec for API #{api_id} from #{filename}")
            :changed

          {:ok, spec} ->
            api_id = insert_validated_spec(filename, spec, new_hash)
            Logger.info("Loaded updated spec for API #{api_id} from #{filename}")
            :changed

          {:error, reason} ->
            Logger.warning(
              "Validation error when parsing spec #{filename} due to #{inspect(reason)}"
            )

            :ignored
        end

      {:extname, false} ->
        Logger.info(
          "Don't load file #{filename} only #{inspect(@valid_oas3_spec_extensions)} are allowed"
        )

        :ignored

      {:error, reason} ->
        Logger.error("Loading error when loading spec #{filename} due to #{inspect(reason)}")
        :ignored
    end
  end

  def compat_lookup_element(table, key, pos, default) do
    # :ets.lookup_element/4 introduced in OTP26
    :ets.lookup_element(table, key, pos, default)
  rescue
    _ ->
      try do
        :ets.lookup_element(table, key, pos)
      rescue
        _ ->
          default
      end
  end

  defp parse_spec(".json", data), do: Jason.decode(data)

  defp parse_spec(yaml, data) when yaml in [".yaml", ".yml"],
    do: YamlElixir.read_from_string(data)

  defp validate_spec({:ok, spec}), do: validate_spec(spec)
  defp validate_spec({:error, reason}), do: {:error, reason}

  defp validate_spec(%{"openapi" => "3.1" <> _} = spec) do
    case JsonXema.validate(@oas3_1_schema, spec) do
      :ok ->
        {:ok, spec}

      {:error, errors} ->
        {:error, errors}
    end
  end

  defp validate_spec(%{"openapi" => "3.0" <> _} = spec) do
    case JsonXema.validate(@oas3_0_schema, spec) do
      :ok ->
        {:ok, spec}

      {:error, errors} ->
        {:error, errors}
    end
  end

  def reply_resources(streams, all_resources) do
    Enum.map(streams, fn {{node_info, type_url} = stream_config_key,
                          %{stream: stream, version: version} = stream_config} ->
      case Map.get(all_resources, type_url) do
        nil ->
          Logger.warning("Can't provide resources for type #{type_url}")
          {stream_config_key, stream_config}

        resources_for_type ->
          new_version = version + 1

          {:ok, response} =
            Protobuf.JSON.from_decoded(
              %{
                "version_info" => "#{new_version}",
                "type_url" => type_url,
                "control_plane" => %{
                  "identifier" => "#{node()}"
                },
                "resources" =>
                  Enum.map(resources_for_type, fn r -> %{"@type" => type_url, "value" => r} end),
                "nonce" => nonce()
              },
              Envoy.Service.Discovery.V3.DiscoveryResponse
            )

          GRPC.Server.Stream.send_reply(stream, response, [])
          {stream_config_key, %{stream_config | version: new_version}}
      end
    end)
    |> Map.new()
  end

  def nonce do
    "#{node()}#{DateTime.utc_now() |> DateTime.to_unix(:nanosecond)}" |> Base.encode64()
  end

  def add_spec(spec_file) do
    if File.exists?(spec_file) do
      GenServer.call(__MODULE__, {:add_spec, spec_file})
    end
  end

  def subscribe_stream(node_info, stream, type_url, version) do
    GenServer.call(
      __MODULE__,
      {:subscribe_stream, node_info, stream, type_url, version},
      :infinity
    )
  end

  def resources(changes) do
    config = ConfigGenerator.from_oas3_specs(changes)

    %{
      @listener => config.listeners,
      @cluster => config.clusters
    }
    |> apply_config_extensions()
  end

  defp apply_config_extensions(config) do
    Application.get_env(:api_fence, :config_extensions, [])
    |> Enum.reduce(config, fn {module, function}, acc ->
      patches = apply(module, function, [])

      Enum.reduce(patches, acc, fn {type, patch}, accacc ->
        if Map.has_key?(accacc, type) do
          config_for_type =
            Map.fetch!(acc, type)
            |> MapPatch.patch(patch)

          Map.put(acc, type, config_for_type)
        else
          Logger.warning("Invalid extension type #{type} in #{module}")

          acc
        end
      end)
    end)
    |> tap(fn config ->
      File.write!("/tmp/api-fence.config.json", Jason.encode!(config))
    end)
  end

  def iterate_specs(acc, iterator_fn) do
    :ets.foldl(
      fn {filename, _hash, api_id, spec, _ts, _nodelete}, acc ->
        iterator_fn.(filename, api_id, spec, acc)
      end,
      acc,
      @spec_table
    )
  end
end
