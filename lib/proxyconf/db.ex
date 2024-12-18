defmodule ProxyConf.Db do
  alias ProxyConf.Api.DbSpec
  alias ProxyConf.ConfigCache
  alias ProxyConf.Repo
  alias ProxyConf.Spec
  import Ecto.Query, only: [from: 2]

  def create_or_update(specs, opts \\ []) when is_list(specs) do
    tx_result =
      Repo.transaction(fn ->
        results =
          Enum.reduce(specs, [], fn spec, acc ->
            {event, id} = create_or_update_spec(spec)
            [{{event, spec.api_id}, id} | acc]
          end)

        {events, ids} = Enum.unzip(results)

        case Keyword.get(opts, :sync) do
          nil ->
            # only exists in single-spec mode
            [%Spec{cluster_id: cluster_id}] = specs
            {cluster_id, events}

          cluster_id ->
            {_num_deleted, api_ids} =
              from(spec in DbSpec,
                where: spec.cluster == ^cluster_id and spec.id not in ^ids,
                select: spec.api_id
              )
              |> Repo.delete_all()

            {cluster_id, Enum.map(api_ids, fn api_id -> {:deleted, api_id} end) ++ events}
        end
      end)

    case tx_result do
      {:ok, {cluster_id, events}} ->
        events = Enum.reject(events, fn {event, _api_id} -> event == :unchanged end)
        ConfigCache.load_events(cluster_id, events)

        :ok

      {:error, _reason} = e ->
        e
    end
  end

  defp create_or_update_spec(%Spec{cluster_id: cluster_id, api_id: api_id, spec: spec}) do
    data = Jason.encode!(spec)

    case get_spec(cluster_id, api_id) do
      nil ->
        db_spec =
          %DbSpec{}
          |> DbSpec.changeset(%{cluster: cluster_id, api_id: api_id, data: data})
          |> Repo.insert!()

        {:inserted, db_spec.id}

      %DbSpec{id: id, data: ^data} ->
        {:unchanged, id}

      %DbSpec{id: id} = db_spec ->
        db_spec
        |> DbSpec.changeset(%{data: data})
        |> Repo.update!()

        {:updated, id}
    end
  end

  def delete_spec(cluster_id, api_id) do
    case get_spec(cluster_id, api_id) do
      nil ->
        {:error, :not_found}

      %DbSpec{} = spec ->
        Repo.delete!(spec)
        ConfigCache.load_events(cluster_id, [{:deleted, api_id}])
        :ok
    end
  end

  def get_spec(cluster_id, api_id) do
    Repo.get_by(DbSpec, cluster: cluster_id, api_id: api_id)
  end

  def get_spec_ids(cluster_id) do
    from(spec in DbSpec,
      where: spec.cluster == ^cluster_id,
      select: spec.api_id
    )
    |> Repo.all()
  end

  def map(mapper_fn) do
    stream = Repo.stream(DbSpec)

    Repo.transaction(fn ->
      Enum.map(stream, mapper_fn)
    end)
  end
end
