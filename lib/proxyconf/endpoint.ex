defmodule ProxyConf.Endpoint do
  use GRPC.Endpoint
  intercept(GRPC.Server.Interceptors.Logger)
  run(ProxyConf.AggregatedDiscoveryServiceServer)
  run(ProxyConf.SecretDiscoveryServiceServer)
end
