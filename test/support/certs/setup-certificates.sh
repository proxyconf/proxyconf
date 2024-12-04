#!/usr/bin/env bash

# this script 

# Communication between Envoy Proxies and ProxyConf is secured by Mutual TLS

BASEDIR=$(dirname "$0")

# Setup a Snakeoil CA
openssl req -nodes -newkey rsa:4096 -keyout $BASEDIR/snakeoil-ca.key -new -x509 -days 7300 -sha256 -extensions v3_ca -out $BASEDIR/snakeoil-ca.crt -subj "/C=CH/ST=Basel/L=Basel/O=ProxyConf/OU=Snakeoil CA/CN=Root CA"

# Create Private Key / CSR used by Envoy to authenticate against ProxyConf
openssl req -nodes -newkey rsa:4096 -keyout $BASEDIR/snakeoil-envoy.key -out $BASEDIR/snakeoil-envoy.csr -subj "/C=CH/ST=Basel/L=Basel/O=ProxyConf/OU=Snakeoil Client/CN=Envoy ProxyConf Client"
# Create Private Key / CSR used by ProxyConf GRPC Server
openssl req -nodes -newkey rsa:4096 -keyout $BASEDIR/snakeoil-server.key -out $BASEDIR/snakeoil-server.csr -subj "/C=CH/ST=Basel/L=Basel/O=ProxyConf/OU=Snakeoil ControlPlane/CN=localhost"
# Create Private Key / CSR used by localhost API Endpoint, cn must match with the domain
openssl req -nodes -newkey rsa:4096 -keyout $BASEDIR/snakeoil-localhost.key -out $BASEDIR/snakeoil-localhost.csr -subj "/C=CH/ST=Basel/L=Basel/O=ProxyConf/OU=Snakeoil Server/CN=localhost"
# Create Private Key / CSR used by local client A (e.g. cURL)
openssl req -nodes -newkey rsa:4096 -keyout $BASEDIR/snakeoil-client-a.key -out $BASEDIR/snakeoil-client-a.csr -subj "/C=CH/ST=Basel/L=Basel/O=ProxyConf/OU=Snakeoil Client/CN=demo-client-a"
# Create Private Key / CSR used by local client B (e.g. cURL)
openssl req -nodes -newkey rsa:4096 -keyout $BASEDIR/snakeoil-client-b.key -out $BASEDIR/snakeoil-client-b.csr -subj "/C=CH/ST=Basel/L=Basel/O=ProxyConf/OU=Snakeoil Client/CN=demo-client-b"

# Issue Certificates
openssl x509 -req -in $BASEDIR/snakeoil-envoy.csr -CA $BASEDIR/snakeoil-ca.crt -CAkey $BASEDIR/snakeoil-ca.key -out $BASEDIR/snakeoil-envoy.crt -days 365 -sha256
openssl x509 -req -in $BASEDIR/snakeoil-server.csr -CA $BASEDIR/snakeoil-ca.crt -CAkey $BASEDIR/snakeoil-ca.key -out $BASEDIR/snakeoil-server.crt -days 365 -sha256
openssl x509 -req -in $BASEDIR/snakeoil-localhost.csr -CA $BASEDIR/snakeoil-ca.crt -CAkey $BASEDIR/snakeoil-ca.key -out $BASEDIR/snakeoil-localhost.crt -days 365 -sha256
openssl x509 -req -in $BASEDIR/snakeoil-client-a.csr -CA $BASEDIR/snakeoil-ca.crt -CAkey $BASEDIR/snakeoil-ca.key -out $BASEDIR/snakeoil-client-a.crt -days 365 -sha256 
openssl x509 -req -in $BASEDIR/snakeoil-client-b.csr -CA $BASEDIR/snakeoil-ca.crt -CAkey $BASEDIR/snakeoil-ca.key -out $BASEDIR/snakeoil-client-b.crt -days 365 -sha256 

rm $BASEDIR/*.csr
# this is ok as it is a demo setup, never do this in production
chmod -R a+r $BASEDIR/*.key $BASEDIR/*.crt
