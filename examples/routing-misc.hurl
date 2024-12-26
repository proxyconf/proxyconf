POST https://localhost:{{port}}/api/spec/routing-misc?api-port={{port}}&envoy-cluster={{envoy-cluster}}
Content-Type: application/yaml
Authorization: Bearer {{admin-access-token}}
file,routing-misc.yaml;
HTTP 200

GET http://localhost:8080/routing-misc/test
HTTP 200

# We expect a not found as required request body is missing 
# and therefore no route matches
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

# Test Path Template /test/{path-variable}
GET http://localhost:8080/routing-misc/test/some-variable
HTTP 200
[Asserts]
jsonpath "$.request_path" == "/api/echo/test/some-variable"

# Test Path Template with wildcard /wildcard/{requestPath}
# {requestPath} is the naming convention for path wildcard
GET http://localhost:8080/routing-misc/wildcard/a/b/c/d/e
HTTP 200
[Asserts]
jsonpath "$.request_path" == "/api/echo/wildcard/a/b/c/d/e"


# Test API to fetch spec
GET https://localhost:{{port}}/api/spec/routing-misc
Authorization: Bearer {{admin-access-token}}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.x-proxyconf.cluster" == {{envoy-cluster}}

# Test API to list api ids for cluster
GET https://localhost:{{port}}/api/specs
Authorization: Bearer {{admin-access-token}}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.cluster" == {{envoy-cluster}}
jsonpath "$.spec_ids" includes "routing-misc"


# Test delete API 
DELETE https://localhost:{{port}}/api/spec/routing-misc
Authorization: Bearer {{admin-access-token}}
HTTP 200

# Test that API isn't available anymore
# a 403 is expected as other APIs still exist on the same listener
# if this was the only API on this listener, the listener would have
# been terminated and a connection error would be the result
GET http://localhost:8080/routing-misc/test
HTTP *
[Asserts]
status >= 403
status <= 404


