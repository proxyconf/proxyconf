POST http://localhost:{{port}}/api/upload/api-key-in-query?api-port={{port}}&envoy-cluster={{envoy-cluster}}
Content-Type: application/yaml
Authorization: Bearer {{admin-access-token}}
file,api-key-in-query.yaml;
HTTP 200

# no api key provided
GET http://localhost:8080/api-key-in-query/test
HTTP 403
[Asserts]
body contains "RBAC: access denied"

GET http://localhost:8080/api-key-in-query/test?my-api-key=supersecret
HTTP 200

GET http://localhost:8080/api-key-in-query/test?my-api-key=wrongsecret
HTTP 403
[Asserts]
body contains "RBAC: access denied"
