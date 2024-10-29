#!/usr/bin/env bash

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

# hurl $BASEDIR/*.hurl --cacert /tmp/proxyconf/ca-cert.pem

# reusing the client certs that were bootstrapped for envoy
hurl $BASEDIR/mtls/*.hurl --file-root $BASEDIR --cacert /tmp/proxyconf/ca-cert.pem --cert /tmp/proxyconf/client.crt --key /tmp/proxyconf/client.key
