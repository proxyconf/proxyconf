
# OpenAPI Extension for ProxyConf

| Property | `config` *`(object)`* |
 | --- | --- |
| **additionalProperties** | `false` |
| **properties** | [`x-proxyconf`](#proxyconf-api-config) |


```yaml title="Example"
x-proxyconf:
  api-id: my-api
  cluster: proxyconf-envoy-cluster
  listener:
    address: 127.0.0.1
    port: 8080
  security:
    allowed-source-ips:
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
| **additionalProperties** | `false` |
| **properties** | [`api-id`](#api-identifier), [`cluster`](#cluster-identifier), [`cors`](#cors-policy), [`listener`](#listener-configuration), [`routing`](#routing), [`security`](#security-configuration), [`url`](#api-url) |
| **optional** | [`api-id`](#api-identifier), [`cluster`](#cluster-identifier), [`cors`](#cors-policy), [`listener`](#listener-configuration), [`routing`](#routing), [`url`](#api-url) |

The `x-proxyconf` property extends the OpenAPI specification with ProxyConf-specific configurations, enabling ProxyConf to generate the necessary resources to integrate with [Envoy Proxy](https://www.envoyproxy.io/).


### API Identifier

| Property | `api-id` *`(string)`* |
 | --- | --- |
| **minLength** | `1` |

A unique identifier for the API, used for API-specific logging, monitoring, and identification in ProxyConf and Envoy. This ID is essential for tracking and debugging API traffic across the system.


### Cluster Identifier

| Property | `cluster` *`(string)`* |
 | --- | --- |
| **minLength** | `1` |

The cluster identifier groups APIs for Envoy. This cluster name should also be reflected in the static `bootstrap` configuration of Envoy, ensuring that APIs are properly associated with the correct Envoy instances.


### CORS Policy

| Property | `cors` *`(object)`* |
 | --- | --- |
| **$ref** | [CORS Policy](#cors-policy) |

Defines the Cross-Origin Resource Sharing (CORS) policy configured for this API.


### Listener Configuration

| Property | `listener` *`(object)`* |
 | --- | --- |
| **$ref** | [Listener Configuration](#listener-configuration) |

The `listener` object configures the Envoy listener used to serve this API. Depending on the specified `url` property a TLS context is configured.


### Routing

| Property | `routing` *`(object)`* |
 | --- | --- |
| **additionalProperties** | `false` |
| **properties** | [`fail-fast-on-missing-header-parameter`](#fail-fast-on-missing-header-parameter), [`fail-fast-on-missing-query-parameter`](#fail-fast-on-missing-query-parameter), [`fail-fast-on-wrong-media-type`](#fail-fast-on-wrong-media-type) |




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

| Property | `fail-fast-on-wrong-media-type` *`(boolean)`* |
 | --- | --- |
| **default** | `true` |

Reject requests where the `content-type` header doesn't match the media types specified in the OpenAPI request body spec. You can override this behavior at the path level using the `x-proxyconf-fail-fast-on-wrong-media-type` field.


### Security Configuration

| Property | `security` *`(object)`* |
 | --- | --- |
| **additionalProperties** | `false` |
| **properties** | [`allowed-source-ips`](#allowed-source-ip-ranges), [`auth`](#authentication) |
| **optional** | [`allowed-source-ips`](#allowed-source-ip-ranges) |

The `security` object configures API-specific security features, such as IP filtering and authentication mechanisms. It supports both source IP filtering (allowing only specific IP ranges) and client authentication for downstream requests, as well as credential injection for upstream requests.


#### Allowed Source IP Ranges

| Property | `allowed-source-ips` *`(array)`* |
 | --- | --- |
| **Array Item** | `#/definitions/cidr` |

An array of allowed source IP ranges (in CIDR notation) that are permitted to access the API. This helps secure the API by ensuring only trusted IPs can communicate with it. For more details on CIDR notation, visit the [CIDR Documentation](https://en.wikipedia.org/wiki/Classless_Inter-Domain_Routing).


#### Authentication

| Property | `auth` *`(object)`* |
 | --- | --- |
| **additionalProperties** | `false` |
| **properties** | [`downstream`](#downstream-authentication), [`upstream`](#upstream-authentication) |
| **optional** | [`upstream`](#upstream-authentication) |

The auth object handles authentication for both downstream and upstream requests. This allows you to specify client authentication requirements for incoming requests and credential injection for outgoing requests to upstream services.


##### Downstream Authentication

| Property | `downstream` *`(choice)`* |
 | --- | --- |
| **$ref** | [Downstream Authentication](#downstream-authentication) |

The `downstream` object configures the authentication mechanism applied to downstream HTTP requests. Defining an authentication mechanism is required, but can be opted-out by explicitely configuring `disabled`.


##### Upstream Authentication

| Property | `upstream` *`(object)`* |
 | --- | --- |
| **$ref** | [Upstream Authentication](#upstream-authentication) |

Configure upstream authentication options.


### API URL

| Property | `url` *`(string)`* |
 | --- | --- |
| **format** | `uri` |

The API URL serves multiple functions:

- **Scheme**: Determines if TLS or non-TLS listeners are used (e.g., `http` or `https`).
- **Domain**: Used for virtual host matching in Envoy.
- **Path**: Configures prefix matching in Envoy's filter chain.
- **Port**: If specified, this overrides the default listener port. Ensure you explicitly configure HTTP ports `80` and `443`.

