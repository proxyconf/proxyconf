defmodule ProxyConf.AggregatedDiscoveryServiceServer do
  @moduledoc false
  require Logger
  use GRPC.Server, service: Envoy.Service.Discovery.V3.AggregatedDiscoveryService.Service

  alias Envoy.Service.Discovery.V3.DiscoveryRequest
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
           resource_names: _,
           type_url: type_url
         } = req,
         stream
       ) do
    node_info = node_info(req)

    if not is_nil(error) do
      Logger.error("ADS discovery request error #{inspect(error)}")
    end

    version =
      if version == "" do
        # first timeer
        0
      else
        case Integer.parse(version) do
          {version, ""} ->
            version

          _ ->
            Logger.warning(
              "Invalid ADS discovery request version #{inspect(version)} provided by node #{node_info.node_id}, reset to 0"
            )

            0
        end
      end

    ProxyConf.Stream.event(stream, node_info, type_url, version)
  end

  def nonce do
    "#{node()}#{DateTime.utc_now() |> DateTime.to_unix(:nanosecond)}" |> Base.encode64()
  end

  defp node_info(%DiscoveryRequest{node: %Node{id: node_id, cluster: cluster}}) do
    %{cluster: cluster, node_id: node_id}
  end
end
