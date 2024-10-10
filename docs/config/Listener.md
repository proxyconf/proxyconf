
# Listener Configuration

| Property | `Listener` *`(object)`* |
 | --- | --- |
| **additionalProperties** | `false` |
| **properties** | [`address`](#listener-address), [`port`](#listener-port) |

The `listener` object configures the Envoy listener used to serve this API. Depending on the provided `api_url` a TLS context is configured.


## Listener Address

| Property | `address` *`(choice)`* |
 | --- | --- |
| **default** | `127.0.0.1` |
| **options** | <ul><li>[IPv6](#ipv6)</li><li>[IPv4](#ipv4)</li></ul> |

The IP address Envoy listens for new TCP connections


### IPv6

<table><tr><th>Choice Option</th><th><code>address <i>(string)</i></code></th></tr></table>
IPv6 TCP Listener Address


### IPv4

<table><tr><th>Choice Option</th><th><code>address <i>(string)</i></code></th></tr></table>
IPv4 TCP Listener Address


## Listener Port

| Property | `port` *`(integer)`* |
 | --- | --- |
| **default** | `8080` |
| **maximum** | `65535` |
| **minimum** | `1` |

The port is extracted from the `api_url` if it is explicitely provided as part of the url. E.g. the implicit ports 80/443 for http/https are replaced by the default `8080`.
