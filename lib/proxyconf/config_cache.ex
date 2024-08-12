defmodule ProxyConf.ConfigCache do
  use GenServer
  alias ProxyConf.ConfigGenerator
  alias ProxyConf.MapPatch
  alias ProxyConf.Spec
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

  # only used for testing
  def load_external_spec(spec_name, spec) do
    GenServer.call(__MODULE__, {:load_external_spec, spec_name, spec})
  end

  def init(_args) do
    config_directories = Application.fetch_env!(:proxyconf, :config_directories)
    {:ok, _pid} = FileSystem.start_link(dirs: config_directories, name: :oas3_watcher)
    FileSystem.subscribe(:oas3_watcher)
    Process.send(self(), :reload, [])

    {:ok,
     %{
       streams: %{},
       version: 0,
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

    new_version =
      if map_size(changes) > 0 do
        state.version + 1
      else
        state.version
      end

    state =
      Enum.reduce(changes, state, fn {cluster_id, changed_files}, state_acc ->
        resources = resources(cluster_id, new_version, changed_files)
        streams = reply_resources(state.streams, cluster_id, resources)
        %{state_acc | streams: streams, resources: resources}
      end)

    {:noreply, %{state | tref: nil, version: new_version}}
  end

  def handle_call({:load_external_spec, spec_name, spec}, _from, state)
      when is_map(spec) do
    Logger.notice(
      file_name: spec_name,
      api_id: Map.get(spec, "x-proxyconf-id", "UNKNOWN"),
      message: "loading external spec"
    )

    case validate_spec(spec_name, spec, :erlang.term_to_binary(spec)) do
      {:ok, %Spec{} = spec} ->
        insert_validated_spec(spec)
        new_version = state.version + 1

        resources = resources(spec.cluster_id, new_version, %{spec_name => :external})
        streams = reply_resources(state.streams, spec.cluster_id, resources)
        {:reply, :ok, %{state | streams: streams, resources: resources, version: new_version}}

      error ->
        Logger.error("Can't load external spec #{spec_name} due to #{inspect(error)}")
        {:reply, error, state}
    end
  end

  def handle_call({:subscribe_stream, node_info, stream, type_url, version}, _from, state) do
    streams =
      case Map.get(state.streams, {node_info, type_url}) do
        %{stream: ^stream, version: ^version} ->
          # nothing to do
          Logger.debug(
            cluster: node_info.cluster,
            message: "#{type_url} Acked version by #{node_info.node_id} version #{version}"
          )

          state.streams

        %{stream: ^stream} ->
          Logger.info(
            cluster: node_info.cluster,
            message:
              "#{type_url} Duplicated subscribe from #{node_info.node_id} version #{version}"
          )

          state.streams

        %{version: old_version} when version == 0 ->
          Logger.info(
            cluster: node_info.cluster,
            message:
              "#{type_url} Reconnect #{node_info.node_id} with previous version #{old_version}"
          )

          stream_config = %{stream: stream, version: old_version}

          Map.merge(
            state.streams,
            reply_resources(
              %{{node_info, type_url} => stream_config},
              node_info.cluster,
              state.resources
            )
          )

        nil ->
          # new node
          Logger.info(
            cluster: node_info.cluster,
            message: "#{type_url} Added node #{node_info.node_id}"
          )

          stream_config = %{stream: stream, version: 0}

          Map.merge(
            state.streams,
            reply_resources(
              %{{node_info, type_url} => stream_config},
              node_info.cluster,
              state.resources
            )
          )
      end

    {:reply, :ok, %{state | streams: streams}}
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
              message: "Validation error when parsing spec #{filename} due to #{inspect(reason)}"
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

  def parse_spec_file(spec) do
    with true <- File.exists?(spec),
         ext <- Path.extname(spec),
         {:ok, data} <- File.read(spec),
         {:ok, parsed} <- parse_spec(ext, data),
         {:ok, internal_spec} <- validate_spec(spec, parsed, data) do
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
  defp validate_spec(_filename, {:error, reason}, _data), do: {:error, reason}

  defp validate_spec(filename, %{"openapi" => "3.1" <> _} = spec, data) do
    case JsonXema.validate(@oas3_1_schema, spec) do
      :ok ->
        Spec.from_oas3(filename, spec, data)

      {:error, errors} ->
        {:error, errors}
    end
  end

  defp validate_spec(filename, %{"openapi" => "3.0" <> _} = spec, data) do
    case JsonXema.validate(@oas3_0_schema, spec) do
      :ok ->
        Spec.from_oas3(filename, spec, data)

      {:error, errors} ->
        {:error, errors}
    end
  end

  def reply_resources(streams, cluster_id, all_resources) do
    Enum.map(streams, fn {{node_info, type_url} = stream_config_key,
                          %{stream: stream, version: version} = stream_config} ->
      is_cluster_member = node_info.cluster == cluster_id

      case Map.get(all_resources, type_url) do
        nil when is_cluster_member ->
          Logger.warning("Can't provide resources for type #{type_url}")
          {stream_config_key, stream_config}

        resources_for_type when is_cluster_member ->
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

          Logger.debug(
            cluster: node_info.cluster,
            message: "#{type_url} Push new version #{new_version} to #{node_info.node_id}"
          )

          {stream_config_key, %{stream_config | version: new_version}}

        _ ->
          {stream_config_key, stream_config}
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

  def resources(cluster_id, version, changed_files) do
    config = ConfigGenerator.from_oas3_specs(cluster_id, changed_files)

    %{
      @listener => config.listeners,
      @cluster => config.clusters
    }
    |> apply_config_extensions()
    |> tap(fn config ->
      File.mkdir_p!("/tmp/proxyconf")

      File.write!(
        "/tmp/proxyconf/#{cluster_id}-#{version}.config.json",
        Jason.encode!(config, pretty: true)
      )
    end)
  end

  defp apply_config_extensions(config) do
    Application.get_env(:proxyconf, :config_extensions, [])
    |> Enum.reduce(config, fn {module, function}, acc ->
      patches = apply(module, function, [])

      Enum.reduce(patches, acc, fn {type, patch}, accacc ->
        IO.inspect({type, patch, accacc})

        if Map.has_key?(accacc, type) do
          config_for_type =
            Map.fetch!(accacc, type)
            |> MapPatch.patch(patch)

          IO.inspect("==================>")

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
