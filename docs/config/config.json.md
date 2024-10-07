
# OpenAPI Extension for ProxyConf

| Property | `root` *`(object)`* |
 | --- | --- |
| **properties** | `x-proxyconf` |
| **required** | `x-proxyconf` |

```yaml title="Example"
x-proxyconf:
  api_id: my-api
  cluster: proxyconf-envoy-cluster
  listener:
    address: 127.0.0.1
    port: 8080
  security:
    allowed_source_ips:
      - 192.168.0.0/16
    auth:
      downstream:
        clients:
          testUser:
            - 9a618248b64db62d15b300a07b00580b
        name: x-api-key
        type: header
  url: https://api.example.com:8080/my-api

```


## ProxyConf API Config

| Property | `x-proxyconf` *`(object)`* |
 | --- | --- |
| **properties** | `api_id`, `cluster`, `listener`, `routing`, `security`, `url` |
| **required** | `security` |

The `x-proxyconf` property extends the OpenAPI specification with ProxyConf-specific configurations, enabling ProxyConf to generate the necessary resources to integrate with [Envoyproxy](https://www.envoyproxy.io/).

### API Identifier

| Property | `api_id` *`(string)`* |
 | --- | --- |
| **default** | `The OpenAPI Spec filename is used as the default value.` |
| **minLength** | `1` |

A unique identifier for the API, used for API-specific logging, monitoring, and identification in ProxyConf and Envoyproxy. This ID is essential for tracking and debugging API traffic across the system.

### Cluster Identifier

| Property | `cluster` *`(string)`* |
 | --- | --- |
| **default** | `proxyconf-cluster` |
| **minLength** | `1` |

The cluster identifier groups APIs for Envoy. This cluster name should also be reflected in the static `bootstrap` configuration of Envoy, ensuring that APIs are properly associated with the correct Envoy instances.

### Listener Configuration

| Property | `listener` *`()`* |
 | --- | --- |
| **$ref** | <a href="/config/listener.json">Listener Configuration</a> |

The `listener` object defines the configuration of the Envoy listener for this API. This includes the address and port where Envoy should listen for incoming requests. Based on the API URL provided, ProxyConf will automatically configure TLS if needed.

### Routing Configuration

| Property | `routing` *`(object)`* |
 | --- | --- |
| **properties** | `fail-fast-on-missing-header-parameter`, `fail-fast-on-missing-query-parameter`, `fail-fast-on_wrong-media-type` |

The `routing` object allows control over request routing behavior. This includes settings to reject requests that don't meet OpenAPI specification requirements, such as missing required headers or query parameters. This level of control is crucial for maintaining API contract integrity.

#### Fail Fast on Missing Header Parameter

| Property | `fail-fast-on-missing-header-parameter` *`(boolean)`* |
 | --- | --- |
| **default** | `true` |

Reject requests that are missing required headers as defined in the OpenAPI spec. You can override this setting at the path level using the `x-proxyconf-fail-fast-on-missing-header-parameter` field in the OpenAPI path definition.

#### Fail Fast on Missing Query Parameter

| Property | `fail-fast-on-missing-query-parameter` *`(boolean)`* |
 | --- | --- |
| **default** | `true` |

Reject requests that are missing required query parameters. Similar to headers, this setting can be overridden at the path level with the `x-proxyconf-fail-fast-on-missing-query-parameter` field.

#### Fail Fast on Wrong Media Type

| Property | `fail-fast-on_wrong-media-type` *`(boolean)`* |
 | --- | --- |
| **default** | `true` |

Reject requests where the `content-type` header doesn't match the media types specified in the OpenAPI request body spec. You can override this behavior at the path level using the `x-proxyconf-fail-fast-on-wrong-media-type` field.

### Security Configuration

| Property | `security` *`(object)`* |
 | --- | --- |
| **properties** | `allowed_source_ips`, `auth` |
| **required** | `auth` |

The `security` object configures API-specific security features, such as IP filtering and authentication mechanisms. It supports both source IP filtering (allowing only specific IP ranges) and client authentication for downstream requests, as well as credential injection for upstream requests.

#### Allowed Source IP Ranges

| Property | `allowed_source_ips` *`(array)`* |
 | --- | --- |
| **default** | `127.0.0.1/8` |
| **uniqueItems** | `true` |

An array of allowed source IP ranges (in CIDR notation) that are permitted to access the API. This helps secure the API by ensuring only trusted IPs can communicate with it. For more details on CIDR notation, visit the [CIDR Documentation](https://en.wikipedia.org/wiki/Classless_Inter-Domain_Routing).

##### IP Address Range

| Property | `Array Item` *`(string)`* |
 | --- | --- |
| **format** | `cidr` |

The IP address range in CIDR notation.

#### Authentication

| Property | `auth` *`(object)`* |
 | --- | --- |
| **properties** | `downstream`, `upstream` |
| **required** | `downstream` |

The `auth` object handles authentication for both downstream and upstream requests. This allows you to specify client authentication requirements for incoming requests and credential injection for outgoing requests to upstream services.

##### Downstream Authentication

| Property | `downstream` *`()`* |
 | --- | --- |
| **$ref** | <a href="/config/security/auth/downstream.json">Downstream Authentication</a> |

Configuration for downstream client authentication. This typically involves specifying authentication types (e.g., API keys) and client credentials.

##### Upstream Authentication

| Property | `upstream` *`()`* |
 | --- | --- |
| **$ref** | <a href="/config/security/auth/upstream.json">Upstream Authentication</a> |

Configuration for upstream service authentication. This allows ProxyConf to inject credentials (e.g., JWT tokens) when connecting to upstream services.

### API URL

| Property | `url` *`(string)`* |
 | --- | --- |
| **default** | `http://localhost:8080/{api_id}` |
| **format** | `uri` |

The API URL serves multiple functions:
- **Scheme**: Determines if TLS or non-TLS listeners are used (e.g., `http` or `https`).
- **Domain**: Used for virtual host matching in Envoy.
- **Path**: Configures prefix matching in Envoy's filter chain.
- **Port**: If specified, this overrides the default listener port. Ensure you explicitly configure HTTP ports `80` and `443`.