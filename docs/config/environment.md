
# Environment Variables for Configuring ProxyConf

This section outlines the environment variables used to configure **ProxyConf**. These variables control various aspects such as directory locations, ports, and certificates for the control plane. Ensure to set these correctly based on your deployment needs.

## `PROXYCONF_CONFIG_DIRS`

Defines a comma-separated list of filesystem directories that **ProxyConf** monitors for OpenAPI specifications (in JSON or YAML format). This allows for dynamic loading and reloading of configurations as new API specs are added or updated.  
- **Default**: None (must be specified).

## `PROXYCONF_GRPC_ENDPOINT_PORT`

Specifies the TCP port on which the GRPC listener will accept connections from the Envoy proxies. This setting is crucial for the communication between ProxyConf and the Envoy proxies in your architecture.  
- **Default**: None (must be specified).

## `PROXYCONF_SERVER_DOWNSTREAM_TLS_PATH`

Specifies the directory path where **ProxyConf** will look for PEM-encoded TLS certificates and private keys for downstream services. This is essential for enabling HTTPS between Envoy and client requests. ProxyConf expects the following file naming convention:

- Certificate: `<domain>.crt` (e.g., `mysubdomain.example.com.crt`)  
- Private key: `<domain>.key` (e.g., `mysubdomain.example.com.key`)  

This setup allows ProxyConf to serve the correct TLS certificates based on the virtual host.

## `PROXYCONF_CA_CERTIFICATE`

!!! Warning
    ProxyConf will **automatically issue TLS certificates** if no matching certificate is available for an API. This feature is primarily for **testing purposes**. **Do not rely on these auto-issued certificates in production environments!**

Specifies the path to the PEM-encoded CA certificate used for issuing downstream TLS certificates. This CA will be used when ProxyConf cannot find a matching certificate/private key pair in `PROXYCONF_SERVER_DOWNSTREAM_TLS_PATH`.

- **Example**: `/path/to/ca-certificate.pem`

## `PROXYCONF_CA_PRIVATE_KEY`

Specifies the path to the PEM-encoded private key associated with the CA certificate, used to issue downstream TLS certificates.  
- **Example**: `/path/to/ca-private-key.pem`

## `PROXYCONF_CONTROL_PLANE_CERTIFICATE`

Defines the path to the PEM-encoded TLS certificate that the GRPC listener uses for securing communications with Envoy proxies.  
- **Example**: `/path/to/control-plane-certificate.pem`

## `PROXYCONF_CONTROL_PLANE_PRIVATE_KEY`

Specifies the path to the PEM-encoded private key for the above control plane certificate. This key is used by the GRPC listener to secure connections.  
- **Example**: `/path/to/control-plane-private-key.pem`

## `PROXYCONF_UPSTREAM_CA_BUNDLE`

The path to the TLS CA bundle that the Envoy proxies will use for validating upstream connections to API servers. This bundle ensures that ProxyConf can securely route traffic to upstream services.  
- **Default**: `/etc/ssl/certs/ca-certificates.crt`

## `PROXYCONF_CRONTAB`

Specifies the path to a crontab file used by ProxyConf to schedule and execute periodic tasks. These tasks could include fetching OpenAPI specifications from remote locations or syncing certificates from systems like Certbot.  
- **Example**: `/path/to/crontab`

---

By configuring these environment variables, you can tailor ProxyConf to your specific architecture and ensure secure, dynamic handling of API traffic and TLS certificates. Make sure to review and update the values based on your environment needs.
