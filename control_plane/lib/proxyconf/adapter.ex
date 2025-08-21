defmodule ProxyConf.Adapter do
  @behaviour ExControlPlane.Adapter
  require Logger

  alias ProxyConf.Db
  alias ProxyConf.Commons.ConfigGenerator
  alias ProxyConf.Commons.Spec

  def init do
    %{}
  end

  def load_events(cluster_id, events) do
    ExControlPlane.ConfigCache.load_events(cluster_id, events)
  end

  def generate_resources(_state, cluster_id, changed_apis) do
    {:ok, config} =
      ConfigGenerator.from_oas3_specs(
        spec_provider(),
        cluster_id,
        changed_apis
      )

    %ExControlPlane.Adapter.ClusterConfig{
      clusters: config.clusters,
      listeners: config.listeners,
      route_configurations: config.route_configurations,
      secrets: config.secrets
    }
  end

  defp spec_provider() do
    fn cluster_id, acc, mapper_fn ->
      {:ok, {_, result}} =
        Db.map_reduce(
          fn db_spec, acc ->
            case Spec.from_oas3(db_spec.api_id, JSON.decode!(db_spec.data), db_spec.data) do
              {:ok, spec} ->
                {[], mapper_fn.(spec, acc)}

              {:error, reason} ->
                Logger.error(cluster: db_spec.cluster, api_id: db_spec.api_id, message: reason)
                {[], acc}
            end
          end,
          acc,
          cluster: cluster_id
        )

      result
    end
  end

  def map_reduce(_state, mapper_fn, acc) do
    {:ok, result} =
      Db.map_reduce(
        fn db_spec, acc ->
          case Spec.from_oas3(db_spec.api_id, JSON.decode!(db_spec.data), db_spec.data) do
            {:ok, spec} ->
              # it's a flat_map_reduce internally, let's conform
              api_config = spec_to_api_config(spec)
              {v, acc} = mapper_fn.(api_config, acc)
              {[v], acc}

            {:error, reason} ->
              Logger.error(cluster: db_spec.cluster, api_id: db_spec.api_id, message: reason)
              {[], acc}
          end
        end,
        acc,
        []
      )

    result
  end

  def get_api_config(_state, cluster_id, api_id) do
    with %ProxyConf.Api.DbSpec{} = db_spec <- Db.get_spec(cluster_id, api_id),
         {:ok, %Spec{} = spec} <- Spec.from_oas3(api_id, JSON.decode!(db_spec.data), db_spec.data) do
      {:ok, spec_to_api_config(spec)}
    else
      nil ->
        {:error, :not_found}

      {:error, _reason} = e ->
        e
    end
  end

  defp spec_to_api_config(%Spec{api_id: api_id, cluster_id: cluster} = spec) do
    %ExControlPlane.Adapter.ApiConfig{api_id: api_id, cluster: cluster, config: spec}
  end
end
