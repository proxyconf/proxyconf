
# Listener Configuration

| Property | `root` *`(object)`* |
 | --- | --- |
| **properties** | `address`, `port` |

The `listener` object configures the Envoy listener used to serve this API. Depending on the provided `api_url` a TLS context is configured.

## Listener Address

|  |  |
 | --- | --- |
| **default** | `127.0.0.1` |
| **oneOf** | <table><tr><td>IPv4</td></tr><tr><td>IPv6</td></tr></table> |

The IP address Envoy listens for new TCP connections

### IPv4

| Property | `address` *`(string)`* |
 | --- | --- |
| **format** | `ipv4` |

IPv4 TCP Listener Address

### IPv6

| Property | `address` *`(string)`* |
 | --- | --- |
| **format** | `ipv6` |

IPv6 TCP Listener Address

## TCP Listener Port

| Property | `port` *`(integer)`* |
 | --- | --- |
| **default** | `8080` |
| **maximum** | `65535` |
| **minimum** | `1` |

The port is extracted from the `api_url` if it is explicitely provided as part of the url. E.g. the implicit ports 80/443 for http/https are replaced by the default `8080`.