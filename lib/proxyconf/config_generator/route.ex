defmodule ProxyConf.ConfigGenerator.Route do
  @moduledoc """
    This module implements the generator of the Route Configs used by Envoy XDS/RDS
  """
  alias ProxyConf.Spec
  alias ProxyConf.ConfigGenerator.Cluster
  alias ProxyConf.ConfigGenerator.Cors
  alias ProxyConf.ConfigGenerator.DownstreamAuth

  def from_spec_gen(spec) do
    path_prefix = spec.api_url.path || "/"
    route = from_oas3_spec(path_prefix, spec)

    fn ->
      route
    end
  end

  @operations ~w/get put post delete options head patch trace/

  def from_oas3_spec(
        path_prefix,
        %Spec{
          type: :oas3,
          cors: cors,
          spec: %{"paths" => paths_object, "servers" => servers}
        } = spec
      ) do
    Enum.flat_map_reduce(paths_object, [], fn
      {path, path_item_object}, clusters_acc ->
        path_level_cors_policy =
          Cors.config_from_json(Map.get(path_item_object, "x-proxyconf-cors"))

        cors =
          Cors.merge_policy(cors, path_level_cors_policy)

        inherited_config =
          Map.merge(%{"servers" => servers}, path_item_object)
          |> Map.take(["parameters", "servers"])

        # path cors local response
        path_item_object =
          if is_nil(cors) do
            path_item_object
          else
            Map.put_new(path_item_object, "options", %{})
          end

        Enum.filter(path_item_object, fn {k, _} -> k in @operations end)
        |> Enum.map_reduce(clusters_acc, fn {operation, operation_object}, clusters_acc ->
          operation_to_route_match(
            path_prefix,
            path,
            operation,
            DeepMerge.deep_merge(inherited_config, operation_object),
            cors,
            clusters_acc,
            spec
          )
        end)
    end)
  end

  def route_id(operation, path, %Spec{} = spec) do
    :crypto.hash(
      :sha256,
      :erlang.term_to_binary([spec.api_url, String.upcase(operation), path])
    )
    |> Base.encode32(padding: false)
  end

  def get_schema(%{"schema" => schema}), do: [{:schema, schema}]
  def get_schema(_), do: []

  @path_wildcard "requestPath"
  @path_template_regex ~r/\{(.*?)\}/
  defp operation_to_route_match(
         path_prefix,
         path,
         operation,
         path_item_object,
         cors,
         clusters,
         %Spec{} = spec
       ) do
    servers = Map.fetch!(path_item_object, "servers")

    missing_query_param_check =
      Map.get(
        path_item_object,
        "x-proxyconf-fail-fast-on-missing-query-parameter",
        spec.routing.fail_fast_on_missing_query_parameter
      )

    missing_header_param_check =
      Map.get(
        path_item_object,
        "x-proxyconf-fail-fast-on-missing-header-parameter",
        spec.routing.fail_fast_on_missing_header_parameter
      )

    wrong_request_media_type_check =
      Map.get(
        path_item_object,
        "x-proxyconf-fail-fast-on-wrong-request-media-type",
        spec.routing.fail_fast_on_wrong_request_media_type
      )

    parameters =
      Map.get(path_item_object, "parameters", [])
      |> Enum.group_by(fn
        %{"in" => loc} ->
          loc

        %{"$ref" => ref} ->
          ["#" | ref_path] = String.split(ref, "/")
          %{"in" => loc} = get_in(spec.spec, ref_path)
          loc
      end)

    required_header_matches =
      if missing_header_param_check do
        Map.get(parameters, "header", [])
        |> Enum.filter(fn p -> Map.get(p, "required", false) end)
        |> Enum.map(fn p -> %{"name" => Map.get(p, "name"), "present_match" => true} end)
      else
        []
      end

    request_body = Map.get(path_item_object, "requestBody", %{})
    content = Map.get(request_body, "content", %{})
    request_body_optional = not Map.get(request_body, "required", false)

    media_type_regex =
      Enum.join(Map.keys(content), "|")
      |> String.replace("/", "\\/")
      |> String.replace("/*", "/[a-zA-Z0-9_-]+")

    media_type_header_matches =
      if not wrong_request_media_type_check or media_type_regex == "" do
        []
      else
        [
          %{
            "name" => "content-type",
            "string_match" => %{
              "safe_regex" => %{
                "regex" =>
                  if request_body_optional do
                    "(^$|^(#{media_type_regex})(;.*)*$)"
                  else
                    "^#{media_type_regex}(;.*)*$"
                  end
              }
            },
            "treat_missing_header_as_empty" => request_body_optional
          }
        ]
      end

    required_query_matches =
      if missing_query_param_check do
        Map.get(parameters, "query", [])
        |> Enum.filter(fn p -> Map.get(p, "required", false) end)
        |> Enum.map(fn p -> %{"name" => Map.get(p, "name"), "present_match" => true} end)
      else
        []
      end

    path_templates = Regex.scan(@path_template_regex, path)

    {cluster_route_config, clusters} =
      case servers do
        [server] ->
          {cluster_name, _uri} =
            cluster = Cluster.cluster_uri_from_oas3_server(spec.api_id, server)

          {%{"cluster" => cluster_name}, [cluster | clusters]}

        servers when length(servers) > 1 ->
          clusters_for_path =
            Enum.map(servers, fn server ->
              {Cluster.cluster_uri_from_oas3_server(spec.api_id, server),
               Map.get(server, "x-proxyconf-server-weight")}
            end)

          {cluster_without_weights, cluster_with_weights} =
            Enum.map(clusters_for_path, fn {{cluster_name, _uri}, weight} ->
              {cluster_name, weight}
            end)
            |> Enum.sort_by(fn {_, weight} -> weight end, :desc)
            |> Enum.split_with(fn {_, weight} -> is_nil(weight) end)

          defined_weights = Enum.map(cluster_with_weights, fn {_, weight} -> weight end)

          min_weight =
            if length(defined_weights) > 0 do
              Enum.min(defined_weights)
            else
              0
            end

          cluster_configs =
            Enum.reduce(cluster_without_weights, cluster_with_weights, fn {cluster_name, _},
                                                                          acc ->
              [{cluster_name, max(0, min_weight - 1)} | acc]
            end)
            |> Enum.map(fn {cluster_name, weight} ->
              %{"name" => cluster_name, "weight" => weight}
            end)

          clusters_for_path_without_weights = Enum.unzip(clusters_for_path) |> elem(0)

          {%{
             "weighted_clusters" => %{
               "clusters" => cluster_configs
             }
           }, clusters ++ clusters_for_path_without_weights}
      end

    route_id = route_id(operation, path, spec)
    [%{"url" => server_url} | _] = servers
    server = URI.parse(server_url)
    server_path = server.path || "/"

    if path_templates == [] do
      # no path templating
      {%{
         "name" => route_id,
         "match" => %{
           "headers" => [
             %{
               "name" => ":method",
               "string_match" => %{
                 "exact" => String.upcase(operation)
               }
             }
             | required_header_matches ++ media_type_header_matches
           ],
           "query_parameters" => required_query_matches,
           "path" => Path.join(path_prefix, path)
         },
         "metadata" => %{
           "filter_metadata" => %{
             "envoy.filters.http.lua" => DownstreamAuth.to_filter_metadata(spec)
           }
         },
         "typed_per_filter_config" =>
           typed_per_filter_config(%{"envoy.filters.http.cors" => cors}),
         "route" =>
           %{
             "prefix_rewrite" => Path.join(server_path, path),
             "auto_host_rewrite" => true
           }
           |> Map.merge(cluster_route_config)
       }, clusters}
    else
      {%{
         "name" => route_id,
         "match" => %{
           "headers" => [
             %{
               "name" => ":method",
               "string_match" => %{
                 "exact" => String.upcase(operation)
               }
             }
             | required_header_matches ++ media_type_header_matches
           ],
           "query_parameters" => required_query_matches,
           "path_match_policy" => %{
             "name" => "envoy.path.match.uri_template.uri_template_matcher",
             "typed_config" => %{
               "@type" =>
                 "type.googleapis.com/envoy.extensions.path.match.uri_template.v3.UriTemplateMatchConfig",
               "path_template" =>
                 Enum.reduce(path_templates, {0, Path.join(path_prefix, path)}, fn
                   [path_template, @path_wildcard], {i, path_acc} ->
                     {i, String.replace(path_acc, path_template, "{#{@path_wildcard}=**}")}

                   [path_template, _path_variable], {i, path_acc} ->
                     {i + 1, String.replace(path_acc, path_template, "{var#{i}}")}
                 end)
                 |> elem(1)
             }
           }
         },
         "metadata" => %{
           "filter_metadata" => %{
             "envoy.filters.http.lua" => DownstreamAuth.to_filter_metadata(spec)
           }
         },
         "typed_per_filter_config" =>
           typed_per_filter_config(%{"envoy.filters.http.cors" => cors}),
         "route" =>
           %{
             "auto_host_rewrite" => true,
             "path_rewrite_policy" => %{
               "name" => "envoy.path.rewrite.uri_template.uri_template_rewriter",
               "typed_config" => %{
                 "@type" =>
                   "type.googleapis.com/envoy.extensions.path.rewrite.uri_template.v3.UriTemplateRewriteConfig",
                 "path_template_rewrite" =>
                   Path.join(
                     server_path,
                     Enum.reduce(path_templates, {0, path}, fn
                       [path_template, @path_wildcard], {i, path_acc} ->
                         {i, String.replace(path_acc, path_template, "{#{@path_wildcard}}")}

                       [path_template, _path_variable], {i, path_acc} ->
                         {i + 1, String.replace(path_acc, path_template, "{var#{i}}")}
                     end)
                     |> elem(1)
                   )
               }
             }
           }
           |> Map.merge(cluster_route_config)
       }, clusters}
    end
  end

  defp typed_per_filter_config(configs) do
    Enum.reduce(configs, %{}, fn {config_key, config}, acc ->
      if config do
        Map.put(acc, config_key, config)
      else
        acc
      end
    end)
  end
end
