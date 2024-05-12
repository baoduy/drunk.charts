#!/bin/bash

# Define variables
RELEASE_NAME="drunk-squid-proxy"
NAMESPACE="drunk-proxy"
CHART_PATH="./"
VALUES_FILE="./values.local.yaml"

# Check if the Helm release already exists in the namespace
helm status $RELEASE_NAME --namespace $NAMESPACE > /dev/null 2>&1

# Capture the exit code of the last command
STATUS_CODE=$?

if [ $STATUS_CODE -eq 0 ]; then
    echo "Release $RELEASE_NAME already exists in the namespace $NAMESPACE. Upgrading..."
    # Upgrade existing release
    helm upgrade $RELEASE_NAME -f values.yaml -f $VALUES_FILE $CHART_PATH --namespace $NAMESPACE
else
    echo "Release $RELEASE_NAME does not exist in the namespace $NAMESPACE. Installing..."
    # Install new release
    helm install $RELEASE_NAME -f values.yaml -f $VALUES_FILE $CHART_PATH --create-namespace --namespace $NAMESPACE
fi