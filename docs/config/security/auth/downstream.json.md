
# Downstream Authentication

|  |  |
 | --- | --- |
| **oneOf** | <table><tr><td>Disabled</td></tr><tr><td>Mutual TLS</td></tr><tr><td>Basic Authentication</td></tr><tr><td>Header or Query Parameter</td></tr><tr><td>JSON Web Tokens (JWT)</td></tr></table> |

The `downstream` object configures the authentication mechanism applied to downstream HTTP requests. Defining an authentication mechanism is required, but can be opted-out by explicitely configuring `disabled`.

## Disabled

<table><tr><th>Constant</th><th><code>disabled <i>(string)</i></code></th></tr></table>
```yaml title="Example"
security:
  auth:
    downstream: disabled

```
Disabling any downstream authentication. This potentially allows untrusted traffic. It's recommended to further limit exposure by narrowing the `allowed_source_ips` as much as possible

## Mutual TLS

| Property | `root` *`(object)`* |
 | --- | --- |
| **properties** | `clients`, `trusted_ca`, `type` |
| **required** | `type`, `trusted_ca`, `clients` |

```yaml title="Example"
security:
  auth:
    downstream:
      clients:
        my_sample:
          - MY-SAMPLE-CLIENT-SUBJECT
      trusted_ca: path/to/my/trusted-ca.pem
      type: mtls

```
Enabling mutual TLS for all clients that access this API. The `subject` or `SAN` in the provided client certificate is matched against the list provided in the `clients` property.

### Allowed Clients


The clients are matches based on the client certificate subject or SAN

### Trusted Certificate Authority (CA)

| Property | `trusted_ca` *`(string)`* |
 | --- | --- |
| **minLength** | `1` |

A path to a PEM encoded file containing the trusted CAs. This file must be readable by the ProxyConf server and is automatically distributed to the Envoy instances using the SDS mechanism

### Authentication Type

<table><tr><th>Constant</th><th><code>mtls <i>(string)</i></code></th></tr></table>
Constant `mtls` identifiying that mutual TLS is used for authenticating downstream HTTP requests.

## Basic Authentication

| Property | `root` *`(object)`* |
 | --- | --- |
| **properties** | `clients`, `type` |
| **required** | `type`, `clients` |

Enabling basic authentication for all clients that access this API. The username and password in the `Authorization` header are matched against the md5 hashes provided in the `clients` property.

### Allowed Clients


The clients are matches based on the md5 hash.

### Authentication Type

<table><tr><th>Constant</th><th><code>basic <i>(string)</i></code></th></tr></table>
Constant `basic` identifiying that HTTP basic authentication is used for authenticating downstream HTTP requests.

## Header or Query Parameter

| Property | `root` *`(object)`* |
 | --- | --- |
| **properties** | `clients`, `name`, `type` |
| **required** | `type`, `name`, `clients` |

Enabling authentication for all clients that access this API using a header or query string parameter. The header or query string parameter is matched against the md5 hashes provided in the `clients` property.

### Allowed Clients

| Property | `clients` *`(object)`* |
 | --- | --- |
| **properties** |  |

The clients are matches based on the md5 hash.

### Parameter Name

| Property | `name` *`(string)`* |
 | --- | --- |
| **minLength** | `1` |

The parameter name (header or query string parameter name) where the credentials are provided.

### Parameter Type

| Property | `type` *`(string)`* |
 | --- | --- |
| **enum** | `header`, `query` |

The parameter type that is used to transport the credentials

## JSON Web Tokens (JWT)

| Property | `root` *`(object)`* |
 | --- | --- |
| **properties** | `provider_config`, `type` |
| **required** | `type`, `provider_config` |

Enabling JWT based authentication for all clients that access this API.The signature, audiences, and issuer claims are verified. It will also check its time restrictions, such as expiration and nbf (not before) time. If the JWT verification fails, its request will be rejected. If the JWT verification succeeds, its payload can be forwarded to the upstream for further authorization if desired.

### Provider Configuration


Configures how JWT should be verified. It has the following fields:

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

[See the Envoy documentation for configuration details](https://www.envoyproxy.io/docs/envoy/latest/api-v3/extensions/filters/http/jwt_authn/v3/config.proto#envoy-v3-api-msg-extensions-filters-http-jwt-authn-v3-jwtprovider)

### Authentication Type

<table><tr><th>Constant</th><th><code>jwt <i>(string)</i></code></th></tr></table>
Constant `jwt` identifiying that JWT bearer tokens are used for authenticating downstream HTTP requests.