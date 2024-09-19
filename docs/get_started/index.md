# Getting started with ProxyConf

We recommend using Docker containers to quickly get started with ProxyConf. In the `demo` folder of the GitHub repository, you’ll find a working `docker-compose` example that sets up an Envoy proxy, ProxyConf, and an upstream Swagger Petstore backend.

## Mutual TLS Setup

For secure communication between ProxyConf and Envoy, mutual TLS (mTLS) certificates are required. To make this process easier, a script for generating demo certificates is provided in the `demo` folder. Simply run the `setup-certificates.sh` script to generate the necessary certificates for your setup. In a production setup the certificates are typically issued by the corporate PKI or a specialized CA.

## Configuring Envoy

Envoy needs to be started with a minimal configuration file to establish a connection with the ProxyConf control plane. A sample configuration file is available in the `demo` folder, and it may look like the following:

### Node Configuration

The `node` section in an Envoy configuration file identifies the instance of Envoy within a larger system. It includes details like the node’s ID, cluster, and metadata that the control plane (such as ProxyConf) uses to manage and configure that particular Envoy instance. The information helps the control plane distinguish between different Envoy instances and apply the correct configuration dynamically.

```yaml
node:
  cluster: proxyconf-cluster
  id: proxyconf
```

!!! note
    
    A single ProxyConf setup can work with multiple Envoy clusters. It's recommended
    to use distinct node ids for logging purposes, but ProxyConf is able to distinguish the Envoy nodes even if they use the same node id.

    The `proxyconf-cluster` is the default cluster name used by ProxyConf. See the configuration page regarding how to adjust this default.


### Dynamic Resources Configuration

The `dynamic_resources` section in the Envoy configuration is used to define how Envoy dynamically fetches configuration data, such as clusters (upstream services) and listeners (network endpoints). It typically includes:

- `ads_config`: Specifies the Aggregated Discovery Service (ADS), allowing Envoy to receive configuration updates for multiple resources (e.g., clusters, routes, listeners) from a central control plane like ProxyConf.
- `cds_config`: Configuration for fetching cluster definitions dynamically via the Cluster Discovery Service (CDS).
- `lds_config`: Configuration for fetching listener definitions dynamically via the Listener Discovery Service (LDS).

In short, `dynamic_resources` allows Envoy to retrieve its configuration on-the-fly from an external control plane, making it more flexible and adaptable.

```yaml
dynamic_resources:
  ads_config:
    api_type: GRPC
    transport_api_version: V3
    grpc_services:
      - envoy_grpc:
          cluster_name: proxyconf-xds-cluster
  cds_config:
    resource_api_version: V3
    ads: {}
  lds_config:
    resource_api_version: V3
    ads: {}
```

!!! note

    This config section doesn't need any other adjustments and can be used as is.


### Static Resources Configuration

The `static_resources` section in Envoy is used to define resources that are hardcoded and do not change dynamically. When connecting Envoy to a control plan, a single static cluster is typically defined within this section. This static cluster allows Envoy to communicate with the control plane to retrieve dynamic configurations for other resources.

To ensure a secure connection between Envoy and the control plane, mutual TLS (mTLS) is required. mTLS guarantees that both Envoy and the control plane authenticate each other, protecting the transmission and integrity of sensitive data such as TLS certificates and secrets.

```yaml
static_resources:
  clusters:
    - type: STRICT_DNS
      typed_extension_protocol_options:
        envoy.extensions.upstreams.http.v3.HttpProtocolOptions:
          "@type": type.googleapis.com/envoy.extensions.upstreams.http.v3.HttpProtocolOptions
          explicit_http_config:
            http2_protocol_options: {}
      name: proxyconf-xds-cluster
      transport_socket:
        name: envoy.transport_sockets.tls
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext
          common_tls_context:
            tls_certificates:
            - certificate_chain:
                filename: /etc/data/client.crt
              private_key:
                filename: /etc/data/client.key
            validation_context:
              trusted_ca:
                filename: /etc/data/ca.crt
      load_assignment:
        cluster_name: proxyconf
        endpoints:
        - lb_endpoints:
          - endpoint:
              address:
                socket_address:
                  address: proxyconf
                  port_value: 18000
```

!!! note

    The cluster config above configures Envoy to communicate with a ProxyConf over the TCP port `18000` located at `proxyconf`. This name resolves to the ProxyConf container in the demo `docker-compose` setup, but needs adjustments if the control plane is deployed in a different location.


