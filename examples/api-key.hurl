POST http://localhost:4000/api/upload/api-key
Content-Type: application/yaml
file,api-key.yaml;
HTTP 200

# no api key provided
GET http://localhost:8080/api-key/test
HTTP 403
[Asserts]
body contains "RBAC: access denied"

GET http://localhost:8080/api-key/test
my-api-key: supersecret
HTTP 200

GET http://localhost:8080/api-key/test
my-api-key: wrongsecret
HTTP 403
[Asserts]
body contains "RBAC: access denied"
