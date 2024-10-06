defmodule ProxyConf.Ext do
  @moduledoc """
    This module implements the ProxyConf OpenAPI Extension
  """
  require Logger

  def config_from_spec(filename, spec) when is_map(spec) do
    proxyconf = Map.fetch!(spec, "x-proxyconf")

    defaults(filename)
    |> DeepMerge.deep_merge(proxyconf)
    |> update_in(["security", "allowed_source_ips"], &to_cidrs/1)
    |> update_in(["url"], &URI.parse/1)
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
