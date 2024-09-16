# ProxyConf

**ProxyConf** is a control plane for [Envoyproxy](https://www.envoyproxy.io/) that simplifies and secures API management in enterprise environments. It leverages the OpenAPI specification to streamline the configuration of Envoyproxy, providing a powerful yet user-friendly platform for managing, monitoring, and securing API traffic at scale.

> [!WARNING]
> ProxyConf is **currently in development** and under active construction ⚠️. While it may already be **usable for some cases**, there’s a good chance you’ll encounter **bugs or incomplete features**.
>
> However, your feedback is incredibly valuable to us! 🚀 If you're feeling adventurous, we’d love for you to try it out and let us know what works, what doesn’t, and where we can improve. Together, we can make ProxyConf even better!


## Key Features

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
| Vulnerability scanning                              |                                                      | Golang Envoy Plugin                   |                 | ?               | no       |
| Request body validation XML                         | XML schema                                           | Golang Envoy Plugin                   |                 | x               | no       |
| Response body validation XML                        | JSON schema                                          | Golang Envoy Plugin                   |                 | x               | no       |
| SOAP & WSDL based configuration                     |                                                      |                                       |                 | ?               | no       |

## Demo Setup

To quickly explore the capabilities of **ProxyConf**, we provide a demo environment that can be easily launched using Docker Compose. The demo setup, located inside the `demo` folder, includes all the necessary components to run a local instance of Envoyproxy with ProxyConf, configured to proxy traffic to a local instance of the **Swagger Petstore** API.

### Steps to Run the Demo:
1. **Generate TLS Certificates**: Before starting the demo, you need to generate the required TLS certificates by running the `setup-certificates.sh` script located in the `demo` folder:
   ```bash
   ./setup-certificates.sh
   ```
2. **Start the Demo Environment**: Once the certificates are generated, you can bring up the environment with Docker Compose:
   ```bash
   docker-compose up
   ```
3. **Explore the Setup**: The demo environment sets up **ProxyConf** to manage and secure Envoyproxy, which acts as a gateway proxying traffic to a local instance of the **Swagger Petstore**. The Swagger Petstore is a sample API, allowing you to test ProxyConf’s routing, security, and traffic management features in a real-world scenario.

### Key Components:
- **Envoyproxy**: Handles traffic routing and load balancing.
- **ProxyConf**: Configures Envoyproxy using OpenAPI specs, providing centralized policy management and enhanced security features.
- **Swagger Petstore**: A demo API specified in `demo/proxyconf/oas3specs/petstore.yaml` that Envoy proxies traffic to, allowing you to experiment with API management features such as routing, TLS termination, and request validation.

This demo provides a hands-on way to see how **ProxyConf** simplifies the configuration and management of Envoyproxy.

## Contributing

We welcome contributions! Please see our CONTRIBUTING.md for details on how to get started with development and submit pull requests.

## License

ProxyConf is licensed under the Mozilla Public License (MPL).

## 📬 Contact & Support

If you have any questions about features, want to report bugs, or request new functionality, please open a [GitHub Issue](https://github.com/proxyconf/proxyconf/issues). We actively monitor and respond to issues to help improve ProxyConf.

For **security concerns**, **business inquiries**, or **consulting requests**, feel free to reach out via email at [proxyconf@pm.me](mailto:proxyconf@pm.me).

---

ProxyConf helps you take control of your API operations, providing the tools needed to secure, optimize, and scale your API infrastructure efficiently. With optional paid extensions for request/response validation and SOAP/WSDL support, ProxyConf can meet the needs of both modern and legacy systems.
