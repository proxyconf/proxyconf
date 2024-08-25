defmodule ProxyConf.Spec do
  require Logger

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
         {_, true} <- {:listener_port_does_not_match_api_url, port == api_url.port},
         {allowed_source_ips, parse_result} <-
           Map.get(listener, "allowed_source_ips", ["127.0.0.1/32"]) |> to_cidrs(),
         {_, true} <- {:invalid_allowed_source_ips, parse_result},
         # downstream auth is validated in it's own module
         downstream_auth <- Map.get(spec, "x-proxyconf-downstream-auth") do
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

  defp to_cidrs(subnets) do
    Enum.map_reduce(subnets, true, fn
      _, false ->
        {nil, false}

      subnet, true ->
        with [address_prefix, prefix_length] <- String.split(subnet, "/"),
             {prefix_length, ""} <- Integer.parse(prefix_length) do
          {%{"address_prefix" => address_prefix, "prefix_len" => prefix_length}, true}
        else
          _ ->
            Logger.warning("Invalid CIDR range in 'allowed_source_ips' configuration #{subnet}")
            {nil, false}
        end
    end)
  end
end
