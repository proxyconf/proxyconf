defmodule ProxyConf.Commons.Gen.Cors do
  @moduledoc """
    This implements the config generator for the CORS HTTP filter
  """

  @typedoc """
    title: access-control-allow-origins
    description: Controls the HTTP `Access-Control-Allow-Origin` response header, which indicates whether the response can be shared with requesting code from the given origin.
  """
  @type access_control_allow_origins() :: nil | [String.t()]

  @typedoc """
    title: access-control-allow-methods
    description: Controls the HTTP `Access-Control-Allow-Methods` response header, which specifies one or more HTTP request methods allowed when accessing a resource in response to a preflight request.
  """
  @type access_control_allow_methods() :: nil | [String.t()]

  @typedoc """
    title: access-control-allow-headers
    description: Controls the HTTP `Access-Control-Allow-Headers` response header, which is used in response to a preflight request to indicate the HTTP headers that can be used during the actual request. This header is required if the preflight request contains `Access-Control-Request-Headers`.
  """
  @type access_control_allow_headers() :: nil | [String.t()]

  @typedoc """
    title: access-control-expose-headers
    description: Controls the HTTP `Access-Control-Expose-Headers` response header, which allows a server to indicate which response headers should be made available to scripts running in the browser in response to a cross-origin request.
  """
  @type access_control_expose_headers() :: nil | [String.t()]

  @typedoc """
    title: delta-seconds
    description: Maximum number of seconds for which the results can be cached as an unsigned non-negative integer. Firefox caps this at 24 hours (86400 seconds). Chromium (prior to v76) caps at 10 minutes (600 seconds). Chromium (starting in v76) caps at 2 hours (7200 seconds). The default value is 5 seconds.
  """
  @type delta_seconds() :: non_neg_integer()

  @typedoc """
    title: access-control-max-age
    description: Controls the HTTP `Access-Control-Max-Age` response header indicates how long the results of a preflight request (that is, the information contained in the `Access-Control-Allow-Methods` and `Access-Control-Allow-Headers` headers) can be cached.
  """
  @type access_control_max_age() :: nil | delta_seconds()

  @typedoc """
    title: access-control-allow-credentials
    description: Controls the HTTP `Access-Control-Allow-Credentials` response header, which tells browsers whether the server allows credentials to be included in cross-origin HTTP requests.
  """
  @type access_control_allow_credentials() :: nil | boolean()

  @typedoc """
    title: CORS Policy
    description: Defines the Cross-Origin Resource Sharing (CORS) policy configured for this API.
    required:
      - access-control-allow-origins
  """
  @type t() ::
          %{
            access_control_allow_origins: access_control_allow_origins(),
            access_control_allow_credentials: access_control_allow_credentials(),
            access_control_allow_methods: access_control_allow_methods(),
            access_control_allow_headers: access_control_allow_headers(),
            access_control_expose_headers: access_control_expose_headers(),
            access_control_max_age: access_control_max_age()
          }

  def merge_policy(nil, nil), do: nil
  def merge_policy(cors, nil), do: cors
  def merge_policy(nil, cors), do: cors

  def merge_policy(_main_cors, "disabled"), do: nil

  def merge_policy(main_cors, path_level_cors) do
    Map.merge(main_cors, path_level_cors)
  end

  def config_from_json(nil), do: nil
  def config_from_json("disabled"), do: nil

  def config_from_json(cors) when is_map(cors) do
    [
      {"access-control-allow-origins", "allow_origin_string_match", &origins/1},
      {"access-control-allow-methods", "allow_methods", &joiner/1},
      {"access-control-allow-headers", "allow_headers", &joiner/1},
      {"access-control-expose-headers", "expose_headers", &joiner/1},
      {"access-control-max-age", "max_age", &Integer.to_string/1},
      {"access-control-allow-credentials", "allow_credentials", & &1}
    ]
    |> Enum.reduce(
      %{
        "@type" => "type.googleapis.com/envoy.extensions.filters.http.cors.v3.CorsPolicy",
        "forward_not_matching_preflights" => false
      },
      fn {config_key, envoy_config_key, transformer}, acc ->
        case Map.get(cors, config_key) do
          nil ->
            acc

          v ->
            Map.put(acc, envoy_config_key, transformer.(v))
        end
      end
    )
  end

  defp origins(origins) do
    Enum.map(origins, fn o ->
      if String.contains?(o, "*") do
        %{
          "safe_regex" => %{
            "regex" =>
              o
              |> String.replace(".", "\\.")
              |> String.replace("*", ".*")
          }
        }
      else
        %{"exact" => o}
      end
    end)
  end

  defp joiner(list) do
    list
    |> Enum.map(&String.trim/1)
    |> Enum.join(",")
  end
end
