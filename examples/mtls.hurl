POST https://localhost:{{port}}/api/upload/mtls?api-port={{port}}&envoy-cluster={{envoy-cluster}}
Content-Type: application/yaml
Authorization: Bearer {{admin-access-token}}
file,mtls.yaml;
HTTP 200

# HTTP Request with an invalid client certificate
GET https://localhost:44444/mtls/test
[Options]
cert: test/support/certs/snakeoil-client-b.crt
key: test/support/certs/snakeoil-client-b.key
HTTP 403
[Asserts]
body contains "RBAC: access denied"

# HTTP Request with a valid client certificate
GET https://localhost:44444/mtls/test
[Options]
cert: test/support/certs/snakeoil-client-a.crt
key: test/support/certs/snakeoil-client-a.key
HTTP 200

