
# Downstream Authentication

| Property | `DownstreamAuth` *`(choice)`* |
 | --- | --- |
| **options** | <ul><li>[Header or Query Parameter](#header-or-query-parameter)</li><li>[Basic Authentication](#basic-authentication)</li><li>[JSON Web Tokens (JWT)](#json-web-tokens-jwt)</li><li>[Mutual TLS](#mutual-tls)</li><li>[Disabled](#disabled)</li></ul> |

The `downstream` object configures the authentication mechanism applied to downstream HTTP requests. Defining an authentication mechanism is required, but can be opted-out by explicitely configuring `disabled`.


## Header or Query Parameter

| Choice Option | `DownstreamAuth` *`(object)`* |
 | --- | --- |
| **additionalProperties** | `false` |
| **properties** | [`clients`](#allowed-clients), [`matcher`](#matcher), [`name`](#parameter-name), [`type`](#parameter-type) |
| **optional** | [`matcher`](#matcher) |

Enabling authentication for all clients that access this API using a header or query string parameter. The header or query string parameter is matched against the md5 hashes provided in the `clients` property.


### Allowed Clients

| Property | `clients` *`(object)`* |
 | --- | --- |
| **additionalProperties** | `true` |

The clients are matches based on the md5 hash or based on the list of match results.


### Matcher

| Property | `matcher` *`(string)`* |
 | --- | --- |

Extracts values from the parameter and compares them with the match results provided in the client list.


### Parameter Name

| Property | `name` *`(string)`* |
 | --- | --- |

The parameter name (header or query string parameter name) where the credentials are provided.


### Parameter Type

| Property | `type` *`()`* |
 | --- | --- |
| **enum** | `query`, `header` |

The parameter type that is used to transport the credentials


## Basic Authentication

| Choice Option | `DownstreamAuth` *`(object)`* |
 | --- | --- |
| **additionalProperties** | `false` |
| **properties** | [`clients`](#allowed-clients), [`type`](#authentication-type) |

Enabling basic authentication for all clients that access this API. The username and password in the `Authorization` header are matched against the md5 hashes provided in the `clients` property.


### Allowed Clients

| Property | `clients` *`(object)`* |
 | --- | --- |
| **additionalProperties** | `true` |

The clients are matches based on the md5 hash.


### Authentication Type

<table><tr><th>Constant</th><th><code>basic <i>(string)</i></code></th></tr></table>
Constant `basic` identifiying that HTTP Basic Authentication is used for authenticating downstream HTTP requests.


## JSON Web Tokens (JWT)

| Choice Option | `DownstreamAuth` *`(object)`* |
 | --- | --- |
| **additionalProperties** | `false` |
| **properties** | [`provider-config`](#provider-configuration), [`type`](#authentication-type) |

Enabling JWT based authentication for all clients that access this API.The signature, audiences, and issuer claims are verified. It will also check its time restrictions, such as expiration and nbf (not before) time. If the JWT verification fails, its request will be rejected. If the JWT verification succeeds, its payload can be forwarded to the upstream for further authorization if desired.


### Provider Configuration

| Property | `provider-config` *`(object)`* |
 | --- | --- |
| **additionalProperties** | `true` |

Configures how JWT should be verified. [See the Envoy documentation for configuration details](https://www.envoyproxy.io/docs/envoy/latest/api-v3/extensions/filters/http/jwt_authn/v3/config.proto#envoy-v3-api-msg-extensions-filters-http-jwt-authn-v3-jwtprovider)

- `issuer`: the principal that issued the JWT, usually a URL or an email address.
- `audiences`: a list of JWT audiences allowed to access. A JWT containing any of these audiences will be accepted. If not specified, the audiences in JWT will not be checked.
- `local_jwks`: fetch JWKS in local data source, either in a local file or embedded in the inline string.
- `remote_jwks`: fetch JWKS from a remote HTTP server, also specify cache duration.
- `forward`: if true, JWT will be forwarded to the upstream.
- `from_headers`: extract JWT from HTTP headers.
- `from_params`: extract JWT from query parameters.
- `from_cookies`: extract JWT from HTTP request cookies.
- `forward_payload_header`: forward the JWT payload in the specified HTTP header.
- `claim_to_headers`: copy JWT claim to HTTP header.
- `jwt_cache_config`: Enables JWT cache, its size can be specified by jwt_cache_size. Only valid JWT tokens are cached.



### Authentication Type

<table><tr><th>Constant</th><th><code>jwt <i>(string)</i></code></th></tr></table>
Constant `jwt` identifiying that JWT are used for authenticating downstream HTTP requests.


## Mutual TLS

| Choice Option | `DownstreamAuth` *`(object)`* |
 | --- | --- |
| **additionalProperties** | `false` |
| **properties** | [`clients`](#allowed-clients), [`trusted-ca`](#trusted-certificate-authority-ca), [`type`](#authentication-type) |

Enabling mutual TLS for all clients that access this API. The `subject` or `SAN` in the provided client certificate is matched against the list provided in the `clients` property.


### Allowed Clients

| Property | `clients` *`(object)`* |
 | --- | --- |
| **additionalProperties** | `true` |

The clients are matches based on the client certificate subject or SAN


### Trusted Certificate Authority (CA)

| Property | `trusted-ca` *`(string)`* |
 | --- | --- |

A path to a PEM encoded file containing the trusted CAs. This file must be readable by the ProxyConf server and is automatically distributed to the Envoy instances using the SDS mechanism


### Authentication Type

<table><tr><th>Constant</th><th><code>mtls <i>(string)</i></code></th></tr></table>
Constant `mtls` identifiying that mutual TLS is used for authenticating downstream HTTP requests.


## Disabled

<table><tr><th>Choice Option</th><th><code>DownstreamAuth <i>(disabled)</i></code></th></tr></table>
Disabling any downstream authentication. This potentially allows untrusted traffic. It's recommended to further limit exposure by narrowing the `allowed-source-ips` as much as possible.
```yaml title="Example"
security:
  auth:
    downstream: disabled

```
