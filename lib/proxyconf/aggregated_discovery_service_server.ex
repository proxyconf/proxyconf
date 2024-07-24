defmodule ProxyConf.AggregatedDiscoveryServiceServer do
  use GRPC.Server, service: Envoy.Service.Discovery.V3.AggregatedDiscoveryService.Service

  alias ProxyConf.ConfigCache
  alias Envoy.Service.Discovery.V3.DiscoveryRequest
  alias Envoy.Service.Discovery.V3.DiscoveryResponse
  alias Envoy.Config.Core.V3.Node

  def stream_aggregated_resources(request, stream) do
    Enum.each(request, fn r ->
      handle_discovery_request(r, stream)
    end)
  end

  defp handle_discovery_request(
         %DiscoveryRequest{
           version_info: version,
           error_detail: error,
           resource_names: [],
           type_url: _type_url
         } = req,
         stream
       ) do
    IO.inspect(error)
    # empty resource names list means all resources are requested
    node_info = node_info(req)

    if version == "" do
      # first timeer
      ConfigCache.subscribe_stream(node_info, stream)
    end
  end

  def nonce do
    "#{node()}#{DateTime.utc_now() |> DateTime.to_unix(:nanosecond)}" |> Base.encode64()
  end

  defp node_info(%DiscoveryRequest{node: %Node{id: node_id, cluster: cluster}}) do
    %{cluster: cluster, node_id: node_id}
  end
end
