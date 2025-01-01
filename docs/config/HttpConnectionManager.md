
# Http Connection Manager Configuration

| Property | `HttpConnectionManager` *`(object)`* |
 | --- | --- |
| **additionalProperties** | `false` |
| **properties** | [`common-http-protocol-options`](#additional-settings-for-http-requests-handled-by-the-connection-manager-these-will-be-applicable-to-both-http1-and-http2-requests), [`server-header-transformation`](#server-header-transformation), [`server-name`](#server-name) |

The `http-connection-manager` object configures the Envoy HttpConnectionManager used to serve this API. ProxyConf automatically configures a filter chain per VHost/Listener, enabling that specific http connection manager configurations can exist per filter chain.


## Additional settings for HTTP requests handled by the connection manager. These will be applicable to both HTTP1 and HTTP2 requests.

| Property | `common-http-protocol-options` *`(object)`* |
 | --- | --- |
| **additionalProperties** | `false` |
| **properties** | [`headers-with-underscores-action`](#headers-with-underscores-action), [`idle-timeout`](#duration), [`max-connection-duration`](#duration), [`max-headers-count`](#uint-32-value), [`max-requests-per-connection`](#uint-32-value), [`max-response-headers-kb`](#uint-32-value), [`max-stream-duration`](#duration) |




### Headers_with_underscores_action

| Property | `headers-with-underscores-action` *`()`* |
 | --- | --- |
| **enum** | `DROP_HEADER`, `REJECT_REQUEST`, `ALLOW` |




### Duration

| Property | `idle-timeout` *`(object)`* |
 | --- | --- |
| **additionalProperties** | `false` |
| **properties** | [`seconds`](#uint-32-value) |




#### Uint_32_value

| Property | `seconds` *`(integer)`* |
 | --- | --- |
| **minimum** | `0` |




### Duration

| Property | `max-connection-duration` *`(object)`* |
 | --- | --- |
| **additionalProperties** | `false` |
| **properties** | [`seconds`](#uint-32-value) |




#### Uint_32_value

| Property | `seconds` *`(integer)`* |
 | --- | --- |
| **minimum** | `0` |




### Uint_32_value

| Property | `max-headers-count` *`(integer)`* |
 | --- | --- |
| **minimum** | `0` |




### Uint_32_value

| Property | `max-requests-per-connection` *`(integer)`* |
 | --- | --- |
| **minimum** | `0` |




### Uint_32_value

| Property | `max-response-headers-kb` *`(integer)`* |
 | --- | --- |
| **minimum** | `0` |




### Duration

| Property | `max-stream-duration` *`(object)`* |
 | --- | --- |
| **additionalProperties** | `false` |
| **properties** | [`seconds`](#uint-32-value) |




#### Uint_32_value

| Property | `seconds` *`(integer)`* |
 | --- | --- |
| **minimum** | `0` |




## Server_header_transformation

| Property | `server-header-transformation` *`()`* |
 | --- | --- |
| **enum** | `PASS_THROUGH`, `APPEND_IF_ABSENT`, `OVERWRITE` |




## Server_name

| Property | `server-name` *`(string)`* |
 | --- | --- |


