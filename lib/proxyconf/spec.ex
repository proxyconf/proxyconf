defmodule ProxyConf.Spec do
  @moduledoc """
    This module models the internal representation of the OpenAPI Spec
    containing the ProxyConf specific extensions.
  """
  require Logger
  alias ProxyConf.ConfigGenerator.DownstreamAuth
  alias ProxyConf.ConfigGenerator.UpstreamAuth

  defstruct([
    :filename,
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
    :spec,
    type: :oas3
  ])

  @typedoc """
    title: API Identifier
    description: A unique identifier for the API, used for API-specific logging, monitoring, and identification in ProxyConf and Envoyproxy. This ID is essential for tracking and debugging API traffic across the system.
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
  @type downstream_auth :: ProxyConf.ConfigGenerator.DownstreamAuth.t()

  @typedoc """
    title: Upstream Authentication
    description: Configuration for upstream authentication.
  """
  @type upstream_auth :: ProxyConf.ConfigGenerator.UpstreamAuth.t()

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
    description: The `x-proxyconf` property extends the OpenAPI specification with ProxyConf-specific configurations, enabling ProxyConf to generate the necessary resources to integrate with [Envoyproxy](https://www.envoyproxy.io/).
    required:
      - security
  """
  @type proxyconf :: %{
          api_id: api_id(),
          cluster: cluster(),
          listener: ProxyConf.ConfigGenerator.Listener.t(),
          url: url(),
          routing: routing(),
          security: security()
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
          x_proxyconf: proxyconf()
        }

  def from_oas3(filename, spec, data) do
    proxyconf = Map.fetch!(spec, "x-proxyconf")

    config_from_spec =
      defaults(filename)
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
      }
    } = config_from_spec

    {:ok,
     %__MODULE__{
       filename: filename,
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
       spec: spec
     }}
  end

  def gen_hash(data) when is_binary(data) do
    :crypto.hash(:sha256, data) |> Base.encode64()
  end

  defp defaults(filename) do
    api_id = Path.rootname(filename) |> Path.basename()

    api_url =
      default(
        :default_api_host,
        "http://localhost:#{Application.get_env(:proxyconf, :default_api_port, 8080)}/#{api_id}"
      )
      |> URI.parse()

    %{
      "api-id" => api_id,
      "url" => "#{api_url.scheme}://#{api_url.host}:#{api_url.port}/#{api_id}",
      "cluster" => default(:default_cluster_id, "proxyconf-cluster"),
      "listener" => %{
        "address" => "127.0.0.1",
        "port" => api_url.port
      },
      "security" => %{"allowed-source-ips" => ["127.0.0.1/8"], "auth" => %{"upstream" => nil}},
      "routing" => %{
        "fail-fast-on-missing-query-parameter" => true,
        "fail-fast-on-missing-header-parameter" => true,
        "fail-fast-on-wrong-request-media_type" => true
      }
    }
  end

  defp default(env_var, default) do
    Application.get_env(
      :proxyconf,
      env_var,
      default
    )
  end

  defp to_cidrs(subnet) when is_binary(subnet), do: to_cidrs([subnet])

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
