POST http://localhost:4040/upload/downstream-tls.yaml
file,downstream-tls.yaml;
HTTP 200

GET https://localhost:8443/downstream-tls/test
HTTP 200

# We expect a not found as required request body is missing 
# and thereore no route matches
POST https://localhost:8443/downstream-tls/test
HTTP 404

# Also a 404 for wrong path
GET https://localhost:8443/downstream-tls/test2
HTTP 404

# With valid content type 
POST https://localhost:8443/downstream-tls/test
Content-Type: application/json
{
  "hello": "world"
}
HTTP 200

# With invalid content type 
POST https://localhost:8443/downstream-tls/test
Content-Type: text/plain
"hello world"
HTTP 404
