# Getting started with ProxyConf

We recommend using Docker containers to quickly get started with ProxyConf.

## Demo Setup

To quickly explore the capabilities of **ProxyConf**, we provide a demo environment that can be easily launched using Docker Compose. The demo setup, located inside the [`demo` folder](https://github.com/proxyconf/proxyconf/demo), includes all the necessary components to run a local instance of Envoyproxy with ProxyConf, configured to proxy traffic to a local instance of the **Swagger Petstore** API.

### Steps to Run the Demo:
1. **Generate TLS Certificates**: Before starting the demo, you need to generate the required TLS certificates by running the `setup-certificates.sh` script located in the `demo` folder:
   ```bash
   ./setup-certificates.sh
   ```
For secure communication between ProxyConf and Envoy, mutual TLS (mTLS) certificates are required. The `setup-certificates.sh` script generates the necessary certificates for the demo setup. In a production setup the certificates are typically issued by the corporate PKI or a specialized CA.

2. **Start the Demo Environment**: Once the certificates are generated, you can bring up the environment with Docker Compose:
   ```bash
   docker-compose up --pull always
   ```

3. **Explore the Setup**: The demo environment sets up **ProxyConf** to manage and secure Envoyproxy, which acts as a gateway proxying traffic to a local instance of the **Swagger Petstore**. The Swagger Petstore is a sample API, allowing you to test ProxyConf’s routing, security, and traffic management features in a real-world scenario. E.g.:
  ```bash
  curl -vv https://localhost:8080/petstore/pet/findByStatus --cacert demo/proxyconf/ca.crt -H "my-api-key: supersecret"
  ``` 

### Key Components:
- **Envoyproxy**: Handles traffic routing and load balancing.
- **ProxyConf**: Configures Envoyproxy using OpenAPI specs, providing centralized policy management and enhanced security features.
- **Swagger Petstore**: A demo API specified in `demo/proxyconf/oas3specs/petstore.yaml` that Envoy proxies traffic to, allowing you to experiment with API management features such as routing, TLS termination, and request validation.

This demo provides a hands-on way to see how **ProxyConf** simplifies the configuration and management of Envoyproxy.


## Node Configuration

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


## Dynamic Resources Configuration

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


## Static Resources Configuration

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


