# Misc
## Downstream TLS


Downstream TLS is implicitely configured by providing a `https` URL in the `x-proxyconf.url` configuration. The server certificate used for the listener is selected by matching the `x-proxyconf.url` hostname with the TLS Common Name (CN) or TLS Subject Alternative Names (SAN) found in the TLS certificates available in [PROXYCONF_SERVER_DOWNSTREAM_TLS_PATH](../config/environment.md/#proxyconf_server_downstream_tls_path).


```yaml title="OpenAPI Specification: examples/downstream-tls.yaml"
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
  - url: http://127.0.0.1:4040/echo
x-proxyconf:
  listener:
    address: 127.0.0.1
    port: 8443
  security:
    auth:
      downstream: disabled
  url: https://localhost:8443/downstream-tls

```

<h3><a href="https://hurl.dev" target="_blank">HURL</a> Examples</h3>
<div class="hurl"><pre><code class="language-hurl"><span class="hurl-entry"><span class="request"><span class="line"><span class="method">POST</span> <span class="url">http://localhost:4040/upload/downstream-tls.yaml</span></span>
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
