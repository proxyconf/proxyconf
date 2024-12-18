# Misc
## Cross-Origin Resource Sharing


Configuring Cross-Origin Resource Sharing (CORS) for this API.


```yaml title="OpenAPI Specification"
info:
  title: Cross-Origin Resource Sharing
openapi: 3.0.3
paths:
  /test:
    get:
      responses:
        '200':
          description: OK
servers:
  - url: https://127.0.0.1:/api/echo
x-proxyconf:
  cluster: demo
  cors:
    access-control-allow-methods:
      - GET
      - POST
    access-control-allow-origins:
      - http://*.foo.com
    access-control-max-age: 600
  security:
    auth:
      downstream:
        clients:
          testUser:
            - 9a618248b64db62d15b300a07b00580b
        name: my-api-key
        type: header
  url: http://localhost:8080/cors

```

<h3><a href="https://hurl.dev" target="_blank">HURL</a> Examples</h3>
<div class="hurl"><pre><code class="language-hurl"><span class="hurl-entry"><span class="request"><span class="line"><span class="method">POST</span> <span class="url">https://localhost:{{port}}/api/spec/cors?api-port={{port}}&amp;envoy-cluster={{envoy-cluster}}</span></span>
<span class="line"><span class="string">Content-Type</span>: <span class="string">application/yaml</span></span>
<span class="line"><span class="string">Authorization</span>: <span class="string">Bearer {{admin-access-token}}</span></span>
<span class="line">file,<span class="filename">cors.yaml</span>;</span>
</span><span class="response"><span class="line"><span class="version">HTTP</span> <span class="number">200</span></span>
</span></span><span class="hurl-entry"><span class="request"><span class="line"></span>
<span class="line"></span><span class="comment"># CORS Preflight Requests are unauthenticated</span>
<span class="line"><span class="method">OPTIONS</span> <span class="url">http://localhost:8080/cors/test</span></span>
<span class="line"><span class="string">Origin</span>: <span class="string">http://cors.foo.com</span></span>
<span class="line"><span class="string">Access-Control-Request-Method</span>: <span class="string">Get</span></span>
</span><span class="response"><span class="line"><span class="version">HTTP</span> <span class="number">200</span></span>
<span class="line"><span class="string">Access-Control-Allow-Origin</span>: <span class="string">http://cors.foo.com</span></span>
<span class="line"><span class="string">Access-Control-Allow-Methods</span>: <span class="string">GET,POST</span></span>
<span class="line"><span class="string">Access-Control-Max-Age</span>: <span class="string">600</span></span>
<span class="line"><span class="section-header">[Asserts]</span></span>
<span class="line"><span class="query-type">bytes</span> <span class="filter-type">count</span> <span class="predicate-type">==</span> <span class="number">0</span></span>
</span></span><span class="hurl-entry"><span class="request"><span class="line"></span>
<span class="line"></span><span class="comment"># Accessing the actual resource must be authenticatied - negative test</span>
<span class="line"><span class="method">GET</span> <span class="url">http://localhost:8080/cors/test</span></span>
</span><span class="response"><span class="line"><span class="version">HTTP</span> <span class="number">403</span></span>
<span class="line"><span class="section-header">[Asserts]</span></span>
<span class="line"><span class="query-type">body</span> <span class="predicate-type">contains</span> <span class="string">"RBAC: access denied"</span></span>
</span></span><span class="hurl-entry"><span class="request"><span class="line"></span>
<span class="line"></span><span class="comment"># Accessing the actual resource must be authenticatied - positive test</span>
<span class="line"><span class="method">GET</span> <span class="url">http://localhost:8080/cors/test</span></span>
<span class="line"><span class="string">my-api-key</span>: <span class="string">supersecret</span></span>
</span><span class="response"><span class="line"><span class="version">HTTP</span> <span class="number">200</span></span>
</span></span></code></pre>
</div>

## Downstream TLS


Downstream TLS is implicitely configured by providing a `https` URL in the `x-proxyconf.url` configuration. The server certificate used for the listener is selected by matching the `x-proxyconf.url` hostname with the TLS Common Name (CN) or TLS Subject Alternative Names (SAN) found in the TLS certificates available in [PROXYCONF_SERVER_DOWNSTREAM_TLS_PATH](../config/environment.md/#proxyconf_server_downstream_tls_path).


```yaml title="OpenAPI Specification"
info:
  title: Downstream TLS
openapi: 3.0.3
paths:
  /test:
    get:
      responses:
        '200':
          content:
            application/json:
              example: '{"hello":"world"}'
              schema:
                type: object
          description: OK
    post:
      requestBody:
        content:
          application/json: {}
        required: true
      responses:
        '200':
          content:
            application/json: {}
          description: OK
servers:
  - url: https://127.0.0.1:/api/echo
x-proxyconf:
  cluster: demo
  listener:
    address: 127.0.0.1
    port: 8443
  security:
    auth:
      downstream: disabled
  url: https://localhost:8443/downstream-tls

```

<h3><a href="https://hurl.dev" target="_blank">HURL</a> Examples</h3>
<div class="hurl"><pre><code class="language-hurl"><span class="hurl-entry"><span class="request"><span class="line"><span class="method">POST</span> <span class="url">https://localhost:{{port}}/api/spec/downstream-tls?api-port={{port}}&amp;envoy-cluster={{envoy-cluster}}</span></span>
<span class="line"><span class="string">Content-Type</span>: <span class="string">application/yaml</span></span>
<span class="line"><span class="string">Authorization</span>: <span class="string">Bearer {{admin-access-token}}</span></span>
<span class="line">file,<span class="filename">downstream-tls.yaml</span>;</span>
</span><span class="response"><span class="line"><span class="version">HTTP</span> <span class="number">200</span></span>
</span></span><span class="hurl-entry"><span class="request"><span class="line"></span>
<span class="line"><span class="method">GET</span> <span class="url">https://localhost:8443/downstream-tls/test</span></span>
</span><span class="response"><span class="line"><span class="version">HTTP</span> <span class="number">200</span></span>
</span></span><span class="hurl-entry"><span class="request"><span class="line"></span>
<span class="line"></span><span class="comment"># We expect a not found as required request body is missing </span>
<span class="line"></span><span class="comment"># and thereore no route matches</span>
<span class="line"><span class="method">POST</span> <span class="url">https://localhost:8443/downstream-tls/test</span></span>
</span><span class="response"><span class="line"><span class="version">HTTP</span> <span class="number">404</span></span>
</span></span><span class="hurl-entry"><span class="request"><span class="line"></span>
<span class="line"></span><span class="comment"># Also a 404 for wrong path</span>
<span class="line"><span class="method">GET</span> <span class="url">https://localhost:8443/downstream-tls/test2</span></span>
</span><span class="response"><span class="line"><span class="version">HTTP</span> <span class="number">404</span></span>
</span></span><span class="hurl-entry"><span class="request"><span class="line"></span>
<span class="line"></span><span class="comment"># With valid content type </span>
<span class="line"><span class="method">POST</span> <span class="url">https://localhost:8443/downstream-tls/test</span></span>
<span class="line"><span class="string">Content-Type</span>: <span class="string">application/json</span></span>
<span class="json"><span class="line">{</span>
<span class="line">  "hello": "world"</span>
<span class="line">}</span></span>
</span><span class="response"><span class="line"><span class="version">HTTP</span> <span class="number">200</span></span>
</span></span><span class="hurl-entry"><span class="request"><span class="line"></span>
<span class="line"></span><span class="comment"># With invalid content type </span>
<span class="line"><span class="method">POST</span> <span class="url">https://localhost:8443/downstream-tls/test</span></span>
<span class="line"><span class="string">Content-Type</span>: <span class="string">text/plain</span></span>
<span class="json"><span class="line">"hello world"</span></span>
</span><span class="response"><span class="line"><span class="version">HTTP</span> <span class="number">404</span></span>
</span></span></code></pre>
</div>
