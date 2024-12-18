POST https://localhost:{{port}}/api/spec/routing-misc?api-port={{port}}&envoy-cluster={{envoy-cluster}}
Content-Type: application/yaml
Authorization: Bearer {{admin-access-token}}
file,routing-misc.yaml;
HTTP 200

GET http://localhost:8080/routing-misc/test
HTTP 200

# We expect a not found as required request body is missing 
# and thereore no route matches
POST http://localhost:8080/routing-misc/test
HTTP 404

# Also a 404 for wrong path
GET http://localhost:8080/routing-misc/test2
HTTP 404

# With valid content type 
POST http://localhost:8080/routing-misc/test
Content-Type: application/json
{
  "hello": "world"
}
HTTP 200

# With invalid content type 
POST http://localhost:8080/routing-misc/test
Content-Type: text/plain
"hello world"
HTTP 404
