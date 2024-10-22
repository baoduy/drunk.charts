#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# Check for required arguments
if [ $# -lt 3 ]; then
  echo "Usage: $0 <pfx_file> <password> <output_folder>"
  exit 1
fi

pfx_file=$1
password=$2
output_folder=$3

# Check if pfx_file exists
if [ ! -f "$pfx_file" ]; then
  echo "PFX file not found: $pfx_file"
  exit 1
fi

# Create output folder if it doesn't exist
mkdir -p "$output_folder"

# Extract private key
echo "Extracting private key..."
openssl pkcs12 -in "$pfx_file" -nocerts -nodes -password pass:"$password" -out "$output_folder/private.key"

# Extract certificate
echo "Extracting certificate..."
openssl pkcs12 -in "$pfx_file" -clcerts -nokeys -password pass:"$password" -out "$output_folder/certificate.crt"

# Extract CA certificates (if any)
echo "Extracting CA certificates..."
openssl pkcs12 -in "$pfx_file" -cacerts -nokeys -chain -password pass:"$password" -out "$output_folder/ca_bundle.crt"

echo "Extraction completed. Files saved in $output_folder."