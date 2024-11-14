# see routing-misc.hurl for more examples that use "disabled" auth
POST http://localhost:4000/api/upload/disabled
Content-Type: application/yaml
file,disabled.yaml;
HTTP 200

GET http://localhost:8080/disabled/test
HTTP 200
