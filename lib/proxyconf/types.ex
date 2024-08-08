defmodule ProxyConf.Types do
  defmodule Spec do
    defstruct([
      :filename,
      :hash,
      :cluster_id,
      :api_url,
      :api_id,
      :listener_address,
      :listener_port,
      :downstream_auth,
      :spec,
      type: :oas3
    ])

    def from_oas3(filename, spec, data) do
      with api_id <- Map.get(spec, "x-proxyconf-id", Path.rootname(filename) |> Path.basename()),
           {_, true} <- {:invalid_api_id, is_binary(api_id)},
           api_url <-
             Map.get(
               spec,
               "x-proxyconf-api-url",
               Application.get_env(
                 :proxyconf,
                 :default_api_host,
                 "http://localhost:#{Application.get_env(:proxyconf, :default_api_port, 8080)}/#{api_id}"
               )
             ),
           {_, true} <- {:invalid_api_url, is_binary(api_url)},
           api_url <- URI.parse(api_url),
           cluster_id <-
             Map.get(
               spec,
               "x-proxyconf-cluster-id",
               Application.get_env(:proxyconf, :default_cluster_id, "proxyconf-cluster")
             ),
           {_, true} <- {:invalid_cluster_id, is_binary(cluster_id)},
           api_id <- Map.get(spec, "x-proxyconf-id", Path.rootname(filename) |> Path.basename()),
           {_, true} <- {:invalid_api_id, is_binary(api_id)},
           listener <- Map.get(spec, "x-proxyconf-listener", %{}),
           {_, true} <- {:invalid_api_listener, is_map(listener)},
           address <- Map.get(listener, "address", "127.0.0.1"),
           {_, true} <- {:invalid_api_listener_address, is_binary(address)},
           port <-
             Map.get(listener, "port", Application.get_env(:proxyconf, :default_api_port, 8080)),
           {_, true} <- {:invalid_api_listener_port, is_integer(port)},
           # downstream auth is validated in it's own module
           downstream_auth <- Map.get(spec, "x-proxyconf-downstream-auth") do
        {:ok,
         %Spec{
           filename: filename,
           hash: gen_hash(data),
           cluster_id: cluster_id,
           api_url: api_url,
           api_id: api_id,
           listener_address: address,
           listener_port: port,
           downstream_auth: downstream_auth,
           spec: spec
         }}
      else
        {error, false} ->
          {:error, error}
      end
    end

    def gen_hash(data) when is_binary(data) do
      :crypto.hash(:sha256, data) |> Base.encode64()
    end
  end

  defmodule VHost do
    use ProxyConf.MapTemplate

    deftemplate(%{
      "name" => :name,
      "domains" => :domains,
      "routes" => :routes
    })
  end

  defmodule Route do
    @operations ~w/get put post delete options head patch trace/

    def from_oas3_spec(
          path_prefix,
          %Spec{
            type: :oas3,
            spec: %{"paths" => paths_object, "servers" => servers} = oas3_spec
          } = spec
        ) do
      Enum.flat_map_reduce(paths_object, [], fn
        {path, %{"$ref" => ref_to_path_item_object}}, clusters_acc ->
          path_item_object = resolve_ref(ref_to_path_item_object, oas3_spec)

          inherited_config =
            Map.merge(%{"servers" => servers}, path_item_object)
            |> Map.take(["parameters", "servers"])

          Enum.filter(path_item_object, fn {k, _} -> k in @operations end)
          |> Enum.map_reduce(clusters_acc, fn {operation, operation_object}, clusters_acc ->
            operation_to_route_match(
              path_prefix,
              path,
              operation,
              DeepMerge.deep_merge(inherited_config, operation_object),
              clusters_acc,
              spec
            )
          end)

        {path, path_item_object}, clusters_acc ->
          inherited_config =
            Map.merge(%{"servers" => servers}, path_item_object)
            |> Map.take(["parameters", "servers"])

          Enum.filter(path_item_object, fn {k, _} -> k in @operations end)
          |> Enum.map_reduce(clusters_acc, fn {operation, operation_object}, clusters_acc ->
            operation_to_route_match(
              path_prefix,
              path,
              operation,
              DeepMerge.deep_merge(inherited_config, operation_object),
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
           clusters,
           %Spec{} = spec
         ) do
      servers = Map.fetch!(path_item_object, "servers")
      fail_fast = Map.get(path_item_object, "x-proxyconf-fail-fast-on-wrong-request", true)

      missing_query_param_check =
        Map.get(path_item_object, "x-proxyconf-fail-fast-on-missing-query-parameter", fail_fast)

      missing_header_param_check =
        Map.get(
          path_item_object,
          "x-proxyconf-fail-fast-on-missing-header-parameter",
          fail_fast
        )

      wrong_request_media_type_check =
        Map.get(path_item_object, "x-proxyconf-fail-fast-on-wrong-media-type", fail_fast)

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
              cluster = ProxyConf.Types.Cluster.cluster_uri_from_oas3_server(spec.api_id, server)

            {%{"cluster" => cluster_name}, [cluster | clusters]}

          servers when length(servers) > 1 ->
            clusters_for_path =
              Enum.map(servers, fn server ->
                {ProxyConf.Types.Cluster.cluster_uri_from_oas3_server(spec.api_id, server),
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
               "envoy.filters.http.lua" => ProxyConf.DownstreamAuth.to_filter_metadata(spec)
             }
           },
           "route" =>
             %{
               "prefix_rewrite" => path
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
               "envoy.filters.http.lua" => ProxyConf.DownstreamAuth.to_filter_metadata(spec)
             }
           },
           "route" =>
             %{
               "path_rewrite_policy" => %{
                 "name" => "envoy.path.rewrite.uri_template.uri_template_rewriter",
                 "typed_config" => %{
                   "@type" =>
                     "type.googleapis.com/envoy.extensions.path.rewrite.uri_template.v3.UriTemplateRewriteConfig",
                   "path_template_rewrite" =>
                     Enum.reduce(path_templates, {0, path}, fn
                       [path_template, @path_wildcard], {i, path_acc} ->
                         {i, String.replace(path_acc, path_template, "{#{@path_wildcard}}")}

                       [path_template, _path_variable], {i, path_acc} ->
                         {i + 1, String.replace(path_acc, path_template, "{var#{i}}")}
                     end)
                     |> elem(1)
                 }
               }
             }
             |> Map.merge(cluster_route_config)
         }, clusters}
      end
    end

    defp resolve_ref(ref, oas3spec) do
      ["#" | ref_path] = Path.split(ref)

      case get_in(oas3spec, ref_path) do
        nil -> %{}
        value -> value
      end
    end
  end

  defmodule Listener do
    use ProxyConf.MapTemplate

    deftemplate(%{
      "name" => :listener_name,
      "address" => %{
        "socket_address" => %{
          "address" => :address,
          "port_value" => :port
        }
      },
      "filter_chains" => [
        %{
          "filters" => [
            %{
              "name" => "envoy.filters.network.http_connection_manager",
              "typed_config" => %{
                "@type" =>
                  "type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager",
                "stat_prefix" => "proxyconf",
                "codec_type" => "AUTO",
                "strip_matching_host_port" => true,
                "route_config" => %{
                  "name" => "local_route",
                  "virtual_hosts" => :virtual_hosts
                },
                "http_filters" =>
                  [
                    :downstream_auth,
                    %{
                      "name" => "envoy.filters.http.router",
                      "typed_config" => %{
                        "@type" =>
                          "type.googleapis.com/envoy.extensions.filters.http.router.v3.Router"
                      }
                    }
                  ]
                  |> List.flatten()
              }
            }
          ]
        }
      ]
    })
  end

  defmodule ClusterLbEndpoint do
    use ProxyConf.MapTemplate

    deftemplate(%{
      "endpoint" => %{
        "address" => %{
          "socket_address" => %{
            "address" => :host,
            "port_value" => :port
          }
        }
      }
    })
  end

  defmodule Cluster do
    use ProxyConf.MapTemplate

    deftemplate(%{
      "name" => :name,
      "connect_timeout" => "0.25s",
      "type" => "STRICT_DNS",
      "lb_policy" => "ROUND_ROBIN",
      "load_assignment" => %{
        "cluster_name" => :name,
        "endpoints" => [
          %{
            "lb_endpoints" => :endpoints
          }
        ]
      }
    })

    def cluster_uri_from_oas3_server(api_id, server) do
      url = Map.fetch!(server, "url")

      url =
        Map.get(server, "variables", %{})
        |> Enum.reduce(url, fn {var_name, %{"default" => default}}, acc_url ->
          String.replace(acc_url, "{#{var_name}}", default)
        end)

      # - url: "{protocol}://{hostname}"
      case URI.parse(url) do
        %URI{host: nil} ->
          raise("invalid upstream server hostname in server url '#{server}'")

        %URI{port: nil} ->
          raise("invalid upstream server port in server url '#{server}'")

        %URI{} = uri ->
          {"#{api_id}::#{uri.host}:#{uri.port}", uri}
      end
    end
  end
end
