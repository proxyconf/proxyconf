defmodule ProxyConf.ConfigGenerator do
  alias ProxyConf.ConfigGenerator.Cluster
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
    clusters: [],
    vhosts: [],
    routes: [],
    route_configurations: [],
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
        downstream_tls_tmpl = DownstreamTls.from_spec_gen(spec) |> add_unifier(listener_name)
        downstream_auth_tmpl = DownstreamAuth.from_spec_gen(spec) |> add_unifier(listener_name)

        vhost_unifier = %{listener: listener_name, host: spec.api_url.host}
        vhost_tmpl = VHost.from_spec_gen(spec) |> add_unifier(vhost_unifier)

        route_tmpl = Route.from_spec_gen(spec) |> add_unifier(vhost_unifier)

        route_configuration_tmpl =
          RouteConfiguration.from_spec_gen(spec) |> add_unifier(vhost_unifier)

        cluster_tmpl = Cluster.from_spec_gen(spec) |> add_unifier(vhost_unifier)

        %__MODULE__{
          config
          | listeners: [listener_tmpl | config.listeners],
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

    downstream_tls_by_listener =
      Enum.group_by(downstream_tls, fn {unifier, _} -> unifier end, fn {_,
                                                                        downstream_tls_config_fn} ->
        downstream_tls_config_fn.()
      end)
      |> Enum.reduce(%{}, fn {unifier, downstream_tls}, acc ->
        Map.put(
          acc,
          unifier,
          List.flatten(downstream_tls) |> Enum.uniq_by(fn %{"name" => name} -> name end)
        )
      end)

    downstream_tls =
      Enum.reduce(downstream_tls_by_listener, %{}, fn {_, tls_certs}, acc ->
        Enum.reduce(tls_certs, acc, fn %{"name" => name} = tls_cert, acc ->
          Map.put(acc, name, tls_cert)
        end)
      end)
      |> Map.values()

    downstream_auth =
      Enum.group_by(downstream_auth, fn {unifier, _} -> unifier end, fn {_,
                                                                         downstream_auth_config_fn} ->
        downstream_auth_config_fn.()
      end)

    vhosts =
      Enum.group_by(vhosts, fn {unifier, _} -> unifier.listener end, fn {unifier, vhost_tmpl_fn} ->
        vhost_tmpl_fn.(Map.fetch!(routes, unifier))
      end)
      |> Enum.reduce(%{}, fn {unifier, vhosts}, acc ->
        Map.put(acc, unifier, List.flatten(vhosts) |> Enum.uniq())
      end)

    route_configurations =
      Enum.group_by(route_configurations, fn {unifier, _} -> unifier.listener end, fn
        {unifier, route_configuration_tmpl_fn} ->
          route_configuration_tmpl_fn.(Map.fetch!(vhosts, unifier.listener))
      end)
      |> Enum.flat_map(fn {_, route_configurations} ->
        List.flatten(route_configurations)
      end)
      |> Enum.uniq()

    {listeners, downstream_auth_clusters} =
      Enum.group_by(
        listeners,
        fn {unifier, _} -> unifier end,
        fn {unifier, listener_tmpl_fn} ->
          listener_tmpl_fn.(
            Map.fetch!(vhosts, unifier),
            Map.fetch!(downstream_auth, unifier),
            Map.fetch!(downstream_tls_by_listener, unifier)
          )
        end
      )
      |> Enum.flat_map(fn {_, listeners} -> listeners end)
      |> Enum.uniq()
      |> Enum.unzip()

    downstream_auth_clusters = List.flatten(downstream_auth_clusters)

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
       downstream_tls: downstream_tls
     }}
  end
end
