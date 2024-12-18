# Downstream Authentication
## API Key in Query Parameter


Authentication using an API key query parameter can be easily configured using the [Authentication with Header or Query Parameter or Header](../config/DownstreamAuth.md/#header-or-query-parameter) configuration.


```yaml title="OpenAPI Specification"
info:
  title: API Key in Query Parameter
openapi: 3.0.3
paths:
  /test:
    get:
      parameters:
        - in: query
          name: my-api-key
          schema:
            type: string
      responses:
        '200':
          description: OK
servers:
  - url: https://127.0.0.1:/api/echo
x-proxyconf:
  cluster: demo
  security:
    auth:
      downstream:
        clients:
          testUser:
            - 9a618248b64db62d15b300a07b00580b
        name: my-api-key
        type: query
  url: http://localhost:8080/api-key-in-query

```

<h3><a href="https://hurl.dev" target="_blank">HURL</a> Examples</h3>
<div class="hurl"><pre><code class="language-hurl"><span class="hurl-entry"><span class="request"><span class="line"><span class="method">POST</span> <span class="url">https://localhost:{{port}}/api/spec/api-key-in-query?api-port={{port}}&amp;envoy-cluster={{envoy-cluster}}</span></span>
<span class="line"><span class="string">Content-Type</span>: <span class="string">application/yaml</span></span>
<span class="line"><span class="string">Authorization</span>: <span class="string">Bearer {{admin-access-token}}</span></span>
<span class="line">file,<span class="filename">api-key-in-query.yaml</span>;</span>
</span><span class="response"><span class="line"><span class="version">HTTP</span> <span class="number">200</span></span>
</span></span><span class="hurl-entry"><span class="request"><span class="line"></span>
<span class="line"></span><span class="comment"># no api key provided</span>
<span class="line"><span class="method">GET</span> <span class="url">http://localhost:8080/api-key-in-query/test</span></span>
</span><span class="response"><span class="line"><span class="version">HTTP</span> <span class="number">403</span></span>
<span class="line"><span class="section-header">[Asserts]</span></span>
<span class="line"><span class="query-type">body</span> <span class="predicate-type">contains</span> <span class="string">"RBAC: access denied"</span></span>
</span></span><span class="hurl-entry"><span class="request"><span class="line"></span>
<span class="line"><span class="method">GET</span> <span class="url">http://localhost:8080/api-key-in-query/test?my-api-key=supersecret</span></span>
</span><span class="response"><span class="line"><span class="version">HTTP</span> <span class="number">200</span></span>
</span></span><span class="hurl-entry"><span class="request"><span class="line"></span>
<span class="line"><span class="method">GET</span> <span class="url">http://localhost:8080/api-key-in-query/test?my-api-key=wrongsecret</span></span>
</span><span class="response"><span class="line"><span class="version">HTTP</span> <span class="number">403</span></span>
<span class="line"><span class="section-header">[Asserts]</span></span>
<span class="line"><span class="query-type">body</span> <span class="predicate-type">contains</span> <span class="string">"RBAC: access denied"</span></span>
</span></span></code></pre>
</div>

## API Key in Request Header


Authentication using an API key request header can be easily configured using the [Authentication with Header or Query Parameter or Header](../config/DownstreamAuth.md/#header-or-query-parameter) configuration.


```yaml title="OpenAPI Specification"
info:
  title: API Key in Request Header
openapi: 3.0.3
paths:
  /test:
    get:
      parameters:
        - in: header
          name: my-api-key
          schema:
            type: string
      responses:
        '200':
          description: OK
servers:
  - url: https://127.0.0.1:/api/echo
x-proxyconf:
  cluster: demo
  security:
    auth:
      downstream:
        clients:
          testUser:
            - 9a618248b64db62d15b300a07b00580b
        name: my-api-key
        type: header
  url: http://localhost:8080/api-key

```

<h3><a href="https://hurl.dev" target="_blank">HURL</a> Examples</h3>
<div class="hurl"><pre><code class="language-hurl"><span class="hurl-entry"><span class="request"><span class="line"><span class="method">POST</span> <span class="url">https://localhost:{{port}}/api/spec/api-key?api-port={{port}}&amp;envoy-cluster={{envoy-cluster}}</span></span>
<span class="line"><span class="string">Content-Type</span>: <span class="string">application/yaml</span></span>
<span class="line"><span class="string">Authorization</span>: <span class="string">Bearer {{admin-access-token}}</span></span>
<span class="line">file,<span class="filename">api-key.yaml</span>;</span>
</span><span class="response"><span class="line"><span class="version">HTTP</span> <span class="number">200</span></span>
</span></span><span class="hurl-entry"><span class="request"><span class="line"></span>
<span class="line"></span><span class="comment"># no api key provided</span>
<span class="line"><span class="method">GET</span> <span class="url">http://localhost:8080/api-key/test</span></span>
</span><span class="response"><span class="line"><span class="version">HTTP</span> <span class="number">403</span></span>
<span class="line"><span class="section-header">[Asserts]</span></span>
<span class="line"><span class="query-type">body</span> <span class="predicate-type">contains</span> <span class="string">"RBAC: access denied"</span></span>
</span></span><span class="hurl-entry"><span class="request"><span class="line"></span>
<span class="line"><span class="method">GET</span> <span class="url">http://localhost:8080/api-key/test</span></span>
<span class="line"><span class="string">my-api-key</span>: <span class="string">supersecret</span></span>
</span><span class="response"><span class="line"><span class="version">HTTP</span> <span class="number">200</span></span>
</span></span><span class="hurl-entry"><span class="request"><span class="line"></span>
<span class="line"><span class="method">GET</span> <span class="url">http://localhost:8080/api-key/test</span></span>
<span class="line"><span class="string">my-api-key</span>: <span class="string">wrongsecret</span></span>
</span><span class="response"><span class="line"><span class="version">HTTP</span> <span class="number">403</span></span>
<span class="line"><span class="section-header">[Asserts]</span></span>
<span class="line"><span class="query-type">body</span> <span class="predicate-type">contains</span> <span class="string">"RBAC: access denied"</span></span>
</span></span></code></pre>
</div>

## Basic Authentication


Authentication using HTTP Basic Authentication can be easily configured using the [Basic Authentication](../config/DownstreamAuth.md/#basic-authentication) configuration.


```yaml title="OpenAPI Specification"
info:
  title: Basic Authentication
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
  security:
    auth:
      downstream:
        clients:
          myUser:
            - 25be91d02dbbf17aff80e21323cd0dc5
        type: basic
  url: http://localhost:8080/basic-auth

```

<h3><a href="https://hurl.dev" target="_blank">HURL</a> Examples</h3>
<div class="hurl"><pre><code class="language-hurl"><span class="hurl-entry"><span class="request"><span class="line"><span class="method">POST</span> <span class="url">https://localhost:{{port}}/api/spec/basic-auth?api-port={{port}}&amp;envoy-cluster={{envoy-cluster}}</span></span>
<span class="line"><span class="string">Content-Type</span>: <span class="string">application/yaml</span></span>
<span class="line"><span class="string">Authorization</span>: <span class="string">Bearer {{admin-access-token}}</span></span>
<span class="line">file,<span class="filename">basic-auth.yaml</span>;</span>
</span><span class="response"><span class="line"><span class="version">HTTP</span> <span class="number">200</span></span>
</span></span><span class="hurl-entry"><span class="request"><span class="line"></span>
<span class="line"></span><span class="comment"># no basic auth credentials provided</span>
<span class="line"><span class="method">GET</span> <span class="url">http://localhost:8080/basic-auth/test</span></span>
</span><span class="response"><span class="line"><span class="version">HTTP</span> <span class="number">403</span></span>
<span class="line"><span class="section-header">[Asserts]</span></span>
<span class="line"><span class="query-type">body</span> <span class="predicate-type">contains</span> <span class="string">"RBAC: access denied"</span></span>
</span></span><span class="hurl-entry"><span class="request"><span class="line"></span>
<span class="line"><span class="method">GET</span> <span class="url">http://localhost:8080/basic-auth/test</span></span>
<span class="line"><span class="section-header">[BasicAuth]</span></span>
<span class="line"><span class="string">myuser</span>: <span class="string">mysecret</span></span>
</span><span class="response"><span class="line"><span class="version">HTTP</span> <span class="number">200</span></span>
</span></span><span class="hurl-entry"><span class="request"><span class="line"></span>
<span class="line"><span class="method">GET</span> <span class="url">http://localhost:8080/basic-auth/test</span></span>
<span class="line"><span class="section-header">[BasicAuth]</span></span>
<span class="line"><span class="string">myuser</span>: <span class="string">wrongsecret</span></span>
</span><span class="response"><span class="line"><span class="version">HTTP</span> <span class="number">403</span></span>
<span class="line"><span class="section-header">[Asserts]</span></span>
<span class="line"><span class="query-type">body</span> <span class="predicate-type">contains</span> <span class="string">"RBAC: access denied"</span></span>
</span></span><span class="hurl-entry"><span class="request"><span class="line"></span>
<span class="line"></span>
<span class="line"><span class="method">GET</span> <span class="url">http://localhost:8080/basic-auth/test</span></span>
<span class="line"><span class="section-header">[BasicAuth]</span></span>
<span class="line"><span class="string">wronguser</span>: <span class="string">mysecret</span></span>
</span><span class="response"><span class="line"><span class="version">HTTP</span> <span class="number">403</span></span>
<span class="line"><span class="section-header">[Asserts]</span></span>
<span class="line"><span class="query-type">body</span> <span class="predicate-type">contains</span> <span class="string">"RBAC: access denied"</span></span>
</span></span></code></pre>
</div>

## Disabled


Opting out of downstream authentication by setting the [Disabled Flag](../config/DownstreamAuth.md/#disabled).


```yaml title="OpenAPI Specification"
info:
  title: Disabled
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
  security:
    auth:
      downstream: disabled
  url: http://localhost:8080/disabled

```

<h3><a href="https://hurl.dev" target="_blank">HURL</a> Examples</h3>
<div class="hurl"><pre><code class="language-hurl"><span class="hurl-entry"><span class="request"><span class="line"></span><span class="comment"># see routing-misc.hurl for more examples that use "disabled" auth</span>
<span class="line"><span class="method">POST</span> <span class="url">https://localhost:{{port}}/api/spec/disabled?api-port={{port}}&amp;envoy-cluster={{envoy-cluster}}</span></span>
<span class="line"><span class="string">Content-Type</span>: <span class="string">application/yaml</span></span>
<span class="line"><span class="string">Authorization</span>: <span class="string">Bearer {{admin-access-token}}</span></span>
<span class="line">file,<span class="filename">disabled.yaml</span>;</span>
</span><span class="response"><span class="line"><span class="version">HTTP</span> <span class="number">200</span></span>
</span></span><span class="hurl-entry"><span class="request"><span class="line"></span>
<span class="line"><span class="method">GET</span> <span class="url">http://localhost:8080/disabled/test</span></span>
</span><span class="response"><span class="line"><span class="version">HTTP</span> <span class="number">200</span></span>
</span></span></code></pre>
</div>

## JSON Web Tokens (JWT)


Authentication using JWT can be easily configured using the [Authentication with JWT](../config/DownstreamAuth.md/#json-web-tokens-jwt) configuration.


```yaml title="OpenAPI Specification"
info:
  title: JSON Web Tokens (JWT)
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
  security:
    auth:
      downstream:
        provider-config:
          audiences:
            - demo
          issuer: proxyconf
          remote_jwks:
            cache_duration:
              seconds: 300
            http_uri:
              timeout: 1s
              uri: https://127.0.0.1:/api/jwks.json
        type: jwt
  url: http://localhost:8080/jwt

```

<h3><a href="https://hurl.dev" target="_blank">HURL</a> Examples</h3>
<div class="hurl"><pre><code class="language-hurl"><span class="hurl-entry"><span class="request"><span class="line"><span class="method">POST</span> <span class="url">https://localhost:{{port}}/api/spec/jwt?api-port={{port}}&amp;envoy-cluster={{envoy-cluster}}</span></span>
<span class="line"><span class="string">Content-Type</span>: <span class="string">application/yaml</span></span>
<span class="line"><span class="string">Authorization</span>: <span class="string">Bearer {{admin-access-token}}</span></span>
<span class="line">file,<span class="filename">jwt.yaml</span>;</span>
</span><span class="response"><span class="line"><span class="version">HTTP</span> <span class="number">200</span></span>
</span></span><span class="hurl-entry"><span class="request"><span class="line"></span>
<span class="line"></span><span class="comment"># no JWT is provided</span>
<span class="line"><span class="method">GET</span> <span class="url">http://localhost:8080/jwt/test</span></span>
</span><span class="response"><span class="line"><span class="version">HTTP</span> <span class="number">401</span></span>
<span class="line"><span class="section-header">[Asserts]</span></span>
<span class="line"><span class="query-type">body</span> <span class="predicate-type">contains</span> <span class="string">"Jwt is missing"</span></span>
</span></span><span class="hurl-entry"><span class="request"><span class="line"></span>
<span class="line"></span><span class="comment"># fetch invalid token (missing correct audience claim)</span>
<span class="line"><span class="method">POST</span> <span class="url">https://localhost:{{port}}/api/access-token</span></span>
<span class="line"><span class="section-header">[QueryStringParams]</span></span>
<span class="line"><span class="string">client_id</span>: <span class="string">{{oauth-client-id-other}}</span></span>
<span class="line"><span class="string">client_secret</span>: <span class="string">{{oauth-client-secret-other}}</span></span>
<span class="line"><span class="string">grant_type</span>: <span class="string">client_credentials</span></span>
</span><span class="response"><span class="line"><span class="version">HTTP</span> <span class="number">200</span></span>
<span class="line"><span class="section-header">[Captures]</span></span>
<span class="line"><span class="string">invalid_access_token</span>: <span class="query-type">jsonpath</span> <span class="string">"$['access_token']"</span></span>
</span></span><span class="hurl-entry"><span class="request"><span class="line"></span>
<span class="line"></span><span class="comment"># Invalid JWT is provided</span>
<span class="line"><span class="method">GET</span> <span class="url">http://localhost:8080/jwt/test</span></span>
<span class="line"><span class="string">Authorization</span>: <span class="string">Bearer {{invalid_access_token}}</span></span>
</span><span class="response"><span class="line"><span class="version">HTTP</span> <span class="number">403</span></span>
<span class="line"><span class="section-header">[Asserts]</span></span>
<span class="line"><span class="query-type">body</span> <span class="predicate-type">contains</span> <span class="string">"Audiences in Jwt are not allowed"</span></span>
</span></span><span class="hurl-entry"><span class="request"><span class="line"></span>
<span class="line"></span><span class="comment"># fetch valid token (including audience specified in downstream auth config)</span>
<span class="line"><span class="method">POST</span> <span class="url">https://localhost:{{port}}/api/access-token</span></span>
<span class="line"><span class="section-header">[QueryStringParams]</span></span>
<span class="line"><span class="string">client_id</span>: <span class="string">{{oauth-client-id}}</span></span>
<span class="line"><span class="string">client_secret</span>: <span class="string">{{oauth-client-secret}}</span></span>
<span class="line"><span class="string">grant_type</span>: <span class="string">client_credentials</span></span>
</span><span class="response"><span class="line"><span class="version">HTTP</span> <span class="number">200</span></span>
<span class="line"><span class="section-header">[Captures]</span></span>
<span class="line"><span class="string">valid_access_token</span>: <span class="query-type">jsonpath</span> <span class="string">"$['access_token']"</span></span>
</span></span><span class="hurl-entry"><span class="request"><span class="line"></span>
<span class="line"></span><span class="comment"># Valid JWT is provided</span>
<span class="line"><span class="method">GET</span> <span class="url">http://localhost:8080/jwt/test</span></span>
<span class="line"><span class="string">Authorization</span>: <span class="string">Bearer {{valid_access_token}}</span></span>
</span><span class="response"><span class="line"><span class="version">HTTP</span> <span class="number">200</span></span>
</span></span><span class="line"></span>
</code></pre>
</div>

## Mutual TLS (mTLS)


Authenticate using TLS client certificates (mTLS).


```yaml title="OpenAPI Specification"
info:
  title: Mutual TLS (mTLS)
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
  listener:
    address: 127.0.0.1
    port: 44444
  security:
    auth:
      downstream:
        clients:
          test_client:
            - CN=demo-client-a,OU=Snakeoil Client,O=ProxyConf,L=Basel,ST=Basel,C=CH
        trusted-ca: test/support/certs/snakeoil-ca.crt
        type: mtls
  url: https://localhost:44444/mtls

```

<h3><a href="https://hurl.dev" target="_blank">HURL</a> Examples</h3>
<div class="hurl"><pre><code class="language-hurl"><span class="hurl-entry"><span class="request"><span class="line"><span class="method">POST</span> <span class="url">https://localhost:{{port}}/api/spec/mtls?api-port={{port}}&amp;envoy-cluster={{envoy-cluster}}</span></span>
<span class="line"><span class="string">Content-Type</span>: <span class="string">application/yaml</span></span>
<span class="line"><span class="string">Authorization</span>: <span class="string">Bearer {{admin-access-token}}</span></span>
<span class="line">file,<span class="filename">mtls.yaml</span>;</span>
</span><span class="response"><span class="line"><span class="version">HTTP</span> <span class="number">200</span></span>
</span></span><span class="hurl-entry"><span class="request"><span class="line"></span>
<span class="line"></span><span class="comment"># HTTP Request with an invalid client certificate</span>
<span class="line"><span class="method">GET</span> <span class="url">https://localhost:44444/mtls/test</span></span>
<span class="line"><span class="section-header">[Options]</span></span>
<span class="line"><span class="string">cert</span>: <span class="filename">test/support/certs/snakeoil-client-b.crt</span></span>
<span class="line"><span class="string">key</span>: <span class="filename">test/support/certs/snakeoil-client-b.key</span></span>
</span><span class="response"><span class="line"><span class="version">HTTP</span> <span class="number">403</span></span>
<span class="line"><span class="section-header">[Asserts]</span></span>
<span class="line"><span class="query-type">body</span> <span class="predicate-type">contains</span> <span class="string">"RBAC: access denied"</span></span>
</span></span><span class="hurl-entry"><span class="request"><span class="line"></span>
<span class="line"></span><span class="comment"># HTTP Request with a valid client certificate</span>
<span class="line"><span class="method">GET</span> <span class="url">https://localhost:44444/mtls/test</span></span>
<span class="line"><span class="section-header">[Options]</span></span>
<span class="line"><span class="string">cert</span>: <span class="filename">test/support/certs/snakeoil-client-a.crt</span></span>
<span class="line"><span class="string">key</span>: <span class="filename">test/support/certs/snakeoil-client-a.key</span></span>
</span><span class="response"><span class="line"><span class="version">HTTP</span> <span class="number">200</span></span>
</span></span><span class="line"></span>
</code></pre>
</div>
