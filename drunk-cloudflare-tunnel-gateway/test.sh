#!/bin/bash
# Test script for drunk-cloudflare-tunnel-gateway chart
# Author: Duy Bao (baoduy)
# Repository: https://github.com/baoduy/drunk.charts

helm template test ./ --values ./values.local.yaml --output-dir ../_output --debug
