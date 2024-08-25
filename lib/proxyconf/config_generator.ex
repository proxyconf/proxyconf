defmodule ProxyConf.ConfigGenerator do
  alias ProxyConf.ConfigGenerator.Cluster
  alias ProxyConf.ConfigGenerator.FilterChain
  alias ProxyConf.ConfigGenerator.Listener
  alias ProxyConf.ConfigGenerator.Route
  alias ProxyConf.ConfigGenerator.RouteConfiguration
  alias ProxyConf.ConfigGenerator.VHost
  alias ProxyConf.ConfigGenerator.DownstreamAuth
  alias ProxyConf.ConfigGenerator.DownstreamTls
  alias ProxyConf.Spec
  alias ProxyConf.ConfigCache
  require Logger

  defstruct(
    skip_errors: true,
    listeners: [],
    filter_chains: [],
    clusters: [],
    vhosts: [],
    routes: [],
    route_configurations: [],
    source_ip_ranges: [],
    downstream_tls: [],
    downstream_auth: [],
    errors: []
  )

  defp add_unifier(tmpl, unifier), do: {unifier, tmpl}

  def from_oas3_specs(cluster_id, _changes) do
    ConfigCache.iterate_specs(cluster_id, %__MODULE__{}, fn %Spec{} = spec, config ->
      try do
        listener_name = Listener.name(spec)
        listener_tmpl = Listener.from_spec_gen(spec) |> add_unifier(listener_name)

        vhost_unifier = %{listener: listener_name, host: spec.api_url.host}
        filter_chain_tmpl = FilterChain.from_spec_gen(spec) |> add_unifier(vhost_unifier)
        downstream_tls_tmpl = DownstreamTls.from_spec_gen(spec) |> add_unifier(vhost_unifier)
        downstream_auth_tmpl = DownstreamAuth.from_spec_gen(spec) |> add_unifier(vhost_unifier)
        vhost_tmpl = VHost.from_spec_gen(spec) |> add_unifier(vhost_unifier)
        source_ip_ranges = spec.allowed_source_ips |> add_unifier(vhost_unifier)
        route_tmpl = Route.from_spec_gen(spec) |> add_unifier(vhost_unifier)

        route_configuration_tmpl =
          RouteConfiguration.from_spec_gen(spec) |> add_unifier(vhost_unifier)

        cluster_tmpl = Cluster.from_spec_gen(spec) |> add_unifier(vhost_unifier)

        %__MODULE__{
          config
          | listeners: [listener_tmpl | config.listeners],
            filter_chains: [filter_chain_tmpl | config.filter_chains],
            source_ip_ranges: [source_ip_ranges | config.source_ip_ranges],
            vhosts: [vhost_tmpl | config.vhosts],
            routes: [route_tmpl | config.routes],
            route_configurations: [route_configuration_tmpl | config.route_configurations],
            clusters: [cluster_tmpl | config.clusters],
            downstream_tls: [downstream_tls_tmpl | config.downstream_tls],
            downstream_auth: [downstream_auth_tmpl | config.downstream_auth]
        }
      rescue
        e ->
          Logger.warning(
            cluster: cluster_id,
            api_id: spec.api_id,
            filename: spec.filename,
            message: "Skipping OpenAPI spec due to: #{Exception.message(e)}"
          )

          %__MODULE__{config | errors: [spec.filename | config.errors]}
      end
    end)
    |> generate()
  end

  defp generate(%__MODULE__{skip_errors: false, errors: [_ | _] = errors}), do: {:error, errors}

  defp generate(%__MODULE__{
         listeners: listeners,
         filter_chains: filter_chains,
         source_ip_ranges: source_ip_ranges,
         clusters: clusters,
         vhosts: vhosts,
         routes: routes,
         route_configurations: route_configurations,
         downstream_tls: downstream_tls,
         downstream_auth: downstream_auth
       }) do
    {all_clusters, routes} =
      Enum.group_by(routes, fn {unifier, _} -> unifier end, fn {_unifier, route_tmpl_fn} ->
        route_tmpl_fn.()
      end)
      |> Enum.reduce({%{}, %{}}, fn {unifier, routes_and_clusters}, {clusters_acc, routes_acc} ->
        {routes, clusters} = List.flatten(routes_and_clusters) |> Enum.unzip()

        {Map.put(clusters_acc, unifier, List.flatten(clusters) |> Enum.uniq()),
         Map.put(routes_acc, unifier, List.flatten(routes) |> Enum.uniq())}
      end)

    downstream_tls_by_vhost =
      Enum.group_by(
        downstream_tls,
        fn {unifier, _} -> unifier end,
        fn {_, downstream_tls_config_fn} ->
          downstream_tls_config_fn.()
        end
      )
      |> Enum.reduce(%{}, fn {unifier, downstream_tls}, acc ->
        Map.put(
          acc,
          unifier,
          List.flatten(downstream_tls) |> Enum.uniq_by(fn %{"name" => name} -> name end)
        )
      end)

    downstream_auth =
      Enum.group_by(
        downstream_auth,
        fn {unifier, _} -> unifier end,
        fn {_, downstream_auth_config_fn} ->
          downstream_auth_config_fn.()
        end
      )

    vhosts =
      Map.new(vhosts, fn {unifier, vhost_tmpl_fn} ->
        {unifier, vhost_tmpl_fn.(Map.fetch!(routes, unifier))}
      end)

    vhosts_for_listeners =
      Enum.group_by(vhosts, fn {unifier, _} -> unifier.listener end, fn {_, vhost} -> vhost end)
      |> Enum.reduce(%{}, fn {listener_unifier, vhosts}, acc ->
        Map.put(acc, listener_unifier, List.flatten(vhosts) |> Enum.uniq())
      end)

    route_configurations =
      Enum.group_by(route_configurations, fn {unifier, _} -> unifier.listener end, fn
        {unifier, route_configuration_tmpl_fn} ->
          route_configuration_tmpl_fn.(
            unifier.host,
            unifier.listener,
            Map.fetch!(vhosts, unifier)
          )
      end)
      |> Enum.flat_map(fn {_, route_configurations} ->
        route_configurations
      end)
      |> Enum.uniq()

    source_ip_ranges =
      Enum.group_by(source_ip_ranges, fn {unifier, _} -> unifier end, fn {_, source_ip_ranges} ->
        source_ip_ranges
      end)
      |> Map.new(fn {unifier, source_ip_ranges} ->
        {unifier, List.flatten(source_ip_ranges) |> Enum.uniq()}
      end)

    {filter_chains_by_listener, downstream_auth_clusters} =
      Enum.group_by(
        filter_chains,
        fn {unifier, _} -> unifier end,
        fn {unifier, filter_chain_tmpl_fn} ->
          Map.fetch!(vhosts_for_listeners, unifier.listener)
          |> Enum.map(fn vhost ->
            filter_chain_tmpl_fn.(
              vhost,
              Map.fetch!(source_ip_ranges, unifier),
              Map.fetch!(downstream_auth, unifier),
              Map.fetch!(downstream_tls_by_vhost, unifier)
            )
          end)
        end
      )
      |> Enum.reduce({%{}, []}, fn {unifier, filter_chains},
                                   {acc_filter_chains, acc_downstream_auth_clusters} ->
        {filter_chains, downstream_auth_clusters} =
          List.flatten(filter_chains) |> Enum.uniq() |> Enum.unzip()

        {Map.update(acc_filter_chains, unifier.listener, filter_chains, fn v ->
           [v | filter_chains]
         end), [downstream_auth_clusters | acc_downstream_auth_clusters]}
      end)

    listeners =
      Enum.group_by(
        listeners,
        fn {unifier, _} -> unifier end,
        fn {unifier, listener_tmpl_fn} ->
          listener_tmpl_fn.(
            Map.fetch!(filter_chains_by_listener, unifier)
            |> List.flatten()
            |> Enum.uniq_by(fn %{"filter_chain_match" => m} -> m end)
          )
        end
      )
      |> Enum.flat_map(fn {_, listeners} ->
        List.flatten(listeners)
      end)
      |> Enum.uniq()

    downstream_auth_clusters = List.flatten(downstream_auth_clusters) |> Enum.uniq()

    clusters =
      Enum.group_by(clusters, fn {unifier, _} -> unifier end, fn {unifier, cluster_tmpl_fn} ->
        cluster_tmpl_fn.(Map.fetch!(all_clusters, unifier))
      end)
      |> Enum.flat_map(fn {_, clusters} -> List.flatten(clusters) end)
      |> Enum.uniq()

    {:ok,
     %{
       clusters: clusters ++ downstream_auth_clusters,
       listeners: listeners,
       route_configurations: route_configurations,
       downstream_tls: Map.values(downstream_tls_by_vhost) |> List.flatten() |> Enum.uniq()
     }}
  end
end
