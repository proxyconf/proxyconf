#!/usr/bin/env bash


if [[ -z "${EXUNIT_RUNNER}" ]]; then
    echo "!!!!!!!!!!!!!! run.sh must be executed via 'mix test test/hurl_test.exs'"
    exit 1
fi

set -eu

wait_for_envoy () {
    echo "Testing $1..."
    printf 'GET %s\nHTTP 200' "$1" | hurl --retry "$2" > /dev/null;
    return 0
}

BASEDIR=$(dirname "$0")
envoy -c $BASEDIR/envoy.server.yaml &

# poll the admin ui address
wait_for_envoy "http://localhost:9901" 60


# reusing the client certs that were bootstrapped for envoy
hurl $BASEDIR/*.hurl --file-root $BASEDIR --cacert /tmp/proxyconf/ca-cert.pem \
    --variable port=4002  # configured in config/test.exs
