
# Downstream Authentication

| Property | `DownstreamAuth` *`(choice)`* |
 | --- | --- |
| **options** | <ul><li>[Mutual TLS](#mutual-tls)</li><li>[Disabled](#disabled)</li></ul> |

The `downstream` object configures the authentication mechanism applied to downstream HTTP requests. Defining an authentication mechanism is required, but can be opted-out by explicitely configuring `disabled`.


## Mutual TLS

| Choice Option | `DownstreamAuth` *`(object)`* |
 | --- | --- |
| **additionalProperties** | `false` |
| **properties** | [`clients`](#allowed-clients), [`trusted-ca`](#trusted-certificate-authority-ca), [`type`](#authentication-type) |

Enabling mutual TLS for all clients that access this API. The `subject` or `SAN` in the provided client certificate is matched against the list provided in the `clients` property.


### Allowed Clients

| Property | `clients` *`(object)`* |
 | --- | --- |
| **generic properties** | [Certificate Subject / SubjectAlternativeName (SAN)](#certificate-subject-subjectalternativename-san) |

The clients are matches based on the client certificate subject or SAN


#### Certificate Subject / SubjectAlternativeName (SAN)

| Generic Property | *`array`* |
 | --- | --- |
| **Array Item** | `string` |
| **minLength** | `1` |

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
