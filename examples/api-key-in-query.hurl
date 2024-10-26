POST http://localhost:4040/upload/api-key-in-query.yaml
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
