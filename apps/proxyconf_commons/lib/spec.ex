defmodule ProxyConf.Commons.Spec do
  @moduledoc """
    This module models the internal representation of the OpenAPI Spec
    containing the ProxyConf specific extensions.
  """
  require Logger
  alias ProxyConf.Commons.OaiOverlay
  alias ProxyConf.Commons.Gen.Cors
  alias ProxyConf.Commons.Gen.DownstreamAuth
  alias ProxyConf.Commons.Gen.HttpConnectionManager
  alias ProxyConf.Commons.Gen.UpstreamAuth

  @external_resource "priv/schemas/proxyconf.json"
  @ext_schema File.read!("priv/schemas/proxyconf.json") |> JSON.decode!()

  @merge_resolver fn
    _, l, r when is_list(l) and is_list(r) ->
      Enum.uniq(l ++ r)

    _, _, _ ->
      DeepMerge.continue_deep_merge()
  end

  @external_resource "priv/schemas/oas3_0.json"
  @oas3_0_schema File.read!("priv/schemas/oas3_0.json")
                 |> JSON.decode!()
                 |> DeepMerge.deep_merge(@ext_schema, @merge_resolver)
                 |> JsonXema.new()

  defstruct([
    :hash,
    :cluster_id,
    :api_url,
    :api_id,
    :listener_address,
    :listener_port,
    :allowed_source_ips,
    :downstream_auth,
    :upstream_auth,
    :routing,
    :cors,
    :oauth,
    :http_connection_manager,
    :spec,
    type: :oas3
  ])

  @typedoc """
    title: API Identifier
    description: A unique identifier for the API, used for API-specific logging, monitoring, and identification in ProxyConf and Envoy. This ID is essential for tracking and debugging API traffic across the system.
  """
  @type api_id :: GenJsonSchema.Type.string(minLength: 1)

  @typedoc """
    title: Cluster Identifier
    description: The cluster identifier groups APIs for Envoy. This cluster name should also be reflected in the static `bootstrap` configuration of Envoy, ensuring that APIs are properly associated with the correct Envoy instances.
  """
  @type cluster :: GenJsonSchema.Type.string(minLength: 1)

  @typedoc """
    title: API URL
    description: |
      The API URL serves multiple functions:

      - **Scheme**: Determines if TLS or non-TLS listeners are used (e.g., `http` or `https`).
      - **Domain**: Used for virtual host matching in Envoy.
      - **Path**: Configures prefix matching in Envoy's filter chain.
      - **Port**: If specified, this overrides the default listener port. Ensure you explicitly configure HTTP ports `80` and `443`.
  """
  @type url :: GenJsonSchema.Type.string(format: :uri)

  @typedoc """
    title: Fail Fast on Missing Header Parameter
    description: Reject requests that are missing required headers as defined in the OpenAPI spec. You can override this setting at the path level using the `x-proxyconf-fail-fast-on-missing-header-parameter` field in the OpenAPI path definition.
    default: true
  """
  @type fail_fast_on_missing_header_parameter :: boolean()

  @typedoc """
    title: Fail Fast on Missing Query Parameter
    description: Reject requests that are missing required query parameters. Similar to headers, this setting can be overridden at the path level with the `x-proxyconf-fail-fast-on-missing-query-parameter` field.
    default: true
  """
  @type fail_fast_on_missing_query_parameter :: boolean()

  @typedoc """
    title: Fail Fast on Wrong Media Type
    description: Reject requests where the `content-type` header doesn't match the media types specified in the OpenAPI request body spec. You can override this behavior at the path level using the `x-proxyconf-fail-fast-on-wrong-media-type` field.
    default: true
  """
  @type fail_fast_on_wrong_media_type :: boolean()
  @type routing :: %{
          fail_fast_on_missing_header_parameter: fail_fast_on_missing_header_parameter(),
          fail_fast_on_missing_query_parameter: fail_fast_on_missing_query_parameter(),
          fail_fast_on_wrong_media_type: fail_fast_on_wrong_media_type()
        }

  @typedoc """
    title: Downstream Authentication
    description: Configuration for downstream client authentication. This typically involves specifying authentication types (e.g., API keys) and client credentials.
  """
  @type downstream_auth :: ProxyConf.Commons.Gen.DownstreamAuth.t()

  @typedoc """
    title: Upstream Authentication
    description: Configuration for upstream authentication.
  """
  @type upstream_auth :: ProxyConf.Commons.Gen.UpstreamAuth.t()

  @typedoc """
    title: Authentication
    description: The auth object handles authentication for both downstream and upstream requests. This allows you to specify client authentication requirements for incoming requests and credential injection for outgoing requests to upstream services.
    required:
      - downstream
  """
  @type authentication :: %{
          downstream: downstream_auth(),
          upstream: upstream_auth()
        }

  @typedoc """
    title: IP Address Range
    description: The IP address range in CIDR notation.
    format: cidr
  """
  @type cidr :: String.t()

  @typedoc """
    title: Allowed Source IP Ranges
    description: An array of allowed source IP ranges (in CIDR notation) that are permitted to access the API. This helps secure the API by ensuring only trusted IPs can communicate with it. For more details on CIDR notation, visit the [CIDR Documentation](https://en.wikipedia.org/wiki/Classless_Inter-Domain_Routing).
  """
  @type allowed_source_ips :: [cidr()]

  @typedoc """
    title: Security Configuration
    description: The `security` object configures API-specific security features, such as IP filtering and authentication mechanisms. It supports both source IP filtering (allowing only specific IP ranges) and client authentication for downstream requests, as well as credential injection for upstream requests.
    required:
      - auth
  """
  @type security :: %{
          auth: authentication(),
          allowed_source_ips: allowed_source_ips()
        }

  @typedoc """
    title: ProxyConf API Config
    description: The `x-proxyconf` property extends the OpenAPI specification with ProxyConf-specific configurations, enabling ProxyConf to generate the necessary resources to integrate with [Envoy Proxy](https://www.envoyproxy.io/).
    required:
      - security
  """
  @type proxyconf :: %{
          api_id: api_id(),
          cluster: cluster(),
          listener: ProxyConf.Commons.Gen.Listener.t(),
          url: url(),
          routing: routing(),
          security: security(),
          cors: ProxyConf.Commons.Gen.Cors.t(),
          oauth: ProxyConf.Commons.Gen.OAuth.t(),
          http_connection_manager: ProxyConf.Commons.Gen.HttpConnectionManager.t()
        }

  @typedoc """
    title: OpenAPI Extension for ProxyConf
    examples:
      - x-proxyconf:
          api-id: my-api
          url: https://api.example.com:8080/my-api
          cluster: proxyconf-envoy-cluster
          listener:
            address: 127.0.0.1
            port: 8080
          security:
            allowed-source-ips:
              - 192.168.0.0/16
            auth:
              downstream:
                type: header
                name: x-api-key
                clients:
                  testUser:
                    - 9a618248b64db62d15b300a07b00580b
  """
  @type root :: %{
          x_proxyconf: nil | proxyconf()
        }

  @spec from_oas3(String.t(), map(), binary()) :: {:ok, map()} | {:error, String.t()}
  def from_oas3(api_id, spec, data) do
    case JsonXema.validate(@oas3_0_schema, spec) do
      :ok ->
        proxyconf = Map.get(spec, "x-proxyconf", %{})

        config_from_spec =
          defaults(api_id, proxyconf["url"])
          |> DeepMerge.deep_merge(proxyconf)
          |> update_in(["security", "allowed-source-ips"], &to_cidrs/1)
          |> update_in(["url"], &URI.parse/1)

        %{
          "cluster" => cluster_id,
          "url" => api_url,
          "api-id" => api_id,
          "listener" => %{"address" => address, "port" => port},
          "security" => %{
            "allowed-source-ips" => allowed_source_ips,
            "auth" => %{"downstream" => downstream_auth, "upstream" => upstream_auth}
          },
          "routing" => %{
            "fail-fast-on-missing-query-parameter" => fail_fast_on_missing_query_parameter,
            "fail-fast-on-missing-header-parameter" => fail_fast_on_missing_header_parameter,
            "fail-fast-on-wrong-request-media_type" => fail_fast_on_wrong_request_media_type
          },
          "cors" => cors,
          "oauth" => _oauth,
          "http-connection-manager" => http_connection_manager
        } = config_from_spec

        {:ok,
         %ProxyConf.Commons.Spec{
           hash: gen_hash(data),
           cluster_id: cluster_id,
           api_url: api_url,
           api_id: api_id,
           listener_address: address,
           listener_port: port,
           allowed_source_ips: allowed_source_ips,
           downstream_auth: DownstreamAuth.config_from_json(downstream_auth),
           upstream_auth: UpstreamAuth.config_from_json(upstream_auth),
           routing: %{
             fail_fast_on_missing_query_parameter: fail_fast_on_missing_query_parameter,
             fail_fast_on_missing_header_parameter: fail_fast_on_missing_header_parameter,
             fail_fast_on_wrong_request_media_type: fail_fast_on_wrong_request_media_type
           },
           cors: Cors.config_from_json(cors),
           oauth: nil,
           http_connection_manager:
             HttpConnectionManager.config_from_json(http_connection_manager),
           spec: spec
         }}

      {:error, %JsonXema.ValidationError{} = error} ->
        {:error, JsonXema.ValidationError.message(error)}
    end
  end

  def gen_hash(data) when is_binary(data) do
    :crypto.hash(:sha256, data) |> Base.encode64()
  end

  @doc """
    generate a single %Spec{} struct
  """
  def to_spec(api_id, data, content_type, template_vars) do
    with {:ok, data} <- render_mustache(data, template_vars),
         {:ok, spec} <- decode(content_type, data) do
      from_oas3(api_id, spec, data)
    else
      e -> e
    end
  end

  @doc """
    generate %Spec{} structs from a generic spec data provider
  """
  def to_specs(spec_provider, cluster_id, template_vars) do
    result =
      spec_provider.(
        fn filename, filedata_fn, {spec_acc, overlay_acc, error_acc} ->
          ext = Path.extname(filename)

          with true <- ext in [".json", ".yaml"],
               data_raw <- filedata_fn.(),
               {:ok, data_raw} <- render_mustache(data_raw, template_vars),
               {:ok, data} <- decode(ext, data_raw) do
            cond do
              Map.has_key?(data, "openapi") ->
                {[{"#{filename}", data} | spec_acc], overlay_acc, error_acc}

              Map.has_key?(data, "overlay") ->
                {spec_acc, [{"#{filename}", data} | overlay_acc], error_acc}

              true ->
                # not openapi or overlay, ignore
                {spec_acc, overlay_acc, error_acc}
            end
          else
            false ->
              # not json or yaml file, OR doesn't contain openapi property silently ignore
              {spec_acc, overlay_acc, error_acc}

            {:error, reason} ->
              # decode error
              {spec_acc, overlay_acc, [{filename, reason} | error_acc]}
          end
        end,
        {[], [], []}
      )

    with {spec_data, overlay_data, []} <- result,
         {overlays, []} <- OaiOverlay.prepare_overlays(overlay_data),
         overlayed_spec_data <- OaiOverlay.overlay(spec_data, overlays) do
      Enum.flat_map_reduce(overlayed_spec_data, [], fn {filename, data}, errors ->
        spec_name = Path.basename(filename) |> Path.rootname()

        case from_oas3(spec_name, data, JSON.encode!(data)) do
          {:ok, %__MODULE__{cluster_id: ^cluster_id} = spec} ->
            {[spec], errors}

          {:ok, %__MODULE__{cluster_id: _invalid_cluster_id}} ->
            {[], [{filename, "Spec is not part of cluster"} | errors]}

          {:error, reason} ->
            {[], [{filename, reason} | errors]}
        end
      end)
    else
      {_, _, errors} -> {[], errors}
      {_, errors} -> {[], errors}
    end
  end

  defp decode(content_type, data) do
    cond do
      String.ends_with?(content_type, "json") ->
        JSON.decode(data)

      String.ends_with?(content_type, "yaml") ->
        YamlElixir.read_from_string(data)

      true ->
        {:error, "invalid content type"}
    end
  end

  defp render_mustache(data, context) do
    {:ok, :bbmustache.render(data, context, raise_on_context_miss: true)}
  rescue
    e in ErlangError ->
      case e do
        %ErlangError{original: {:context_missing, {:key, key}}} ->
          {:error, "missing template variable {{#{key}}}"}

        %ErlangError{original: o} ->
          {:error, "Mustache templating error #{inspect(o)}"}
      end
  end

  defp defaults(api_id, api_url) do
    api_url =
      (api_url ||
         default(
           :default_api_host,
           "https://localhost:#{Application.get_env(:proxyconf, :default_api_port, 8443)}/#{api_id}"
         ))
      |> URI.parse()

    %{
      "api-id" => api_id,
      "url" => "#{api_url.scheme}://#{api_url.host}:#{api_url.port}/#{api_id}",
      "cluster" => default(:default_cluster_id, "demo"),
      "listener" => %{
        "address" => "127.0.0.1",
        "port" => api_url.port
      },
      "security" => %{
        "allowed-source-ips" => ["127.0.0.1/8"],
        "auth" => %{
          "upstream" => nil,
          "downstream" => %{
            "type" => "jwt",
            "provider-config" => %{
              "issuer" => "proxyconf",
              "audiences" => ["demo"],
              "forward" => false,
              "remote_jwks" => %{
                "http_uri" => %{
                  "uri" =>
                    "https://127.0.0.1:#{Application.fetch_env!(:proxyconf, :mgmt_api_port)}/api/jwks.json",
                  "timeout" => "1s"
                },
                "cache_duration" => %{
                  "seconds" => 300
                }
              }
            }
          }
        }
      },
      "routing" => %{
        "fail-fast-on-missing-query-parameter" => true,
        "fail-fast-on-missing-header-parameter" => true,
        "fail-fast-on-wrong-request-media_type" => true
      },
      "cors" => nil,
      "oauth" => nil,
      "http-connection-manager" => nil
    }
  end

  defp default(env_var, default) do
    Application.get_env(
      :proxyconf,
      env_var,
      default
    )
  end

  defp to_cidrs(subnets) when is_list(subnets) do
    Enum.flat_map(subnets, fn subnet ->
      with [address_prefix, prefix_length] <- String.split(subnet, "/"),
           {prefix_length, ""} <- Integer.parse(prefix_length) do
        [%{"address_prefix" => address_prefix, "prefix_len" => prefix_length}]
      else
        _ ->
          Logger.warning(
            "Ignored invalid CIDR range in 'allowed_source_ips' configuration #{subnet}"
          )

          []
      end
    end)
  end
end
