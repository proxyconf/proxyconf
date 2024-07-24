defmodule ApiFence.ConfigGenerator do
  alias ApiFence.Types.Cluster
  alias ApiFence.Types.ClusterLbEndpoint
  alias ApiFence.Types.Listener
  alias ApiFence.Types.Route
  alias ApiFence.Types.Upstream
  alias ApiFence.Types.VHost
  alias ApiFence.ConfigCache
  require Logger
  defstruct([:version, listeners: [], clusters: [], vhosts: [], routes: []])

  def from_oas3_specs(version) do
    %__MODULE__{listeners: listeners, clusters: clusters, vhosts: vhosts, routes: routes} =
      ConfigCache.iterate_specs(%__MODULE__{version: version}, fn filename,
                                                                  api_id,
                                                                  spec,
                                                                  config ->
        try do
          {listener_unifier, _} = listener_tmpl = listener_template_fn(spec, config)
          {vhost_unifier, _} = vhost_tmpl = vhost_template_fn(listener_unifier, spec, config)
          route_tmpl = route_template_fn(api_id, vhost_unifier, spec, config)
          cluster_tmpl = cluster_template_fn(api_id, vhost_unifier, config)

          %__MODULE__{
            config
            | listeners: [listener_tmpl | config.listeners],
              vhosts: [vhost_tmpl | config.vhosts],
              routes: [route_tmpl | config.routes],
              clusters: [cluster_tmpl | config.clusters]
          }
        rescue
          e ->
            Logger.error(
              "Skipping OpenAPI spec #{filename} with API ID #{api_id} due to: #{Exception.message(e)}"
            )

            Logger.debug(Exception.format_stacktrace(__STACKTRACE__))

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
        fn {unifier, listener_tmpl_fn} -> listener_tmpl_fn.(Map.fetch!(vhosts, unifier)) end
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

  @listener_extension_key "x-api-fence-listeners"
  @default_listener %{"address" => "127.0.0.1", "port" => 8080}
  defp listener_template_fn(spec, _config) do
    %{"address" => address, "port" => port} =
      Map.merge(@default_listener, Map.get(spec, @listener_extension_key, %{}))

    listener_name = "#{address}:#{port}"

    {%{listener_name: listener_name},
     fn vhosts ->
       %{
         listener_name: listener_name,
         address: address,
         port: port,
         virtual_hosts: vhosts,
         auth_filters: []
       }
       |> Listener.eval()
     end}
  end

  @default_api_url "http://localhost:8080/api"
  @api_url_extension_key "x-api-fence-api-url"
  defp vhost_template_fn(listener_unifier, spec, _config) do
    %URI{host: host} = Map.get(spec, @api_url_extension_key, @default_api_url) |> URI.parse()

    {%{listener: listener_unifier, host: host},
     fn routes ->
       %{name: host, domains: [host], routes: routes} |> VHost.eval()
     end}
  end

  defp route_template_fn(api_id, vhost_unifier, spec, config) do
    %URI{path: path} = Map.get(spec, @api_url_extension_key, @default_api_url) |> URI.parse()

    path_prefix = path || "/"
    # TODO: currently no template type for route available
    {vhost_unifier,
     fn ->
       Route.from_oas3_spec(api_id, config.version, path_prefix, spec)
     end}
  end

  @schema_cache_cluster "schema_cache_cluster"
  defp cluster_template_fn(api_id, vhost_unifier, _config) do
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
