POST https://localhost:{{port}}/api/spec/complex-header-auth?api-port={{port}}&envoy-cluster={{envoy-cluster}}
Content-Type: application/yaml
Authorization: Bearer {{admin-access-token}}
file,complex-header-auth.yaml;
HTTP 200

# no api key provided
GET http://localhost:8080/complex-header-auth/test
HTTP 403
[Asserts]
body contains "RBAC: access denied"

GET http://localhost:8080/complex-header-auth/test
My-Complex-Header: issuer=myissuer, location=mylocation, commonname=mycommonname
HTTP 200

GET http://localhost:8080/api-key/test
my-complex-header: issuer=wrongissuer, location=mylocation, commonname=mycommonname
HTTP 403
[Asserts]
body contains "RBAC: access denied"
