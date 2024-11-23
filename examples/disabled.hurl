# see routing-misc.hurl for more examples that use "disabled" auth
POST http://localhost:{{port}}/api/upload/disabled?api-port={{port}}
Content-Type: application/yaml
file,disabled.yaml;
HTTP 200

GET http://localhost:8080/disabled/test
HTTP 200
