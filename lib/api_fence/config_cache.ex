defmodule ApiFence.ConfigCache do
  use GenServer
  alias ApiFence.ConfigGenerator
  alias ApiFence.MapPatch
  require Logger

  @cluster "type.googleapis.com/envoy.config.cluster.v3.Cluster"
  @listener "type.googleapis.com/envoy.config.listener.v3.Listener"

  @spec_table :config_cache_tbl_specs
  @valid_oas3_file_extensions [".json", ".yaml", ".yml"]

  def start_link(_args) do
    :ets.new(@spec_table, [:public, :named_table])
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
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

    state =
      Enum.reduce(config_files, state, fn filename, state_acc ->
        update_result = maybe_update_spec_table(filename)
        # FIXME: remove below, this is here to always trigger a reload
        update_result = :changed

        case update_result do
          :unchanged ->
            state_acc

          :changed ->
            new_version = state.version + 1
            %{state_acc | version: new_version, resources: resources(new_version)}
        end
      end)

    reply_resources(Map.values(state.streams), state.resources)
    {:noreply, %{state | tref: nil}}
  end

  def handle_call({:subscribe_stream, node_info, stream}, _from, state) do
    # full sync first time discovery
    reply_resources([stream], state.resources)

    {:reply, :ok, %{state | streams: Map.put(state.streams, node_info, stream)}}
  end

  defp maybe_update_spec_table(filename) do
    extname = Path.extname(filename) |> String.downcase()

    with {:extname, true} <- {:extname, extname in @valid_oas3_file_extensions},
         {:ok, data} <- File.read(filename),
         hash <- :crypto.hash(:sha256, data) |> Base.encode64(),
         {:hash, _new_hash, ^hash, _data} <-
           {:hash, hash, compat_lookup_element(@spec_table, filename, 2, nil), data} do
      :unchanged
    else
      {:hash, new_hash, old_hash, data} when is_binary(old_hash) or is_nil(old_hash) ->
        result =
          parse_spec(extname, data)
          |> validate_spec()

        case result do
          {:ok, spec} ->
            api_id =
              Map.get(spec, "x-api-fence-api-id", Path.rootname(filename) |> Path.basename())

            spec = Map.put(spec, "x-api-fence-api-id", api_id)

            :ets.insert(@spec_table, {filename, new_hash, api_id, spec, DateTime.utc_now()})

            Application.get_env(:api_fence, :external_spec_handlers, [])
            |> Enum.each(fn {module, function} ->
              apply(module, function, [filename, api_id, spec])
            end)

            :changed

          {:error, _reason} = e ->
            e
        end

      {:extname, false} ->
        {:error, {:unsupported, extname}}

      {:error, _reason} = error ->
        error
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

  def get_spec(filename) do
    case :ets.lookup(@spec_table, filename) do
      [] ->
        {:error, :not_found}

      [{_filename, _hash, _api_id, spec, _ts}] ->
        {:ok, spec}
    end
  end

  defp parse_spec(".json", data), do: Jason.decode(data)

  defp parse_spec(yaml, data) when yaml in [".yaml", ".yml"],
    do: YamlElixir.read_from_string(data)

  defp validate_spec({:ok, spec}), do: {:ok, spec}
  defp validate_spec({:error, reason}), do: {:error, reason}

  def reply_resources(streams, all_resources) do
    Enum.each(all_resources, fn {resource_type_url, resources} ->
      {:ok, response} =
        Protobuf.JSON.from_decoded(
          %{
            "version_info" => "123",
            "type_url" => resource_type_url,
            "control_plane" => %{
              "identifier" => "#{node()}"
            },
            "resources" =>
              Enum.map(resources, fn r -> %{"@type" => resource_type_url, "value" => r} end),
            "nonce" => nonce()
          },
          Envoy.Service.Discovery.V3.DiscoveryResponse
        )

      Enum.each(streams, fn stream ->
        GRPC.Server.Stream.send_reply(stream, response, [])
      end)
    end)
  end

  def nonce do
    "#{node()}#{DateTime.utc_now() |> DateTime.to_unix(:nanosecond)}" |> Base.encode64()
  end

  def add_spec(spec_file) do
    if File.exists?(spec_file) do
      GenServer.call(__MODULE__, {:add_spec, spec_file})
    end
  end

  def subscribe_stream(node_info, stream) do
    GenServer.call(__MODULE__, {:subscribe_stream, node_info, stream}, :infinity)
  end

  def resources(version) do
    config = ConfigGenerator.from_oas3_specs(version)

    %{
      @listener => config.listeners,
      @cluster => config.clusters
    }
    |> apply_config_extensions(version)
  end

  defp apply_config_extensions(config, version) do
    Application.get_env(:api_fence, :config_extensions, [])
    |> Enum.reduce(config, fn {module, function}, acc ->
      patches = apply(module, function, [%{version: version}])

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
      fn {filename, _hash, api_id, spec, _ts}, acc ->
        iterator_fn.(filename, api_id, spec, acc)
      end,
      acc,
      @spec_table
    )
  end
end
