defmodule ProxyConf.SecretDiscoveryServiceServer do
  use GRPC.Server, service: Envoy.Service.Secret.V3.SecretDiscoveryService.Service
end
