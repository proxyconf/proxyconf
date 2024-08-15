defmodule ProxyConf.ConfigCache do
  use GenServer
  alias ProxyConf.ConfigGenerator
  alias ProxyConf.MapPatch
  alias ProxyConf.Spec
  require Logger

  @cluster "type.googleapis.com/envoy.config.cluster.v3.Cluster"
  @listener "type.googleapis.com/envoy.config.listener.v3.Listener"
  @route_configuration "type.googleapis.com/envoy.config.route.v3.RouteConfiguration"

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
    wait_until_in_sync()
  end

  def wait_until_in_sync do
    if GenServer.call(__MODULE__, :in_sync?) do
      :ok
    else
      Process.sleep(100)
      wait_until_in_sync()
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
       version: 0,
       resources: %{},
       waiting_acks: %{},
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
    end)

    new_version =
      if map_size(changes) > 0 do
        state.version + 1
      else
        state.version
      end

    state =
      Enum.reduce(changes, state, fn {cluster_id, changed_files}, state_acc ->
        case resources(cluster_id, new_version, changed_files) do
          {:ok, resources_for_cluster} ->
            {streams, waiting_acks} =
              reply_resources(
                state.streams,
                cluster_id,
                Map.get(state_acc.resources, cluster_id, %{}),
                resources_for_cluster
              )

            %{
              state_acc
              | streams: streams,
                resources: Map.put(state_acc.resources, cluster_id, resources_for_cluster),
                waiting_acks: Map.merge(state.waiting_acks, waiting_acks)
            }

          :error ->
            state_acc
        end
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

        case resources(spec.cluster_id, new_version, %{spec_name => :external}) do
          {:ok, resources_for_cluster} ->
            {streams, waiting_acks} =
              reply_resources(
                state.streams,
                spec.cluster_id,
                Map.get(state.resources, spec.cluster_id, %{}),
                resources_for_cluster
              )

            {:reply, :ok,
             %{
               state
               | streams: streams,
                 resources: Map.put(state.resources, spec.cluster_id, resources_for_cluster),
                 waiting_acks: Map.merge(state.waiting_acks, waiting_acks),
                 version: new_version
             }}

          :error ->
            {:reply, :cant_load_spec, state}
        end

      error ->
        Logger.error("Can't load external spec #{spec_name} due to #{inspect(error)}")
        {:reply, error, state}
    end
  end

  def handle_call(:in_sync?, _from, state) do
    {:reply, map_size(state.waiting_acks), state}
  end

  def handle_call({:subscribe_stream, node_info, stream, type_url, version}, _from, state) do
    stream_config_key = {node_info, type_url}

    state =
      case Map.get(state.streams, stream_config_key) do
        %{stream: ^stream, version: ^version} ->
          # nothing to do
          Logger.debug(
            cluster: node_info.cluster,
            message: "#{type_url} Acked version by #{node_info.node_id} version #{version}"
          )

          waiting_acks =
            case Map.get(state.waiting_acks, stream_config_key, version) do
              other when other > version -> state.waiting_acks
              _ -> Map.delete(state.waiting_acks, stream_config_key)
            end

          %{state | waiting_acks: waiting_acks}

        %{stream: ^stream} ->
          Logger.info(
            cluster: node_info.cluster,
            message:
              "#{type_url} Duplicated subscribe from #{node_info.node_id} version #{version}"
          )

          state

        %{version: old_version} when version == 0 ->
          Logger.info(
            cluster: node_info.cluster,
            message:
              "#{type_url} Reconnect #{node_info.node_id} with previous version #{old_version}"
          )

          stream_config = %{stream: stream, version: old_version}

          {streams, waiting_acks} =
            reply_resources(
              %{{node_info, type_url} => stream_config},
              node_info.cluster,
              %{},
              Map.get(state.resources, node_info.cluster, %{})
            )

          %{
            state
            | streams: Map.merge(state.streams, streams),
              waiting_acks: Map.merge(state.waiting_acks, waiting_acks)
          }

        nil ->
          # new node

          Logger.info(
            cluster: node_info.cluster,
            message: "#{type_url} Added node #{node_info.node_id}"
          )

          stream_config = %{stream: stream, version: 0}

          if map_size(state.resources) > 0 do
            {streams, waiting_acks} =
              reply_resources(
                %{{node_info, type_url} => stream_config},
                node_info.cluster,
                %{},
                Map.get(state.resources, node_info.cluster, %{})
              )

            %{
              state
              | streams: Map.merge(state.streams, streams),
                waiting_acks: Map.merge(state.waiting_acks, waiting_acks)
            }
          else
            %{state | streams: Map.put(state.streams, {node_info, type_url}, stream_config)}
          end
      end

    {:reply, :ok, state}
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

  def parse_spec_file(spec_filename, overrides \\ %{}) do
    with true <- File.exists?(spec_filename),
         ext <- Path.extname(spec_filename),
         {:ok, data} <- File.read(spec_filename),
         {:ok, parsed} <- parse_spec(ext, data),
         parsed <- Map.merge(parsed, overrides),
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

  def reply_resources(streams, cluster_id, old_resources_for_cluster, resources_for_cluster) do
    {streams, waiting_acks} =
      Enum.map_reduce(streams, [], fn {{node_info, type_url} = stream_config_key,
                                       %{stream: stream, version: version} = stream_config},
                                      waiting_acks ->
        is_cluster_member = node_info.cluster == cluster_id

        old_resources_for_type = Map.get(old_resources_for_cluster, type_url)

        case Map.get(resources_for_cluster, type_url) do
          ^old_resources_for_type ->
            Logger.debug(cluster: cluster_id, message: "No changes for type #{type_url}")

            {{stream_config_key, stream_config}, waiting_acks}

          nil when is_cluster_member ->
            Logger.warning(
              cluster: cluster_id,
              message: "Can't provide resources for type #{type_url}"
            )

            {{stream_config_key, stream_config}, waiting_acks}

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

            {{stream_config_key, %{stream_config | version: new_version}},
             [{stream_config_key, "#{new_version}"} | waiting_acks]}

          _ ->
            {{stream_config_key, stream_config}, waiting_acks}
        end
      end)

    {Map.new(streams), Map.new(waiting_acks)}
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

  defp resources(cluster_id, version, changed_files) do
    case ConfigGenerator.from_oas3_specs(cluster_id, changed_files) do
      {:ok, config} ->
        resources =
          %{
            @listener => config.listeners,
            @cluster => config.clusters,
            @route_configuration => config.route_configurations
          }
          |> apply_config_extensions()
          |> tap(fn config ->
            File.mkdir_p!("/tmp/proxyconf")

            File.write!(
              "/tmp/proxyconf/#{cluster_id}-#{version}.config.json",
              Jason.encode!(config, pretty: true)
            )
          end)

        {:ok, resources}

      {:error, errored_files} ->
        Logger.warning(
          cluster: cluster_id,
          message: "spec files with errors #{Enum.join(errored_files, ", ")}"
        )

        :error
    end
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
