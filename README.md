# ProxyConf

**ProxyConf** is a control plane for [Envoyproxy](https://www.envoyproxy.io/) that simplifies and secures API management in enterprise environments. It leverages the OpenAPI specification to streamline the configuration of Envoyproxy, providing a powerful yet user-friendly platform for managing, monitoring, and securing API traffic at scale.

## Features

- **Envoyproxy Integration**
  - High-performance routing, load balancing, and traffic management.
  - Built-in observability with metrics, logging, and tracing.
  - Security features like TLS termination and rate limiting.

- **ProxyConf Control Plane**
  - **OpenAPI-Driven Configuration:** Simplifies and standardizes Envoyproxy configuration using OpenAPI specs.
  - **Centralized Policy Management:** Manage API security, routing, and traffic policies across multiple Envoy instances.
  - **Enhanced Security:** Adds layers like authentication, authorization, and custom rate limiting on top of Envoyproxy’s native features.
  - **Real-time Monitoring:** Unified dashboard with real-time insights into API health, performance, and security.
  - **Scalability:** Seamless scaling in distributed, high-availability environments.

- **Proprietary Extensions** (Available as Paid Add-ons)
  - **Request and Response Validation:** Advanced validation mechanisms for API requests and responses, ensuring data integrity and compliance with specifications.
  - **SOAP/WSDL Support:**  Support for SOAP-based APIs and WSDL specifications, enabling seamless integration with legacy systems.

### Feature Matrix

| **Feature**                                         | **OpenAPI Extension**                                | **Implementation**                    | **Open Source** | **Paid Add-On** | **DONE** |
|-----------------------------------------------------|------------------------------------------------------|---------------------------------------|-----------------|-----------------|----------|
| Downstream TLS                                      | x-proxyconf-api-url (automatic for https url)        | Envoy SDS                             | x               |                 | yes      |
| Downstream Static mTLS Authentication               | x-proxyconf-downstream-auth                          | Envoy TLS Inspector + RBAC Filter     | x               |                 | yes      |
| Downstream Static API Key Authentication            | x-proxyconf-downstream-auth                          | Custom Lua Filter + Envoy RBAC Filter | x               |                 | yes      |
| Downstream Static Basic Authentication              | x-proxyconf-downstream-auth                          | Custom Lua Filter + Envoy RBAC Filter | x               |                 | yes      |
| Downstream JWT based Authentication                 | x-proxyconf-downstream-auth                          | Envoy JWT Filter                      | x               |                 | yes      |
| Source IP filtering                                 | x-proxyconf-listener {allowed-source-ips}            | Envoy RBAC Filter                     | x               |                 | yes      |
| Multi-Cluster Support                               | x-proxyconf-cluster-id                               | Envoy cluster id mapping              | x               |                 | yes      |
| Multi-Listener Support                              | x-proxyconf-listener                                 | Envoy listener                        | x               |                 | yes      |
| Virtual Hosts Support                               | x-proxyconf-api-url (host is extracted from the url) | Envoy RDS                             | x               |                 | yes      |
| Routing based on HTTP Method & Path                 | n/a                                                  | Envoy RDS                             | x               |                 | yes      |
| Routing based on Path templates                     | n/a                                                  | Envoy RDS                             | x               |                 | yes      |
| Routing checks required request headers             | x-proxyconf-fail-fast-on-missing-header-parameter    | Envoy RDS                             | x               |                 | yes      |
| Routing checks required query parameters            | x-proxyconf-fail-fast-on-missing-query-parameter     | Envoy RDS                             | x               |                 | yes      |
| Routing checks required request content type header | x-proxyconf-fail-fast-on-wrong-media-type            | Envoy RDS                             | x               |                 | yes      |
| Upstream server load balancing                      | x-proxyconf-server-weight                            | Envoy weighted cluster                | x               |                 | yes      |
|                                                     |                                                      |                                       |                 |                 |          |
| Request header validation                           | JSON Schema                                          | Golang Envoy Plugin                   |                 | x               | yes      |
| Response header validation                          | JSON Schema                                          | Golang Envoy Plugin                   |                 | x               | yes      |
| Query parameter validation                          | JSON Schema                                          | Golang Envoy Plugin                   |                 | x               | yes      |
| Request body validation JSON / Form-Data            | JSON schema                                          | Golang Envoy Plugin                   |                 | x               | yes      |
| Response body validation JSON / Form-Data           | JSON schema                                          | Golang Envoy Plugin                   |                 | x               | yes      |
| Vulnerability scanning                              |                                                      | Golang Envoy Plugin                   |                 | x               | no       |

## Contributing

We welcome contributions! Please see our CONTRIBUTING.md for details on how to get started with development and submit pull requests.

## License

ProxyConf is licensed under the Apache2 License.

## Contact

For any questions or support, please reach out via GitHub Discussions or open an issue.

---

ProxyConf helps you take control of your API operations, providing the tools needed to secure, optimize, and scale your API infrastructure efficiently. With optional paid extensions for request/response validation and SOAP/WSDL support, ProxyConf can meet the needs of both modern and legacy systems.
