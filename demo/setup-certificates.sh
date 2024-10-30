#!/usr/bin/env bash

# this script 

# Communication between Envoy Proxies and ProxyConf is secured by Mutual TLS

BASEDIR=$(dirname "$0")

if [ ! -e "$BASEDIR/status" ]; then
# Setup a Demo CA
openssl req -nodes -newkey rsa:4096 -keyout $BASEDIR/proxyconf/ca.key -new -x509 -days 7300 -sha256 -extensions v3_ca -out $BASEDIR/proxyconf/ca.crt -subj "/C=CH/ST=Basel/L=Basel/O=ProxyConf/OU=Demo CA/CN=Root CA"
cp $BASEDIR/proxyconf/ca.crt $BASEDIR/envoy/ca.crt

# Create Private Key / CSR used by Envoy to authenticate against ProxyConf
openssl req -nodes -newkey rsa:4096 -keyout $BASEDIR/envoy/client.key -out $BASEDIR/envoy/client.csr -subj "/C=CH/ST=Basel/L=Basel/O=ProxyConf/OU=Demo Client/CN=Envoy ProxyConf Client"
# Create Private Key / CSR used by ProxyConf GRPC Server
openssl req -nodes -newkey rsa:4096 -keyout $BASEDIR/proxyconf/server.key -out $BASEDIR/proxyconf/server.csr -subj "/C=CH/ST=Basel/L=Basel/O=ProxyConf/OU=Demo ControlPlane/CN=ProxyConf"
# Create Private Key / CSR used by localhost API Endpoint, cn must match with the domain
openssl req -nodes -newkey rsa:4096 -keyout $BASEDIR/proxyconf/localhost.key -out $BASEDIR/proxyconf/localhost.csr -subj "/C=CH/ST=Basel/L=Basel/O=ProxyConf/OU=Demo Server/CN=localhost"
# Create Private Key / CSR used by local client (e.g. cURL)
openssl req -nodes -newkey rsa:4096 -keyout $BASEDIR/demo-client.key -out $BASEDIR/demo-client.csr -subj "/C=CH/ST=Basel/L=Basel/O=ProxyConf/OU=Demo Client/CN=demo-client"

# Issue Certificates
openssl x509 -req -in $BASEDIR/envoy/client.csr -CA $BASEDIR/proxyconf/ca.crt -CAkey $BASEDIR/proxyconf/ca.key -out $BASEDIR/envoy/client.crt -days 365 -sha256
openssl x509 -req -in $BASEDIR/proxyconf/server.csr -CA $BASEDIR/proxyconf/ca.crt -CAkey $BASEDIR/proxyconf/ca.key -out $BASEDIR/proxyconf/server.crt -days 365 -sha256
openssl x509 -req -in $BASEDIR/proxyconf/localhost.csr -CA $BASEDIR/proxyconf/ca.crt -CAkey $BASEDIR/proxyconf/ca.key -out $BASEDIR/proxyconf/localhost.crt -days 365 -sha256
openssl x509 -req -in $BASEDIR/demo-client.csr -CA $BASEDIR/proxyconf/ca.crt -CAkey $BASEDIR/proxyconf/ca.key -out $BASEDIR/demo-client.crt -days 365 -sha256 

# this is ok as it is a demo setup, never do this in production
chmod -R a+r $BASEDIR/envoy $BASEDIR/proxyconf
echo "setup-certificates:done" > $BASEDIR/status
else
	echo "================================================================"
	echo "Use existing keys & certificates in $BASEDIR."
	echo "Delete $BASEDIR/status and rerun command to recreate!"
	echo "================================================================"
fi

