# OpenAPI Extension for ProxyConf

**Title:** OpenAPI Extension for ProxyConf

|                           |                                                                           |
| ------------------------- | ------------------------------------------------------------------------- |
| **Type**                  | `object`                                                                  |
| **Required**              | No                                                                        |
| **Additional properties** | [[Any type: allowed]](# "Additional Properties of any type are allowed.") |

| Property                       | Type   | Title/Description    |
| ------------------------------ | ------ | -------------------- |
| + [x-proxyconf](#x-proxyconf ) | object | ProxyConf API Config |

## <a name="x-proxyconf"></a>Property `x-proxyconf`

**Title:** ProxyConf API Config

|                           |                                                                           |
| ------------------------- | ------------------------------------------------------------------------- |
| **Type**                  | `object`                                                                  |
| **Required**              | Yes                                                                       |
| **Additional properties** | [[Any type: allowed]](# "Additional Properties of any type are allowed.") |

| Property                             | Type   | Title/Description      |
| ------------------------------------ | ------ | ---------------------- |
| - [api_id](#x-proxyconf_api_id )     | string | API Identifier         |
| - [cluster](#x-proxyconf_cluster )   | string | Cluster Identifier     |
| - [listener](#x-proxyconf_listener ) | object | Listener Configuration |
| - [routing](#x-proxyconf_routing )   | object | -                      |
| + [security](#x-proxyconf_security ) | object | Security Configuration |
| - [url](#x-proxyconf_url )           | string | API URL                |

### <a name="x-proxyconf_api_id"></a>Property `api_id`

**Title:** API Identifier

|              |                                                  |
| ------------ | ------------------------------------------------ |
| **Type**     | `string`                                         |
| **Required** | No                                               |
| **Default**  | `"The OpenAPI Spec filename is used as default"` |

| Restrictions   |   |
| -------------- | - |
| **Min length** | 1 |

### <a name="x-proxyconf_cluster"></a>Property `cluster`

**Title:** Cluster Identifier

|              |          |
| ------------ | -------- |
| **Type**     | `string` |
| **Required** | No       |

| Restrictions   |   |
| -------------- | - |
| **Min length** | 1 |

### <a name="x-proxyconf_listener"></a>Property `listener`

**Title:** Listener Configuration

|                           |                                                                           |
| ------------------------- | ------------------------------------------------------------------------- |
| **Type**                  | `object`                                                                  |
| **Required**              | No                                                                        |
| **Additional properties** | [[Any type: allowed]](# "Additional Properties of any type are allowed.") |

| Property                                    | Type        | Title/Description |
| ------------------------------------------- | ----------- | ----------------- |
| - [address](#x-proxyconf_listener_address ) | Combination | -                 |
| - [port](#x-proxyconf_listener_port )       | integer     | TCP Listener Port |

#### <a name="x-proxyconf_listener_address"></a>Property `address`

|                           |                                                                           |
| ------------------------- | ------------------------------------------------------------------------- |
| **Type**                  | `combining`                                                               |
| **Required**              | No                                                                        |
| **Additional properties** | [[Any type: allowed]](# "Additional Properties of any type are allowed.") |
| **Default**               | `"127.0.0.1"`                                                             |

| One of(Option)                                                      |
| ------------------------------------------------------------------- |
| [IPv4 TCP Listener Address](#x-proxyconf_listener_address_oneOf_i0) |
| [IPv6 TCP Listener Address](#x-proxyconf_listener_address_oneOf_i1) |

##### <a name="x-proxyconf_listener_address_oneOf_i0"></a>Property `IPv4 TCP Listener Address`

**Title:** IPv4 TCP Listener Address

|              |          |
| ------------ | -------- |
| **Type**     | `string` |
| **Required** | No       |
| **Format**   | `ipv4`   |

##### <a name="x-proxyconf_listener_address_oneOf_i1"></a>Property `IPv6 TCP Listener Address`

**Title:** IPv6 TCP Listener Address

|              |          |
| ------------ | -------- |
| **Type**     | `string` |
| **Required** | No       |
| **Format**   | `ipv6`   |

#### <a name="x-proxyconf_listener_port"></a>Property `port`

**Title:** TCP Listener Port

|              |           |
| ------------ | --------- |
| **Type**     | `integer` |
| **Required** | No        |
| **Default**  | `8080`    |

**Description:** The port is extracted from the `api_url` if it is explicitely provided as part of the url. E.g. the implicit ports 80/443 for http/https are replaced by the default `8080`.

| Restrictions |            |
| ------------ | ---------- |
| **Minimum**  | &ge; 1     |
| **Maximum**  | &le; 65535 |

### <a name="x-proxyconf_routing"></a>Property `routing`

|                           |                                                                           |
| ------------------------- | ------------------------------------------------------------------------- |
| **Type**                  | `object`                                                                  |
| **Required**              | No                                                                        |
| **Additional properties** | [[Any type: allowed]](# "Additional Properties of any type are allowed.") |

| Property                                                                                               | Type    | Title/Description |
| ------------------------------------------------------------------------------------------------------ | ------- | ----------------- |
| - [fail_fast_on_missing_header_parameter](#x-proxyconf_routing_fail_fast_on_missing_header_parameter ) | boolean | -                 |
| - [fail_fast_on_missing_query_parameter](#x-proxyconf_routing_fail_fast_on_missing_query_parameter )   | boolean | -                 |
| - [fail_fast_on_wrong_media_type](#x-proxyconf_routing_fail_fast_on_wrong_media_type )                 | boolean | -                 |
| - [fail_fast_on_wrong_request](#x-proxyconf_routing_fail_fast_on_wrong_request )                       | boolean | -                 |

#### <a name="x-proxyconf_routing_fail_fast_on_missing_header_parameter"></a>Property `fail_fast_on_missing_header_parameter`

|              |           |
| ------------ | --------- |
| **Type**     | `boolean` |
| **Required** | No        |

#### <a name="x-proxyconf_routing_fail_fast_on_missing_query_parameter"></a>Property `fail_fast_on_missing_query_parameter`

|              |           |
| ------------ | --------- |
| **Type**     | `boolean` |
| **Required** | No        |

#### <a name="x-proxyconf_routing_fail_fast_on_wrong_media_type"></a>Property `fail_fast_on_wrong_media_type`

|              |           |
| ------------ | --------- |
| **Type**     | `boolean` |
| **Required** | No        |

#### <a name="x-proxyconf_routing_fail_fast_on_wrong_request"></a>Property `fail_fast_on_wrong_request`

|              |           |
| ------------ | --------- |
| **Type**     | `boolean` |
| **Required** | No        |

### <a name="x-proxyconf_security"></a>Property `security`

**Title:** Security Configuration

|                           |                                                                           |
| ------------------------- | ------------------------------------------------------------------------- |
| **Type**                  | `object`                                                                  |
| **Required**              | Yes                                                                       |
| **Additional properties** | [[Any type: allowed]](# "Additional Properties of any type are allowed.") |

| Property                                                          | Type            | Title/Description                |
| ----------------------------------------------------------------- | --------------- | -------------------------------- |
| - [allowed_source_ips](#x-proxyconf_security_allowed_source_ips ) | array of string | Allowed Source IP Address Ranges |
| + [auth](#x-proxyconf_security_auth )                             | object          | Authentication                   |

#### <a name="x-proxyconf_security_allowed_source_ips"></a>Property `allowed_source_ips`

**Title:** Allowed Source IP Address Ranges

|              |                   |
| ------------ | ----------------- |
| **Type**     | `array of string` |
| **Required** | No                |
| **Default**  | `["127.0.0.1/8"]` |

| Each item of this array must be                                                     | Description |
| ----------------------------------------------------------------------------------- | ----------- |
| [IP Address Range in CIDR Notation](#x-proxyconf_security_allowed_source_ips_items) | -           |

##### <a name="autogenerated_heading_2"></a>IP Address Range in CIDR Notation

**Title:** IP Address Range in CIDR Notation

|              |          |
| ------------ | -------- |
| **Type**     | `string` |
| **Required** | No       |
| **Format**   | `cidr`   |

#### <a name="x-proxyconf_security_auth"></a>Property `auth`

**Title:** Authentication

|                           |                                                                           |
| ------------------------- | ------------------------------------------------------------------------- |
| **Type**                  | `object`                                                                  |
| **Required**              | Yes                                                                       |
| **Additional properties** | [[Any type: allowed]](# "Additional Properties of any type are allowed.") |

| Property                                               | Type        | Title/Description         |
| ------------------------------------------------------ | ----------- | ------------------------- |
| + [downstream](#x-proxyconf_security_auth_downstream ) | Combination | Downstream Authentication |
| - [upstream](#x-proxyconf_security_auth_upstream )     | object      | Upstream Authentication   |

##### <a name="x-proxyconf_security_auth_downstream"></a>Property `downstream`

**Title:** Downstream Authentication

|                           |                                                                           |
| ------------------------- | ------------------------------------------------------------------------- |
| **Type**                  | `combining`                                                               |
| **Required**              | Yes                                                                       |
| **Additional properties** | [[Any type: allowed]](# "Additional Properties of any type are allowed.") |

| One of(Option)                                                              |
| --------------------------------------------------------------------------- |
| [Disabled](#x-proxyconf_security_auth_downstream_oneOf_i0)                  |
| [Mutual TLS](#x-proxyconf_security_auth_downstream_oneOf_i1)                |
| [Basic Authentication](#x-proxyconf_security_auth_downstream_oneOf_i2)      |
| [Header or Query Parameter](#x-proxyconf_security_auth_downstream_oneOf_i3) |
| [JSON Web Tokens (JWT)](#x-proxyconf_security_auth_downstream_oneOf_i4)     |

###### <a name="x-proxyconf_security_auth_downstream_oneOf_i0"></a>Property `Disabled`

**Title:** Disabled

|              |         |
| ------------ | ------- |
| **Type**     | `const` |
| **Required** | No      |

**Description:** Disabling any downstream authentication. This potentially allows untrusted traffic. It's recommended to further limit exposure by narrowing the `allowed_source_ips` as much as possible

**Example:** 

```yaml
security:
  auth:
    downstream: disabled

```

Specific value: `"disabled"`

###### <a name="x-proxyconf_security_auth_downstream_oneOf_i1"></a>Property `Mutual TLS`

**Title:** Mutual TLS

|                           |                                                                           |
| ------------------------- | ------------------------------------------------------------------------- |
| **Type**                  | `object`                                                                  |
| **Required**              | No                                                                        |
| **Additional properties** | [[Any type: allowed]](# "Additional Properties of any type are allowed.") |

**Description:** Enabling mutual TLS for all clients that access this API. The `subject` or `SAN` in the provided client certificate is matched against the list provided in the `clients` property.

**Example:** 

```yaml
security:
  auth:
    downstream:
      clients:
        my_sample:
        - MY-SAMPLE-CLIENT-SUBJECT
      trusted_ca: path/to/my/trusted-ca.pem
      type: mtls

```

| Property                                                                   | Type   | Title/Description                  |
| -------------------------------------------------------------------------- | ------ | ---------------------------------- |
| + [clients](#x-proxyconf_security_auth_downstream_oneOf_i1_clients )       | object | Allowed Clients                    |
| + [trusted_ca](#x-proxyconf_security_auth_downstream_oneOf_i1_trusted_ca ) | string | Trusted Certificate Authority (CA) |
| + [type](#x-proxyconf_security_auth_downstream_oneOf_i1_type )             | const  | -                                  |

###### <a name="x-proxyconf_security_auth_downstream_oneOf_i1_clients"></a>Property `clients`

**Title:** Allowed Clients

|                           |                                                                                                                                                                 |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Type**                  | `object`                                                                                                                                                        |
| **Required**              | Yes                                                                                                                                                             |
| **Additional properties** | [[Should-conform]](#x-proxyconf_security_auth_downstream_oneOf_i1_clients_additionalProperties "Each additional property must conform to the following schema") |

**Description:** The clients are matches based on the client certificate subject or SAN

| Property                                                                           | Type            | Title/Description                                  |
| ---------------------------------------------------------------------------------- | --------------- | -------------------------------------------------- |
| - [](#x-proxyconf_security_auth_downstream_oneOf_i1_clients_additionalProperties ) | array of string | Certificate Subject / SubjectAlternativeName (SAN) |

###### <a name="x-proxyconf_security_auth_downstream_oneOf_i1_clients_additionalProperties"></a>Property `Certificate Subject / SubjectAlternativeName (SAN)`

**Title:** Certificate Subject / SubjectAlternativeName (SAN)

|              |                   |
| ------------ | ----------------- |
| **Type**     | `array of string` |
| **Required** | No                |

| Each item of this array must be                                                                                 | Description |
| --------------------------------------------------------------------------------------------------------------- | ----------- |
| [additionalProperties items](#x-proxyconf_security_auth_downstream_oneOf_i1_clients_additionalProperties_items) | -           |

###### <a name="autogenerated_heading_3"></a>additionalProperties items

|              |          |
| ------------ | -------- |
| **Type**     | `string` |
| **Required** | No       |

| Restrictions   |   |
| -------------- | - |
| **Min length** | 1 |

###### <a name="x-proxyconf_security_auth_downstream_oneOf_i1_trusted_ca"></a>Property `trusted_ca`

**Title:** Trusted Certificate Authority (CA)

|              |          |
| ------------ | -------- |
| **Type**     | `string` |
| **Required** | Yes      |

| Restrictions   |   |
| -------------- | - |
| **Min length** | 1 |

###### <a name="x-proxyconf_security_auth_downstream_oneOf_i1_type"></a>Property `type`

|              |         |
| ------------ | ------- |
| **Type**     | `const` |
| **Required** | Yes     |

Specific value: `"mtls"`

###### <a name="x-proxyconf_security_auth_downstream_oneOf_i2"></a>Property `Basic Authentication`

**Title:** Basic Authentication

|                           |                                                                           |
| ------------------------- | ------------------------------------------------------------------------- |
| **Type**                  | `object`                                                                  |
| **Required**              | No                                                                        |
| **Additional properties** | [[Any type: allowed]](# "Additional Properties of any type are allowed.") |

| Property                                                             | Type   | Title/Description |
| -------------------------------------------------------------------- | ------ | ----------------- |
| + [clients](#x-proxyconf_security_auth_downstream_oneOf_i2_clients ) | object | -                 |
| + [type](#x-proxyconf_security_auth_downstream_oneOf_i2_type )       | const  | -                 |

###### <a name="x-proxyconf_security_auth_downstream_oneOf_i2_clients"></a>Property `clients`

|                           |                                                                                                                                                                 |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Type**                  | `object`                                                                                                                                                        |
| **Required**              | Yes                                                                                                                                                             |
| **Additional properties** | [[Should-conform]](#x-proxyconf_security_auth_downstream_oneOf_i2_clients_additionalProperties "Each additional property must conform to the following schema") |

| Property                                                                           | Type            | Title/Description |
| ---------------------------------------------------------------------------------- | --------------- | ----------------- |
| - [](#x-proxyconf_security_auth_downstream_oneOf_i2_clients_additionalProperties ) | array of string | -                 |

###### <a name="x-proxyconf_security_auth_downstream_oneOf_i2_clients_additionalProperties"></a>Property `additionalProperties`

|              |                   |
| ------------ | ----------------- |
| **Type**     | `array of string` |
| **Required** | No                |

| Each item of this array must be                                                                                 | Description |
| --------------------------------------------------------------------------------------------------------------- | ----------- |
| [additionalProperties items](#x-proxyconf_security_auth_downstream_oneOf_i2_clients_additionalProperties_items) | -           |

###### <a name="autogenerated_heading_4"></a>additionalProperties items

|              |          |
| ------------ | -------- |
| **Type**     | `string` |
| **Required** | No       |

| Restrictions   |   |
| -------------- | - |
| **Min length** | 1 |

###### <a name="x-proxyconf_security_auth_downstream_oneOf_i2_type"></a>Property `type`

|              |         |
| ------------ | ------- |
| **Type**     | `const` |
| **Required** | Yes     |

Specific value: `"basic"`

###### <a name="x-proxyconf_security_auth_downstream_oneOf_i3"></a>Property `Header or Query Parameter`

**Title:** Header or Query Parameter

|                           |                                                                           |
| ------------------------- | ------------------------------------------------------------------------- |
| **Type**                  | `object`                                                                  |
| **Required**              | No                                                                        |
| **Additional properties** | [[Any type: allowed]](# "Additional Properties of any type are allowed.") |

| Property                                                             | Type             | Title/Description |
| -------------------------------------------------------------------- | ---------------- | ----------------- |
| + [clients](#x-proxyconf_security_auth_downstream_oneOf_i3_clients ) | object           | -                 |
| + [name](#x-proxyconf_security_auth_downstream_oneOf_i3_name )       | string           | -                 |
| + [type](#x-proxyconf_security_auth_downstream_oneOf_i3_type )       | enum (of string) | -                 |

###### <a name="x-proxyconf_security_auth_downstream_oneOf_i3_clients"></a>Property `clients`

|                           |                                                                                                                                                                 |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Type**                  | `object`                                                                                                                                                        |
| **Required**              | Yes                                                                                                                                                             |
| **Additional properties** | [[Should-conform]](#x-proxyconf_security_auth_downstream_oneOf_i3_clients_additionalProperties "Each additional property must conform to the following schema") |

| Property                                                                           | Type            | Title/Description |
| ---------------------------------------------------------------------------------- | --------------- | ----------------- |
| - [](#x-proxyconf_security_auth_downstream_oneOf_i3_clients_additionalProperties ) | array of string | -                 |

###### <a name="x-proxyconf_security_auth_downstream_oneOf_i3_clients_additionalProperties"></a>Property `additionalProperties`

|              |                   |
| ------------ | ----------------- |
| **Type**     | `array of string` |
| **Required** | No                |

| Each item of this array must be                                                                                 | Description |
| --------------------------------------------------------------------------------------------------------------- | ----------- |
| [additionalProperties items](#x-proxyconf_security_auth_downstream_oneOf_i3_clients_additionalProperties_items) | -           |

###### <a name="autogenerated_heading_5"></a>additionalProperties items

|              |          |
| ------------ | -------- |
| **Type**     | `string` |
| **Required** | No       |

| Restrictions   |   |
| -------------- | - |
| **Min length** | 1 |

###### <a name="x-proxyconf_security_auth_downstream_oneOf_i3_name"></a>Property `name`

|              |          |
| ------------ | -------- |
| **Type**     | `string` |
| **Required** | Yes      |

| Restrictions   |   |
| -------------- | - |
| **Min length** | 1 |

###### <a name="x-proxyconf_security_auth_downstream_oneOf_i3_type"></a>Property `type`

|              |                    |
| ------------ | ------------------ |
| **Type**     | `enum (of string)` |
| **Required** | Yes                |

Must be one of:
* "header"
* "query"

###### <a name="x-proxyconf_security_auth_downstream_oneOf_i4"></a>Property `JSON Web Tokens (JWT)`

**Title:** JSON Web Tokens (JWT)

|                           |                                                                           |
| ------------------------- | ------------------------------------------------------------------------- |
| **Type**                  | `object`                                                                  |
| **Required**              | No                                                                        |
| **Additional properties** | [[Any type: allowed]](# "Additional Properties of any type are allowed.") |

| Property                                                                             | Type   | Title/Description |
| ------------------------------------------------------------------------------------ | ------ | ----------------- |
| + [provider_config](#x-proxyconf_security_auth_downstream_oneOf_i4_provider_config ) | object | -                 |
| + [type](#x-proxyconf_security_auth_downstream_oneOf_i4_type )                       | const  | -                 |

###### <a name="x-proxyconf_security_auth_downstream_oneOf_i4_provider_config"></a>Property `provider_config`

|                           |                                                                           |
| ------------------------- | ------------------------------------------------------------------------- |
| **Type**                  | `object`                                                                  |
| **Required**              | Yes                                                                       |
| **Additional properties** | [[Any type: allowed]](# "Additional Properties of any type are allowed.") |

###### <a name="x-proxyconf_security_auth_downstream_oneOf_i4_type"></a>Property `type`

|              |         |
| ------------ | ------- |
| **Type**     | `const` |
| **Required** | Yes     |

Specific value: `"jwt"`

##### <a name="x-proxyconf_security_auth_upstream"></a>Property `upstream`

**Title:** Upstream Authentication

|                           |                                                                           |
| ------------------------- | ------------------------------------------------------------------------- |
| **Type**                  | `object`                                                                  |
| **Required**              | No                                                                        |
| **Additional properties** | [[Any type: allowed]](# "Additional Properties of any type are allowed.") |

| Property                                                      | Type    | Title/Description |
| ------------------------------------------------------------- | ------- | ----------------- |
| + [name](#x-proxyconf_security_auth_upstream_name )           | string  | -                 |
| - [overwrite](#x-proxyconf_security_auth_upstream_overwrite ) | boolean | -                 |
| + [type](#x-proxyconf_security_auth_upstream_type )           | const   | -                 |
| + [value](#x-proxyconf_security_auth_upstream_value )         | string  | -                 |

###### <a name="x-proxyconf_security_auth_upstream_name"></a>Property `name`

|              |          |
| ------------ | -------- |
| **Type**     | `string` |
| **Required** | Yes      |

| Restrictions   |   |
| -------------- | - |
| **Min length** | 1 |

###### <a name="x-proxyconf_security_auth_upstream_overwrite"></a>Property `overwrite`

|              |           |
| ------------ | --------- |
| **Type**     | `boolean` |
| **Required** | No        |

###### <a name="x-proxyconf_security_auth_upstream_type"></a>Property `type`

|              |         |
| ------------ | ------- |
| **Type**     | `const` |
| **Required** | Yes     |

Specific value: `"header"`

###### <a name="x-proxyconf_security_auth_upstream_value"></a>Property `value`

|              |          |
| ------------ | -------- |
| **Type**     | `string` |
| **Required** | Yes      |

| Restrictions   |   |
| -------------- | - |
| **Min length** | 1 |

### <a name="x-proxyconf_url"></a>Property `url`

**Title:** API URL

|              |          |
| ------------ | -------- |
| **Type**     | `string` |
| **Required** | No       |
| **Format**   | `uri`    |

----------------------------------------------------------------------------------------------------------------------------
