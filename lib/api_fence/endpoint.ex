defmodule ApiFence.Endpoint do
  use GRPC.Endpoint
  intercept(GRPC.Server.Interceptors.Logger)
  run(ApiFence.AggregatedDiscoveryServiceServer)
  run(ApiFence.SecretDiscoveryServiceServer)
end
