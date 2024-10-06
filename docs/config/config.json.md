
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

The x-proxyconf property extends the OpenAPI specification with ProxyConf-specific configurations, used to generate the necessary resources for Envoyproxy.


### API Identifier

| Property | `api_id` *`(string)`* |
 | --- | --- |
| **default** | `The OpenAPI Spec filename is used as default` |
| **minLength** | `1` |

The identifier used by ProxyConf to identify the API. The identifier is used for API specific logging and monitoring inside ProxyConf and Envoyproxy.

### Cluster Identifier

| Property | `cluster` *`(string)`* |
 | --- | --- |
| **default** | `proxyconf-cluster` |
| **minLength** | `1` |

The cluster identifier is used to group APIs belonging to different Envoy clusters. Note: the cluster identifier used also be provided by the static "bootstrap" Envoy configuration.


### Listener

| Property | `listener` *`()`* |
 | --- | --- |
| **$ref** | <a href="/config/listener.json">Listener</a> |

The `listener` object configures the Envoy listener used to serve this API. Depending on the provided `api_url` a TLS context is configured.

### Routing Configuration

| Property | `routing` *`(object)`* |
 | --- | --- |
| **properties** | `fail-fast-on-missing-header-parameter`, `fail-fast-on-missing-query-parameter`, `fail-fast-on_wrong-media-type` |

The `routing` object can be used to control request routing behaviour. Currently it's possible to reject requests that fail some parameter requirements outlined in the OpenAPI spec.

#### Fail fast on missing header parameter

| Property | `fail-fast-on-missing-header-parameter` *`(boolean)`* |
 | --- | --- |
| **default** | `true` |

Rejects a request if a required header is missing. This setting has a path level override `x-proxyconf-fail-fast-on-missing-header-parameter`.

#### Fail fast on missing query parameter

| Property | `fail-fast-on-missing-query-parameter` *`(boolean)`* |
 | --- | --- |
| **default** | `true` |

Rejects a request if a required query parameter is missing. This setting has a path level override `x-proxyconf-fail-fast-on-missing-query-parameter`.

#### Fail fast on wrong media type

| Property | `fail-fast-on_wrong-media-type` *`(boolean)`* |
 | --- | --- |
| **default** | `true` |

Rejects a request if the media type providd in the `content-type` header doesn't match the specification. This setting has a path level override `x-proxyconf-fail-fast-on-wrong-media-type`.

### Security Configuration

| Property | `security` *`(object)`* |
 | --- | --- |
| **properties** | `allowed_source_ips`, `auth` |
| **required** | `auth` |

The `security` object allows configuration of API-specific security features. Currently, it supports settings for source IP filtering, downstream request authentication, and injecting credentials for upstream requests.


#### Allowed Source IP Address Ranges

| Property | `allowed_source_ips` *`(array)`* |
 | --- | --- |
| **default** | `127.0.0.1/8` |
| **uniqueItems** | `true` |

The `allowed_source_ips` array specifies the source IP address ranges that are allowed to access the API.

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

The `auth` object allows configuring downstream request authentication, and injecting credentials for upstream requests.

##### Downstream Authentication

| Property | `downstream` *`()`* |
 | --- | --- |
| **$ref** | <a href="/config/security/auth/downstream.json">Downstream Authentication</a> |

Configure downstream authentication options.

##### Upstream Authentication

| Property | `upstream` *`()`* |
 | --- | --- |
| **$ref** | <a href="/config/security/auth/upstream.json">Upstream Authentication</a> |

Configure upstream authentication options.

### API URL

| Property | `url` *`(string)`* |
 | --- | --- |
| **default** | `http://localhost:8080/{api_id}` |
| **format** | `uri` |

The API URL serves several functions. The scheme in the `url` (e.g., `http` or `https`) determines whether ProxyConf configures a TLS or non-TLS Envoy listener.

The domain name in the `url` is used to set up virtual host matching in the Envoy filter chain, while the path configures prefix matching within the same chain.

If a TCP port is specified in the `url`, it overrides the default listener port. Note: The default HTTP ports, 80 and 443, must be explicitly configured.
