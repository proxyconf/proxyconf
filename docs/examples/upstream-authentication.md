# Upstream Authentication
## Inject Upstream Header


Inject Upstream Header. This is useful if e.g. a static api key must provided that is not available by the client. Upstream Authentication can be easily configured using the [Upstream Authentication](../config/UpstreamAuth.md) configuration.


```yaml title="OpenAPI Specification"
info:
  title: Inject Upstream Header
openapi: 3.0.3
paths:
  /test:
    get:
      responses:
        '200':
          description: OK
servers:
  - url: http://127.0.0.1:4040/echo
x-proxyconf:
  security:
    auth:
      downstream: disabled
      upstream:
        name: upstream-api-key
        overwrite: false
        type: header
        value: upstream-secret
  url: http://localhost:8080/inject-upstream-header

```

<h3><a href="https://hurl.dev" target="_blank">HURL</a> Examples</h3>
<div class="hurl"><pre><code class="language-hurl"><span class="hurl-entry"><span class="request"><span class="line"><span class="method">POST</span> <span class="url">http://localhost:4040/upload/inject-upstream-header.yaml</span></span>
<span class="line">file,<span class="filename">inject-upstream-header.yaml</span>;</span>
</span><span class="response"><span class="line"><span class="version">HTTP</span> <span class="number">200</span></span>
</span></span><span class="hurl-entry"><span class="request"><span class="line"></span>
<span class="line"></span>
<span class="line"></span><span class="comment"># If the client does not provides the header, it is set</span>
<span class="line"><span class="method">GET</span> <span class="url">http://localhost:8080/inject-upstream-header/test</span></span>
</span><span class="response"><span class="line"><span class="version">HTTP</span> <span class="number">200</span></span>
<span class="line"><span class="string">Content-Type</span>: <span class="string">application/json</span></span>
<span class="line"><span class="section-header">[Asserts]</span></span>
<span class="line"><span class="query-type">jsonpath</span> <span class="string">"$.headers.upstream-api-key"</span> <span class="predicate-type">==</span> <span class="string">"upstream-secret"</span></span>
</span></span><span class="hurl-entry"><span class="request"><span class="line"></span>
<span class="line"></span>
<span class="line"></span><span class="comment"># If the client provides the header, it is passed through</span>
<span class="line"><span class="method">GET</span> <span class="url">http://localhost:8080/inject-upstream-header/test</span></span>
<span class="line"><span class="string">upstream-api-key</span>: <span class="string">override-upstream-secret</span></span>
</span><span class="response"><span class="line"><span class="version">HTTP</span> <span class="number">200</span></span>
<span class="line"><span class="string">Content-Type</span>: <span class="string">application/json</span></span>
<span class="line"><span class="section-header">[Asserts]</span></span>
<span class="line"><span class="query-type">jsonpath</span> <span class="string">"$.headers.upstream-api-key"</span> <span class="predicate-type">==</span> <span class="string">"override-upstream-secret"</span></span>
</span></span></code></pre>
</div>
