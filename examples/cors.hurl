POST http://localhost:{{port}}/api/upload/cors?api-port={{port}}
Content-Type: application/yaml
file,cors.yaml;
HTTP 200

# CORS Preflight Requests are unauthenticated
OPTIONS http://localhost:8080/cors/test
Origin: http://cors.foo.com
Access-Control-Request-Method: Get
HTTP 200
Access-Control-Allow-Origin: http://cors.foo.com
Access-Control-Allow-Methods: GET,POST
Access-Control-Max-Age: 600
[Asserts]
bytes count == 0

# Accessing the actual resource must be authenticatied - negative test
GET http://localhost:8080/cors/test
HTTP 403
[Asserts]
body contains "RBAC: access denied"

# Accessing the actual resource must be authenticatied - positive test
GET http://localhost:8080/cors/test
my-api-key: supersecret
HTTP 200
