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
envoy -c $BASEDIR/envoy.server.yaml --service-cluster $ENVOY_CLUSTER &

# poll the admin ui address
wait_for_envoy "http://localhost:9901" 60

ADMIN_ACCESS_TOKEN=$(curl -X POST "http://localhost:4002/api/access-token?client_id=$OAUTH_CLIENT_ID&client_secret=$OAUTH_CLIENT_SECRET&grant_type=client_credentials" | jq -r ".access_token")


# reusing the client certs that were bootstrapped for envoy
hurl $BASEDIR/*.hurl --file-root $BASEDIR --cacert /tmp/proxyconf/ca-cert.pem \
    --variable port=4002 \
    --variable admin-access-token=$ADMIN_ACCESS_TOKEN \
    --variable envoy-cluster=$ENVOY_CLUSTER \
    --variable oauth-client-id=$OAUTH_CLIENT_ID \
    --variable oauth-client-secret=$OAUTH_CLIENT_SECRET \
    --variable oauth-client-id-other=$OAUTH_CLIENT_ID_OTHER \
    --variable oauth-client-secret-other=$OAUTH_CLIENT_SECRET_OTHER
