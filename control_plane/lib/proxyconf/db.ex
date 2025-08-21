defmodule ProxyConf.Db do
  alias ProxyConf.Api.DbSpec
  alias ProxyConf.Api.DbSecret
  alias ProxyConf.Repo
  alias ProxyConf.Commons.Spec
  import Ecto.Query, only: [from: 2]

  def create_or_update_specs(specs, opts \\ []) when is_list(specs) do
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
        ProxyConf.Adapter.load_events(cluster_id, events)

        :ok

      {:error, _reason} = e ->
        e
    end
  end

  defp create_or_update_spec(%Spec{
         cluster_id: cluster_id,
         api_id: api_id,
         api_url: api_url,
         listener_address: listener_address,
         listener_port: listener_port,
         spec: spec
       }) do
    data = JSON.encode!(spec)
    vhost = api_url.host

    case get_spec(cluster_id, api_id) do
      nil ->
        db_spec =
          %DbSpec{}
          |> DbSpec.changeset(%{
            cluster: cluster_id,
            api_id: api_id,
            listener_address: listener_address,
            listener_port: listener_port,
            vhost: vhost,
            data: data
          })
          |> Repo.insert!()

        {:inserted, db_spec.id}

      %DbSpec{
        id: id,
        data: ^data,
        listener_address: ^listener_address,
        listener_port: ^listener_port,
        vhost: ^vhost
      } ->
        {:unchanged, id}

      %DbSpec{id: id} = db_spec ->
        db_spec
        |> DbSpec.changeset(%{
          data: data,
          listener_address: listener_address,
          listener_port: listener_port,
          vhost: vhost
        })
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
        ProxyConf.Adapter.load_events(cluster_id, [{:deleted, api_id}])
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

  def create_or_update_secret(cluster_id, name, value) do
    case Repo.get_by(DbSecret, cluster: cluster_id, name: name) do
      %DbSecret{value: ^value} ->
        :ok

      %DbSecret{} = db_secret ->
        db_secret
        |> DbSecret.changeset(%{value: value})
        |> Repo.update!()

      nil ->
        %DbSecret{}
        |> DbSecret.changeset(%{cluster: cluster_id, name: name, value: value})
        |> Repo.insert!()
    end

    :ok
  end

  def maybe_get_secret(cluster_id, "%SECRET:" <> _ = secret_name) do
    case Regex.scan(~r/^%SECRET:(.+)%$/, secret_name) do
      [[_, secret_name]] ->
        secret = Repo.get_by!(DbSecret, cluster: cluster_id, name: secret_name)
        %{"secret" => %{"inline_string" => secret.value}}

      _ ->
        raise "Invalid cluster secret identifier #{secret_name}"
    end
  end

  def maybe_get_secret(_, secret), do: secret

  def map_reduce(mapper_fn, acc, where) do
    stream =
      from(spec in DbSpec,
        where: ^where,
        select: spec
      )
      |> Repo.stream()

    Repo.transaction(fn ->
      Enum.flat_map_reduce(stream, acc, mapper_fn)
    end)
  end
end
