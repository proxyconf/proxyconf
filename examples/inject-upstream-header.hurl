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
jsonpath "$.headers.upstream-api-key" == "upstream-secret"


# If the client provides the header, it is passed through
GET http://localhost:8080/inject-upstream-header/test
upstream-api-key: override-upstream-secret
HTTP 200
Content-Type: application/json
[Asserts]
jsonpath "$.headers.upstream-api-key" == "override-upstream-secret"
