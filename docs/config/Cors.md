
# CORS Policy

| Property | `Cors` *`(object)`* |
 | --- | --- |
| **additionalProperties** | `false` |
| **properties** | [`access-control-allow-credentials`](#access-control-allow-credentials), [`access-control-allow-headers`](#access-control-allow-headers), [`access-control-allow-methods`](#access-control-allow-methods), [`access-control-allow-origins`](#access-control-allow-origins), [`access-control-expose-headers`](#access-control-expose-headers), [`access-control-max-age`](#access-control-max-age) |
| **optional** | [`access-control-allow-credentials`](#access-control-allow-credentials), [`access-control-allow-headers`](#access-control-allow-headers), [`access-control-allow-methods`](#access-control-allow-methods), [`access-control-expose-headers`](#access-control-expose-headers), [`access-control-max-age`](#access-control-max-age) |

Defines the Cross-Origin Resource Sharing (CORS) policy configured for this API.


## access-control-allow-credentials

| Property | `access-control-allow-credentials` *`(boolean)`* |
 | --- | --- |

Controls the HTTP `Access-Control-Allow-Credentials` response header, which tells browsers whether the server allows credentials to be included in cross-origin HTTP requests.


## access-control-allow-headers

| Property | `access-control-allow-headers` *`(array)`* |
 | --- | --- |
| **Array Item** | `string` |

Controls the HTTP `Access-Control-Allow-Headers` response header, which is used in response to a preflight request to indicate the HTTP headers that can be used during the actual request. This header is required if the preflight request contains `Access-Control-Request-Headers`.


## access-control-allow-methods

| Property | `access-control-allow-methods` *`(array)`* |
 | --- | --- |
| **Array Item** | `string` |

Controls the HTTP `Access-Control-Allow-Methods` response header, which specifies one or more HTTP request methods allowed when accessing a resource in response to a preflight request.


## access-control-allow-origins

| Property | `access-control-allow-origins` *`(array)`* |
 | --- | --- |
| **Array Item** | `string` |

Controls the HTTP `Access-Control-Allow-Origin` response header, which indicates whether the response can be shared with requesting code from the given origin.


## access-control-expose-headers

| Property | `access-control-expose-headers` *`(array)`* |
 | --- | --- |
| **Array Item** | `string` |

Controls the HTTP `Access-Control-Expose-Headers` response header, which allows a server to indicate which response headers should be made available to scripts running in the browser in response to a cross-origin request.


## access-control-max-age

| Property | `access-control-max-age` *`(integer)`* |
 | --- | --- |
| **$ref** | [delta-seconds](#delta-seconds) |

Controls the HTTP `Access-Control-Max-Age` response header indicates how long the results of a preflight request (that is, the information contained in the `Access-Control-Allow-Methods` and `Access-Control-Allow-Headers` headers) can be cached.


### delta-seconds

| Property | `access-control-max-age` *`(integer)`* |
 | --- | --- |
| **minimum** | `0` |

Maximum number of seconds for which the results can be cached as an unsigned non-negative integer. Firefox caps this at 24 hours (86400 seconds). Chromium (prior to v76) caps at 10 minutes (600 seconds). Chromium (starting in v76) caps at 2 hours (7200 seconds). The default value is 5 seconds.
