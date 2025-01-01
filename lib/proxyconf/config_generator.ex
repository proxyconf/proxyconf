defmodule ProxyConf.ConfigGenerator do
  @moduledoc """
    This module implements the config generator that produces the different
    Envoy resources.

    Every config generator module (ProxyConf.ConfigGenerator.*) is able to
    produce generator functions for resources or fragments used by a resource 
    by calling the `from_spec_gen/1` function, passing the internal Spec struct. 
    The produced resource generators are tagged by a grouping key (e.g. a listener).
    The tagging is required to group resources together as multiple OpenAPI 
    specs could configure the same listener, and therefore listener specific
    configurations (but potentially specific to each space) like TLS/mTLS or
    VHost matching must be aggregated.
    
  """
  alias ProxyConf.ConfigGenerator.Cluster
  alias ProxyConf.ConfigGenerator.FilterChain
  alias ProxyConf.ConfigGenerator.Listener
  alias ProxyConf.ConfigGenerator.Route
  alias ProxyConf.ConfigGenerator.RouteConfiguration
  alias ProxyConf.ConfigGenerator.VHost
  alias ProxyConf.ConfigGenerator.DownstreamAuth
  alias ProxyConf.ConfigGenerator.DownstreamTls
  alias ProxyConf.ConfigGenerator.UpstreamAuth
  alias ProxyConf.Spec
  alias ProxyConf.ConfigCache
  require Logger

  defstruct(
    skip_errors: true,
    listeners: %{},
    filter_chains: %{},
    clusters: %{},
    vhosts: %{},
    routes: %{},
    route_configurations: %{},
    http_connection_managers: %{},
    source_ip_ranges: %{},
    downstream_tls: %{},
    downstream_auth: %{},
    upstream_auth: %{},
    errors: []
  )

  def from_oas3_specs(cluster_id, _changes) do
    ConfigCache.iterate_specs(cluster_id, %__MODULE__{}, fn %Spec{} = spec, config ->
      try do
        listener_name = Listener.name(spec)
        vhost_unifier = %{listener: listener_name, host: spec.api_url.host}

        %__MODULE__{
          config
          | listeners:
              add_to_group(listener_name, config.listeners, Listener.from_spec_gen(spec)),
            filter_chains:
              add_to_group(vhost_unifier, config.filter_chains, FilterChain.from_spec_gen(spec)),
            source_ip_ranges:
              add_to_group(vhost_unifier, config.source_ip_ranges, spec.allowed_source_ips),
            http_connection_managers:
              add_to_group(
                vhost_unifier,
                config.http_connection_managers,
                spec.http_connection_manager
              ),
            vhosts: add_to_group(vhost_unifier, config.vhosts, VHost.from_spec_gen(spec)),
            routes: add_to_group(vhost_unifier, config.routes, Route.from_spec_gen(spec)),
            route_configurations:
              add_to_group(
                vhost_unifier,
                config.route_configurations,
                RouteConfiguration.from_spec_gen(spec)
              ),
            clusters: add_to_group(vhost_unifier, config.clusters, Cluster.from_spec_gen(spec)),
            downstream_tls:
              add_to_group(
                vhost_unifier,
                config.downstream_tls,
                DownstreamTls.from_spec_gen(spec)
              ),
            downstream_auth:
              add_to_group(
                vhost_unifier,
                config.downstream_auth,
                DownstreamAuth.from_spec_gen(spec)
              ),
            upstream_auth:
              add_to_group(vhost_unifier, config.upstream_auth, UpstreamAuth.from_spec_gen(spec))
        }
      rescue
        e ->
          Logger.warning(
            cluster: cluster_id,
            api_id: spec.api_id,
            message: "Skipping OpenAPI spec due to: #{Exception.message(e)}"
          )

          %__MODULE__{config | errors: [spec.api_id | config.errors]}
      end
    end)
    |> generate()
  end

  defp generate(%__MODULE__{
         listeners: listeners,
         filter_chains: filter_chains,
         source_ip_ranges: source_ip_ranges,
         http_connection_managers: http_connection_managers,
         clusters: clusters,
         vhosts: vhosts,
         routes: routes,
         route_configurations: route_configurations,
         downstream_tls: downstream_tls,
         downstream_auth: downstream_auth,
         upstream_auth: upstream_auth
       }) do
    source_ip_ranges = materialize_group(source_ip_ranges)
    http_connection_managers = materialize_group(http_connection_managers)
    routes = materialize_group(routes)
    downstream_tls = materialize_group(downstream_tls)
    downstream_auth = materialize_group(downstream_auth)
    upstream_auth = materialize_group(upstream_auth)

    {all_clusters, routes} =
      Enum.reduce(routes, {%{}, %{}}, fn {unifier, routes_and_clusters},
                                         {clusters_acc, routes_acc} ->
        {routes, clusters} = Enum.unzip(routes_and_clusters)

        {Map.put(clusters_acc, unifier, List.flatten(clusters) |> Enum.uniq()),
         Map.put(routes_acc, unifier, List.flatten(routes) |> Enum.uniq())}
      end)

    vhosts = materialize_group(vhosts, [routes])
    route_configurations = materialize_group(route_configurations, [:unifier, vhosts])

    {filter_chains_by_listener, downstream_auth_clusters, secrets} =
      materialize_group(filter_chains, [
        vhosts,
        source_ip_ranges,
        http_connection_managers,
        downstream_auth,
        downstream_tls,
        upstream_auth
      ])
      |> Enum.group_by(
        fn {unifier, _} -> unifier.listener end,
        fn {_unifier, filter_chains_by_listener} ->
          filter_chains_by_listener
        end
      )
      |> Enum.reduce({%{}, [], Map.values(downstream_tls)}, fn {listener_unifier, filter_chains},
                                                               {acc_filter_chains,
                                                                acc_downstream_auth_clusters,
                                                                acc_secrets} ->
        {filter_chains, downstream_auth_clusters, upstream_auth_secrets} =
          List.flatten(filter_chains) |> :lists.unzip3()

        {Map.update(acc_filter_chains, listener_unifier, filter_chains, fn v ->
           filter_chains ++ v
         end), [downstream_auth_clusters | acc_downstream_auth_clusters],
         [upstream_auth_secrets | acc_secrets]}
      end)

    listeners = materialize_group(listeners, [filter_chains_by_listener])

    clusters = materialize_group(clusters, [all_clusters])

    {:ok,
     %{
       clusters:
         List.flatten(Map.values(clusters) ++ downstream_auth_clusters)
         |> Enum.uniq(),
       listeners: Map.values(listeners) |> List.flatten(),
       route_configurations: Map.values(route_configurations) |> List.flatten(),
       tls_secret: List.flatten(secrets) |> Enum.uniq()
     }}
  end

  # optimizing group_by / uniq_by calls

  defp add_to_group(unifier, group, item) do
    Map.update(group, unifier, MapSet.new([item]), fn items -> MapSet.put(items, item) end)
  end

  defp materialize_group(group, dependencies \\ []) do
    Enum.reduce(Map.keys(group), group, fn unifier, group_acc ->
      materialize_group_items(unifier, group_acc, dependencies)
    end)
  end

  defp materialize_group_items(unifier, group, dependencies) do
    args =
      Enum.map(dependencies, fn
        # inject unifier
        :unifier -> unifier
        d -> Map.fetch!(d, unifier)
      end)

    Map.update!(group, unifier, fn items ->
      items =
        Enum.flat_map(items, fn
          {generator_function, context}
          when is_function(generator_function) and is_map(context) ->
            try do
              [apply(generator_function, args ++ [context])]
            rescue
              e ->
                Logger.error(
                  "Can't materialize config item in group #{inspect(unifier)} due to #{inspect(e)}"
                )

                []
            end

          item ->
            [item]
        end)
        |> List.flatten()

      unique_after_materialize(%{}, items) |> Map.values()
    end)
  end

  defp unique_after_materialize(items, %{name: name} = item), do: Map.put(items, name, item)

  defp unique_after_materialize(items, multi_item) when is_list(multi_item),
    do: Enum.reduce(multi_item, items, fn it, acc -> unique_after_materialize(acc, it) end)

  defp unique_after_materialize(items, item), do: Map.put(items, :erlang.phash2(item), item)
end
