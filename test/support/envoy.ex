defmodule ProxyConf.TestSupport.Envoy do
  @moduledoc false

  import ProxyConf.TestSupport.Common

  def start_envoy(config) do
    File.mkdir_p!("/tmp/proxyconf-testing")
    config_file = "/tmp/proxyconf-testing/#{config.cluster_id}.json"

    envoy_config =
      %{
        "admin" => %{
          "address" => %{
            "socket_address" => %{
              "address" => "127.0.0.1",
              "port_value" => config.admin_port
            }
          }
        },
        "dynamic_resources" => %{
          "ads_config" => %{
            "api_type" => "GRPC",
            "grpc_services" => [
              %{"envoy_grpc" => %{"cluster_name" => "proxyconf-xds-cluster"}}
            ],
            "transport_api_version" => "V3"
          },
          "cds_config" => %{
            "resource_api_version" => "V3",
            "ads" => %{}
          },
          "lds_config" => %{
            "resource_api_version" => "V3",
            "ads" => %{}
          }
        },
        "node" => %{"cluster" => config.cluster_id, "id" => "proxyconf1"},
        "static_resources" => %{
          "clusters" => [
            %{
              "load_assignment" => %{
                "cluster_name" => "proxyconf-xds-cluster",
                "endpoints" => [
                  %{
                    "lb_endpoints" => [
                      %{
                        "endpoint" => %{
                          "address" => %{
                            "socket_address" => %{
                              "address" => "127.0.0.1",
                              "port_value" => 18000
                            }
                          }
                        }
                      }
                    ]
                  }
                ]
              },
              "name" => "proxyconf-xds-cluster",
              "transport_socket" => %{
                "name" => "envoy.transport_sockets.tls",
                "typed_config" => %{
                  "@type" =>
                    "type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext",
                  "common_tls_context" => %{
                    "tls_certificates" => [
                      %{
                        "certificate_chain" => %{
                          "filename" => "/tmp/proxyconf/client-cert.pem"
                        },
                        "private_key" => %{
                          "filename" => "/tmp/proxyconf/client-key.pem"
                        }
                      }
                    ]
                  }
                }
              },
              "type" => "STRICT_DNS",
              "typed_extension_protocol_options" => %{
                "envoy.extensions.upstreams.http.v3.HttpProtocolOptions" => %{
                  "@type" =>
                    "type.googleapis.com/envoy.extensions.upstreams.http.v3.HttpProtocolOptions",
                  "explicit_http_config" => %{"http2_protocol_options" => %{}}
                }
              }
            }
          ]
        }
      }
      |> Jason.encode!()

    File.write!(config_file, envoy_config)

    port =
      Port.open({:spawn_executable, "envoy-contrib"},
        args: [
          "-c",
          "#{config_file}",
          "-l",
          "error",
          "--log-path /tmp/envoy-test-#{config.cluster_id}.log",
          "--base-id",
          "#{config.admin_port}"
        ]
      )

    Map.put(config, :port, port)
  end
end
