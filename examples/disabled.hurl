# see routing-misc.hurl for more examples that use "disabled" auth
POST https://localhost:{{port}}/api/spec/disabled?api-port={{port}}&envoy-cluster={{envoy-cluster}}
Content-Type: application/yaml
Authorization: Bearer {{admin-access-token}}
file,disabled.yaml;
HTTP 200

GET http://localhost:8080/disabled/test
HTTP 200
