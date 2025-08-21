# ProxyConf

![Image title](./assets/logow.png){ align=center } 

**ProxyConf** is a control plane for [Envoyproxy](https://www.envoyproxy.io/) that simplifies and secures API management in enterprise environments. It leverages the OpenAPI specification to streamline the configuration of Envoyproxy, providing a powerful yet user-friendly platform for managing, and securing API traffic at scale.


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

### Steps to Run the Demo

1. **Start the Demo Environment**  
   Bring up the environment with Docker Compose:

   ```bash
   cd demo

   docker-compose up --pull always
   ```

2. **Create OAuth Client Configuration**  
   Use the following command to create an OAuth client configuration, which is required to retrieve an access token for managing the cluster:

   ```bash
   curl -X POST https://localhost:4000/api/create-config/demo \
        --cacert ../control_plane/test/support/certs/snakeoil-ca.crt
   ```

   Example response:
   ```json
   {
       "client_id": "demo",
       "client_secret": "1Q1ea-txiDn8AQ39Vs69CLn3k9yFBy-eQOcTyw6pE5gQmZvr5wOMD0RpkZCKUunk"
   }
   ```

3. **Retrieve OAuth Access Token**  
   Use the generated OAuth client configuration to retrieve an access token:

   ```bash
   curl -X POST "https://localhost:4000/api/access-token?client_id=demo&client_secret=<YOUR_CLIENT_SECRET>&grant_type=client_credentials" \
        --cacert ../control_plane/test/support/certs/snakeoil-ca.crt
   ```

   Example response:
   ```json
   {
       "access_token": "ACCESS-TOKEN",
       "created_at": "2024-12-10T21:08:33",
       "expires_in": 7200,
       "refresh_token": null,
       "scope": "cluster-admin",
       "token_type": "bearer"
   }
   ```

4. **Upload the Petstore Specification**  
   Upload the OpenAPI specification of the Swagger Petstore to ProxyConf:

   ```bash
   curl -X POST https://localhost:4000/api/spec/petstore \
        -H "Authorization: Bearer <ACCESS-TOKEN>" \
        -H "Content-Type: application/yaml" \
        --data-binary "@demo/proxyconf/oas3specs/petstore.yaml" \
        --cacert ../control_plane/test/support/certs/snakeoil-ca.crt
   ```

   Response:
   ```text
   OK
   ```

5. **Explore the Setup**  
   The demo environment configures **ProxyConf** to manage and secure the **Swagger Petstore** API. The Petstore API is reachable at `https://localhost:8080/petstore`.

   You can test the setup with an example API key configured in the `petstore.yaml` OpenAPI specification:

   ```bash
   curl -X GET "https://localhost:8080/petstore/pet/findByStatus?status=pending" \
        -H "my-api-key: supersecret" \
        --cacert ../control_plane/test/support/certs/snakeoil-ca.crt
   ```

   Example response:
   ```json
   [
       {
           "id": 3,
           "category": { "id": 2, "name": "Cats" },
           "name": "Cat 3",
           "photoUrls": ["url1", "url2"],
           "tags": [
               { "id": 1, "name": "tag3" },
               { "id": 2, "name": "tag4" }
           ],
           "status": "pending"
       },
       {
           "id": 6,
           "category": { "id": 1, "name": "Dogs" },
           "name": "Dog 3",
           "photoUrls": ["url1", "url2"],
           "tags": [
               { "id": 1, "name": "tag3" },
               { "id": 2, "name": "tag4" }
           ],
           "status": "pending"
       }
   ]
   ```

### Key Components

- **Envoyproxy**: Handles traffic routing and load balancing.
- **ProxyConf**: Configures Envoyproxy using OpenAPI specs, providing centralized policy management and enhanced security features.
- **Swagger Petstore**: A demo API specified in `demo/proxyconf/oas3specs/petstore.yaml` that Envoy proxies traffic to, allowing you to experiment with API management features such as routing, TLS termination, and request validation.
- **Postgres Database**: The persistence layer for ProxyConf.

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
