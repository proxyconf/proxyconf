POST https://localhost:{{port}}/api/upload/basic-auth?api-port={{port}}&envoy-cluster={{envoy-cluster}}
Content-Type: application/yaml
Authorization: Bearer {{admin-access-token}}
file,basic-auth.yaml;
HTTP 200

# no basic auth credentials provided
GET http://localhost:8080/basic-auth/test
HTTP 403
[Asserts]
body contains "RBAC: access denied"

GET http://localhost:8080/basic-auth/test
[BasicAuth]
myuser: mysecret
HTTP 200

GET http://localhost:8080/basic-auth/test
[BasicAuth]
myuser: wrongsecret
HTTP 403
[Asserts]
body contains "RBAC: access denied"


GET http://localhost:8080/basic-auth/test
[BasicAuth]
wronguser: mysecret
HTTP 403
[Asserts]
body contains "RBAC: access denied"
