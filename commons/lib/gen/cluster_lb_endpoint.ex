defmodule ProxyConf.Commons.Gen.ClusterLbEndpoint do
  @moduledoc """
    This module implements the cluster loadbalancer endpoint resource
  """
  use ProxyConf.Commons.MapTemplate

  deftemplate(%{
    "endpoint" => %{
      "address" => %{
        "socket_address" => %{
          "address" => :host,
          "port_value" => :port
        }
      }
    }
  })
end
