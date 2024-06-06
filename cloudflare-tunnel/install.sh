#!/bin/bash

# Define variables
RELEASE_NAME="cf-tunnel"
NAMESPACE="cf-system"
CHART_PATH="./"
VALUES_FILE="./values.yaml"

helm upgrade $RELEASE_NAME -f values.yaml -f $VALUES_FILE $CHART_PATH --namespace $NAMESPACE --atomic --create-namespace --install