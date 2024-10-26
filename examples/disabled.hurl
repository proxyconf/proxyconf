# see routing-misc.hurl for more examples that use "disabled" auth
POST http://localhost:4040/upload/disabled.yaml
file,disabled.yaml;
HTTP 200

GET http://localhost:8080/disabled/test
HTTP 200
