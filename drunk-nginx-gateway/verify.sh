#!/usr/bin/env bash
# Verify drunk-nginx-gateway: build deps, lint, render, package, index.yaml.
# Author: Duy Bao (baoduy) — https://github.com/baoduy/drunk.charts
set -euo pipefail
cd "$(dirname "$0")"

echo "==> helm dependency build"
helm dependency build .

echo "==> helm lint"
helm lint .

echo "==> helm template (render check)"
helm template test . >/dev/null

echo "==> helm package + repo index (index.yaml)"
helm package .
helm repo index .

echo "All checks passed."
