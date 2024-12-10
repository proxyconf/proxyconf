
# Environment Variables for Configuring ProxyConf

This section outlines the environment variables used to configure **ProxyConf**. These variables control various aspects such as database setup, ports, and certificates for the control plane. Ensure to set these correctly based on your deployment needs.

## `SECRET_KEY_BASE`

Defines a base secret that is used to sign/encrypt cookies and other secrets.
You can generate one by calling `openssl rand 32 | base32`
- **Default**: None (must be specified).

## `DB_ENCRYPTION_KEY`

Defines a secret key that is used to encrypt sensitive values stored in the database.
You can generate one by calling `openssl rand 32 | base32`
- **Default**: None (must be specified).

## `PROXYCONF_HOSTNAME`

Defines the hostname used to serve the mgmt endpoint / ui.
- **Default**: localhost.

## `RELEASE_COOKIE`

Defines the distributed erlang cookie, required to cluster multiple ProxyConf nodes. 
- **Default**: generated during build. Ensure to replace it for production usage.

## `PROXYCONF_DATABASE_URL`

Defines a database url used to connect to the database.
For example: ecto://USER:PASS@HOST/DATABASE
- **Default**: None (must be specified).

## `PROXYCONF_CA_CERTIFICATE`

Defines the path to the PEM encoded CA certificate.
- **Default**: None (must be specified).

## `PROXYCONF_CONTROL_PLANE_CERTIFICATE`

Defines the path to the PEM encoded certificate used by the GRPC endpoint accessed by the Envoy data plane.
- **Default**: None (must be specified).

## `PROXYCONF_CONTROL_PLANE_PRIVATE_KEY`

Defines the path to the PEM encoded private key used by the GRPC endpoint accessed by the Envoy data plane.
- **Default**: None (must be specified).

## `PROXYCONF_MGMT_API_CA_CERTIFICATE`

Defines the path to the PEM encoded CA certificate used by the HTTPS management API.
- **Default**: The certificate defined in `PROXYCONF_CA_CERTIFICATE`.

## `PROXYCONF_MGMT_API_CERTIFICATE`

Defines the path to the PEM encoded certificate used by the HTTPS management API.
- **Default**: The certificate defined in `PROXYCONF_CONTROL_PLANE_CERTIFICATE`.

## `PROXYCONF_MGMT_API_PRIVATE_KEY`

Defines the path to the PEM encoded private key used by the HTTPS management API.
- **Default**: The private key defined in `PROXYCONF_CONTROL_PLANE_PRIVATE_KEY`.

## `PROXYCONF_MGMT_API_JWT_SIGNER_KEY`

Defines the path to the PEM encoded private key used by the JWT signer.
- **Default**: The private key defined in `PROXYCONF_MGMT_API_PRIVATE_KEY`.

## `PROXYCONF_CERTIFICATE_ISSUER_CERT`

Defines the path to the PEM encoded certificate used to automatically issue server certificates if no matching cert is available.
- **Default**: None (must be specified).

## `PROXYCONF_CERTIFICATE_ISSUER_KEY`

Defines the path to the PEM encoded private key used to automatically issue server certificates if no matching cert is available.
- **Default**: None (must be specified).

## `PROXYCONF_UPSTREAM_CA_BUNDLE`

The path to the TLS CA bundle that the Envoy proxies will use for validating upstream connections to API servers. This bundle ensures that ProxyConf can securely route traffic to upstream services.  
- **Default**: `/etc/ssl/certs/ca-certificates.crt`

## `PROXYCONF_GRPC_ENDPOINT_PORT`

Specifies the TCP port on which the GRPC listener will accept connections from the Envoy proxies. This setting is crucial for the communication between ProxyConf and the Envoy proxies in your architecture.  
- **Default**: 18000.

## `PROXYCONF_CRONTAB`

Specifies the path to a crontab file used by ProxyConf to schedule and execute periodic tasks. These tasks could include fetching OpenAPI specifications from remote locations or syncing certificates from systems like Certbot.  
- **Example**: `/path/to/crontab`

---

By configuring these environment variables, you can tailor ProxyConf to your specific architecture and ensure secure, dynamic handling of API traffic and TLS certificates. Make sure to review and update the values based on your environment needs.
