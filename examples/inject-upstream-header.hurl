# Set secret 'upstream-api-key' used to inject in the header
POST https://localhost:{{port}}/api/secret/upstream-api-key
Authorization: Bearer {{admin-access-token}}
```
MY-UPSTREAM-SECRET
```
HTTP 200


POST https://localhost:{{port}}/api/spec/inject-upstream-header?api-port={{port}}&envoy-cluster={{envoy-cluster}}
Content-Type: application/yaml
Authorization: Bearer {{admin-access-token}}
file,inject-upstream-header.yaml;
HTTP 200


# If the client does not provides the header, it is set
GET http://localhost:8080/inject-upstream-header/test
HTTP 200
Content-Type: application/json
[Asserts]
jsonpath "$.headers.upstream-api-key" == "MY-UPSTREAM-SECRET"


# If the client provides the header, it is passed through
GET http://localhost:8080/inject-upstream-header/test
upstream-api-key: override-upstream-secret
HTTP 200
Content-Type: application/json
[Asserts]
jsonpath "$.headers.upstream-api-key" == "override-upstream-secret"
