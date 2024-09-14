#!/usr/bin/env bash

# this script 

# Communication between Envoy Proxies and ProxyConf is secured by Mutual TLS

# Setup a Demo CA
openssl req -nodes -newkey rsa:4096 -keyout proxyconf/ca.key -new -x509 -days 7300 -sha256 -extensions v3_ca -out proxyconf/ca.crt -subj "/C=CH/ST=Basel/L=Basel/O=ProxyConf/OU=Demo CA/CN=Root CA"
cp proxyconf/ca.crt envoy/ca.crt

# Create Private Key / CSR used by Envoy to authenticate against ProxyConf
openssl req -nodes -newkey rsa:4096 -keyout envoy/client.key -out envoy/client.csr -subj "/C=CH/ST=Basel/L=Basel/O=ProxyConf/OU=Demo Client/CN=Envoy ProxyConf Client"
# Create Private Key / CSR used by ProxyConf GRPC Server
openssl req -nodes -newkey rsa:4096 -keyout proxyconf/server.key -out proxyconf/server.csr -subj "/C=CH/ST=Basel/L=Basel/O=ProxyConf/OU=Demo ControlPlane/CN=ProxyConf"
# Create Private Key / CSR used by localhost API Endpoint, cn must match with the domain
openssl req -nodes -newkey rsa:4096 -keyout proxyconf/localhost.key -out proxyconf/localhost.csr -subj "/C=CH/ST=Basel/L=Basel/O=ProxyConf/OU=Demo Server/CN=localhost"
# Create Private Key / CSR used by local client (e.g. cURL)
openssl req -nodes -newkey rsa:4096 -keyout demo-client.key -out demo-client.csr -subj "/C=CH/ST=Basel/L=Basel/O=ProxyConf/OU=Demo Client/CN=demo-client"

# Issue Certificates
openssl x509 -req -in envoy/client.csr -CA proxyconf/ca.crt -CAkey proxyconf/ca.key -out envoy/client.crt -days 365 -sha256
openssl x509 -req -in proxyconf/server.csr -CA proxyconf/ca.crt -CAkey proxyconf/ca.key -out proxyconf/server.crt -days 365 -sha256 
openssl x509 -req -in proxyconf/localhost.csr -CA proxyconf/ca.crt -CAkey proxyconf/ca.key -out proxyconf/localhost.crt -days 365 -sha256 
openssl x509 -req -in demo-client.csr -CA proxyconf/ca.crt -CAkey proxyconf/ca.key -out demo-client.crt -days 365 -sha256 

# this is ok as it is a demo setup, never do this in production
chmod -R a+r envoy proxyconf

