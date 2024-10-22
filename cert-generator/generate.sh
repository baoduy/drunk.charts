#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# Check for required arguments
if [ $# -lt 2 ]; then
  echo "Usage: $0 <domain_name> <password>"
  exit 1
fi

domain_name=$1
password=$2

# OpenSSL config file
OPENSSL_CONFIG="./openssl.cnf"

# Check if OpenSSL config file exists
if [ ! -f "$OPENSSL_CONFIG" ]; then
  echo "OpenSSL configuration file not found: $OPENSSL_CONFIG"
  exit 1
fi

# Export domain_name for use in openssl.cnf
export DOMAIN_NAME="$domain_name"

# Clean up any existing files from previous runs
echo "Cleaning up existing files for $domain_name..."
rm -f "${domain_name}-ca.key" \
      "${domain_name}-ca.crt" \
      "${domain_name}-ca.srl" \
      "${domain_name}.key" \
      "${domain_name}.crt" \
      "${domain_name}.csr" \
      "${domain_name}.pfx"
      
echo "Generating CA private key and certificate..."
openssl req -new -x509 -days 3650 -nodes \
  -keyout "${domain_name}-ca.key" \
  -out "${domain_name}-ca.crt" \
  -config "$OPENSSL_CONFIG" \
  -extensions v3_ca \
  -subj "/C=US/ST=State/L=Locality/O=Organization/CN=CA_$domain_name"

echo "Generating server private key..."
openssl genrsa -out "${domain_name}.key" 2048

echo "Generating server certificate signing request (CSR)..."
openssl req -new \
  -key "${domain_name}.key" \
  -out "${domain_name}.csr" \
  -config "$OPENSSL_CONFIG"

echo "Signing server CSR with CA..."
openssl x509 -req \
  -in "${domain_name}.csr" \
  -CA "${domain_name}-ca.crt" \
  -CAkey "${domain_name}-ca.key" \
  -CAcreateserial \
  -out "${domain_name}.crt" \
  -days 3650 \
  -extensions v3_req \
  -extfile "$OPENSSL_CONFIG"

echo "Creating PFX file..."
openssl pkcs12 -export \
  -out "${domain_name}.pfx" \
  -inkey "${domain_name}.key" \
  -in "${domain_name}.crt" \
  -certfile "${domain_name}-ca.crt" \
  -password pass:"$password"

echo "Cleaning up..."
rm "${domain_name}.csr" "${domain_name}-ca.srl"

echo "Certificate generation completed successfully."