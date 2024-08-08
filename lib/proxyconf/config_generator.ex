defmodule ProxyConf.ConfigGenerator do
  alias ProxyConf.Types.Cluster
  alias ProxyConf.Types.ClusterLbEndpoint
  alias ProxyConf.Types.Listener
  alias ProxyConf.Types.Route
  alias ProxyConf.Types.VHost
  alias ProxyConf.Types.Spec
  alias ProxyConf.ConfigCache
  require Logger
  defstruct(listeners: [], clusters: [], vhosts: [], routes: [], downstream_auth: [])

  def from_oas3_specs(cluster_id, _changes) do
    %__MODULE__{
      listeners: listeners,
      clusters: clusters,
      vhosts: vhosts,
      routes: routes,
      downstream_auth: downstream_auth
    } =
      ConfigCache.iterate_specs(cluster_id, %__MODULE__{}, fn %Spec{} = spec, config ->
        try do
          {listener_unifier, _} = listener_tmpl = listener_template_fn(spec, config)

          downstream_auth_tmpl = downstream_auth_template_fn(listener_unifier, spec, config)

          {vhost_unifier, _} = vhost_tmpl = vhost_template_fn(listener_unifier, spec, config)
          route_tmpl = route_template_fn(vhost_unifier, spec, config)
          cluster_tmpl = cluster_template_fn(vhost_unifier, spec, config)

          %__MODULE__{
            config
            | listeners: [listener_tmpl | config.listeners],
              vhosts: [vhost_tmpl | config.vhosts],
              routes: [route_tmpl | config.routes],
              clusters: [cluster_tmpl | config.clusters],
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

            config
        end
      end)

    {all_clusters, routes} =
      Enum.group_by(routes, fn {unifier, _} -> unifier end, fn {_unifier, route_tmpl_fn} ->
        route_tmpl_fn.()
      end)
      |> Enum.reduce({%{}, %{}}, fn {unifier, routes_and_clusters}, {clusters_acc, routes_acc} ->
        {routes, clusters} = List.flatten(routes_and_clusters) |> Enum.unzip()

        {Map.put(clusters_acc, unifier, List.flatten(clusters) |> Enum.uniq()),
         Map.put(routes_acc, unifier, List.flatten(routes) |> Enum.uniq())}
      end)

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

    listeners =
      Enum.group_by(
        listeners,
        fn {unifier, _} -> unifier end,
        fn {unifier, listener_tmpl_fn} ->
          listener_tmpl_fn.(Map.fetch!(vhosts, unifier), Map.fetch!(downstream_auth, unifier))
        end
      )
      |> Enum.flat_map(fn {_, listeners} -> listeners end)
      |> Enum.uniq()

    clusters =
      Enum.group_by(clusters, fn {unifier, _} -> unifier end, fn {unifier, cluster_tmpl_fn} ->
        cluster_tmpl_fn.(Map.fetch!(all_clusters, unifier))
      end)
      |> Enum.flat_map(fn {_, clusters} -> List.flatten(clusters) |> Enum.uniq() end)

    %{clusters: clusters, listeners: listeners}
  end

  defp listener_template_fn(%Spec{} = spec, _config) do
    listener_name = "#{spec.listener_address}:#{spec.listener_port}"

    {%{listener_name: listener_name},
     fn vhosts, downstream_auth ->
       %{
         listener_name: listener_name,
         address: spec.listener_address,
         port: spec.listener_port,
         virtual_hosts: vhosts,
         downstream_auth:
           ProxyConf.DownstreamAuth.to_envoy_http_filter(downstream_auth)
           |> IO.inspect(label: "downstream auth")
       }
       |> Listener.eval()
     end}
  end

  defp vhost_template_fn(listener_unifier, %Spec{} = spec, _config) do
    host = spec.api_url.host

    {%{listener: listener_unifier, host: host},
     fn routes ->
       %{
         name: host,
         domains: [host],
         routes: routes
       }
       |> VHost.eval()
     end}
  end

  defp downstream_auth_template_fn(listener_unifier, %Spec{} = spec, _config) do
    downstream_auth_config = ProxyConf.DownstreamAuth.to_config(spec)

    {listener_unifier,
     fn ->
       downstream_auth_config
     end}
  end

  defp route_template_fn(vhost_unifier, %Spec{} = spec, _config) do
    path_prefix = spec.api_url.path || "/"
    # TODO: currently no template type for route available
    {vhost_unifier,
     fn ->
       Route.from_oas3_spec(path_prefix, spec)
     end}
  end

  defp cluster_template_fn(vhost_unifier, %Spec{} = _spec, _config) do
    {vhost_unifier,
     fn clusters ->
       Enum.uniq(clusters)
       |> Enum.map(fn {cluster_name, cluster_uri} ->
         Cluster.eval(%{
           name: cluster_name,
           endpoints: [ClusterLbEndpoint.eval(%{host: cluster_uri.host, port: cluster_uri.port})]
         })
       end)
     end}
  end
end
