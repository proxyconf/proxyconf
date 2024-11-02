
# Upstream Authentication

| Property | `UpstreamAuth` *`(object)`* |
 | --- | --- |
| **$ref** | [Upstream Authentication](#upstream-authentication) |

Configure upstream authentication options.


## Upstream Authentication

| Property | `UpstreamAuth` *`(object)`* |
 | --- | --- |
| **additionalProperties** | `false` |
| **properties** | [`name`](#header-name), [`overwrite`](#overwrite-header), [`type`](#authentication-type), [`value`](#header-value) |
| **optional** | [`overwrite`](#overwrite-header) |

Configure upstream authentication options.


### Header Name

| Property | `name` *`(string)`* |
 | --- | --- |

The header name where the credentials are injected.


### Overwrite Header

| Property | `overwrite` *`(boolean)`* |
 | --- | --- |
| **default** | `true` |

If set to `true` an existing header is overwritten.


### Authentication Type

<table><tr><th>Constant</th><th><code>header <i>(string)</i></code></th></tr></table>
Constant `header` identifiying that credentials should be injected in a header for authenticating upstream HTTP requests.


### Header Value

| Property | `value` *`(string)`* |
 | --- | --- |

The header value that is injected.
