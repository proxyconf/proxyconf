POST http://localhost:4000/api/upload/mtls
Content-Type: application/yaml
file,mtls.yaml;
HTTP 200

# HTTP Request with an invalid client certificate
GET https://localhost:44444/mtls/test
[Options]
cert: /tmp/proxyconf/exunit-bad.crt
key: /tmp/proxyconf/exunit-bad.key
HTTP 403
[Asserts]
body contains "RBAC: access denied"

# HTTP Request with a valid client certificate
GET https://localhost:44444/mtls/test
[Options]
cert: /tmp/proxyconf/exunit-good.crt
key: /tmp/proxyconf/exunit-good.key
HTTP 200

