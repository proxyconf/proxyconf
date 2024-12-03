POST https://localhost:{{port}}/api/upload/jwt?api-port={{port}}&envoy-cluster={{envoy-cluster}}
Content-Type: application/yaml
Authorization: Bearer {{admin-access-token}}
file,jwt.yaml;
HTTP 200

# no JWT is provided
GET http://localhost:8080/jwt/test
HTTP 401
[Asserts]
body contains "Jwt is missing"

# fetch invalid token (missing correct audience claim)
POST https://localhost:{{port}}/api/access-token
[QueryStringParams]
client_id: {{oauth-client-id-other}}
client_secret: {{oauth-client-secret-other}}
grant_type: client_credentials
HTTP 200
[Captures]
invalid_access_token: jsonpath "$['access_token']"

# Invalid JWT is provided
GET http://localhost:8080/jwt/test
Authorization: Bearer {{invalid_access_token}}
HTTP 403
[Asserts]
body contains "Audiences in Jwt are not allowed"

# fetch valid token (including audience specified in downstream auth config)
POST https://localhost:{{port}}/api/access-token
[QueryStringParams]
client_id: {{oauth-client-id}}
client_secret: {{oauth-client-secret}}
grant_type: client_credentials
HTTP 200
[Captures]
valid_access_token: jsonpath "$['access_token']"

# Valid JWT is provided
GET http://localhost:8080/jwt/test
Authorization: Bearer {{valid_access_token}}
HTTP 200

