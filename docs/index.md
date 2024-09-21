# ProxyConf

![Image title](./assets/logo.svg){ align=left } 

**ProxyConf** is a control plane for [Envoyproxy](https://www.envoyproxy.io/) that simplifies and secures API management in enterprise environments. It leverages the OpenAPI specification to streamline the configuration of Envoyproxy, providing a powerful yet user-friendly platform for managing, and securing API traffic at scale.

<br />
<br />
!!! Warning
    
    ProxyConf is **currently in development** and under active construction ⚠️. While it may already be **usable for some cases**, there’s a good chance you’ll encounter **bugs or incomplete features**.
    
    However, your feedback is incredibly valuable to us! 🚀 If you're feeling adventurous, we’d love for you to try it out and let us know what works, what doesn’t, and where we can improve. Together, we can make ProxyConf even better!


## Key Features

- **Envoyproxy Integration**
    - High-performance routing, load balancing, and traffic management.
    - Built-in observability with metrics, logging, and tracing.
    - Security features like JWT authentication, TLS termination, and rate limiting.

- **ProxyConf Control Plane**
    - **OpenAPI-Driven Configuration:** Simplifies and standardizes Envoyproxy configuration using OpenAPI specs.
    - **Centralized Policy Management:** Manage API security, routing, and traffic policies across multiple Envoy instances.
    - **Scalability:** Seamless scaling in distributed, high-availability environments.

- **Proprietary Extensions** (Available as Paid Add-ons, work in progress)
    - **Request and Response Validation:** Advanced validation mechanisms for API requests and responses, ensuring data integrity and compliance with specifications.
  - **SOAP/WSDL Support:**  Support for SOAP-based APIs and WSDL specifications, enabling seamless integration with legacy systems.


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

We welcome contributions to ProxyConf! Whether it’s bug fixes, new features, or improvements to documentation, your help is appreciated.

### How to Contribute:
- **Fork** the repository.
- Create a new branch for your changes (e.g., `feature/your-feature`).
- **Commit** your changes with clear and descriptive messages.
- Open a **Pull Request** describing your changes and how they address the issue.

### Guidelines:
- Ensure that your changes are well-tested and maintain the existing functionality.
- Follow consistent code formatting and best practices used in the project.
- Be respectful and constructive in all interactions.

We’re excited to collaborate with the community to make ProxyConf better! Feel free to open an issue if you have questions or need guidance.

##  License

ProxyConf is licensed under the [Mozilla Public License 2.0](https://www.mozilla.org/en-US/MPL/2.0/). You are free to use, modify, and distribute the software under the terms of this license.

## Contact & Support

If you have any questions about features, want to report bugs, or request new functionality, please open a [GitHub Issue](https://github.com/proxyconf/proxyconf/issues). We actively monitor and respond to issues to help improve ProxyConf.

For **security concerns**, **business inquiries**, or **consulting requests**, feel free to reach out via email at [proxyconf@pm.me](mailto:proxyconf@pm.me).
