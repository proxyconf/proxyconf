defmodule ProxyConf.ConfigGenerator.ClusterLbEndpoint do
  @moduledoc """
    This module implements the cluster loadbalancer endpoint resource
  """
  use ProxyConf.MapTemplate

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
