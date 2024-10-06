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

  def from_oas3(filename, spec, data) do
    proxyconf = Map.fetch!(spec, "x-proxyconf")

    config_from_spec =
      defaults(filename)
      |> DeepMerge.deep_merge(proxyconf)
      |> update_in(["security", "allowed_source_ips"], &to_cidrs/1)
      |> update_in(["url"], &URI.parse/1)

    %{
      "cluster" => cluster_id,
      "url" => api_url,
      "api_id" => api_id,
      "listener" => %{"address" => address, "port" => port},
      "security" => %{
        "allowed_source_ips" => allowed_source_ips,
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
      "api_id" => api_id,
      "url" => "#{api_url.scheme}://#{api_url.host}:#{api_url.port}/#{api_id}",
      "cluster" => default(:default_cluster_id, "proxyconf-cluster"),
      "listener" => %{
        "address" => "127.0.0.1",
        "port" => api_url.port
      },
      "security" => %{"allowed_source_ips" => ["127.0.0.1/8"], "auth" => %{"upstream" => nil}},
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
