POST http://localhost:{{port}}/api/upload/jwt
Content-Type: application/yaml
file,jwt.yaml;
HTTP 200

# no JWT is provided
GET http://localhost:8080/jwt/test
HTTP 401
[Asserts]
body contains "Jwt is missing"

# fetch invalid token (missing correct audience claim)
GET http://localhost:4040/local-jwt-provider/access-token
HTTP 200
[Captures]
invalid_access_token: body

# Invalid JWT is provided
GET http://localhost:8080/jwt/test
Authorization: Bearer {{invalid_access_token}}
HTTP 403
[Asserts]
body contains "Audiences in Jwt are not allowed"

# fetch valid token (including audience specified in downstream auth config)
GET http://localhost:4040/local-jwt-provider/access-token?aud=hurl-tester
HTTP 200
[Captures]
valid_access_token: body

# Valid JWT is provided
GET http://localhost:8080/jwt/test
Authorization: Bearer {{valid_access_token}}
HTTP 200

