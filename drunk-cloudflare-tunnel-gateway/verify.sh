#!/usr/bin/env bash
# Verify drunk-cloudflare-tunnel-gateway: build deps, lint, render, package, index.yaml.
# Author: Duy Bao (baoduy) — https://github.com/baoduy/drunk.charts
set -euo pipefail
cd "$(dirname "$0")"

# The cloudflare-tunnel subchart hard-requires a tunnelID; supply a dummy so
# lint + render succeed. Real deploys set this in values.
EXTRA_ARGS=(--set cloudflareTunnel.gatewayClassConfig.tunnelID=00000000-0000-0000-0000-000000000000)

echo "==> helm dependency build"
helm dependency build .

echo "==> helm lint"
helm lint . "${EXTRA_ARGS[@]}"

echo "==> helm template (render check)"
helm template test . "${EXTRA_ARGS[@]}" >/dev/null

echo "==> helm package + repo index (index.yaml)"
helm package .
helm repo index .

echo "All checks passed."
