defmodule ProxyConf.ConfigGenerator.ClusterLbEndpoint do
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
