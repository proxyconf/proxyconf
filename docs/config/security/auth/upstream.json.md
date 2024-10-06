
# Upstream Authentication

| Property | `root` *`(object)`* |
 | --- | --- |
| **properties** | `name`, `overwrite`, `type`, `value` |
| **required** | `type`, `name`, `value` |

Configure upstream authentication options.

## Header Name

| Property | `name` *`(string)`* |
 | --- | --- |
| **minLength** | `1` |

The header name where the credentials are injected.

## Overwrite Header

| Property | `overwrite` *`(boolean)`* |
 | --- | --- |
| **default** | `false` |

If set to `true` an existing header is overwritten.

## Authentication Type

<table><tr><th>Constant</th><th><code>header <i>(string)</i></code></th></tr></table>
Constant `header` identifiying that credentials should be injected in a header for authenticating upstream HTTP requests.

## Header Value

| Property | `value` *`(string)`* |
 | --- | --- |
| **minLength** | `1` |

The header value that is injected.