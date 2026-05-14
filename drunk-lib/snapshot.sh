#!/usr/bin/env bash
# snapshot.sh — capture golden-file baselines for drunk-lib consumer charts.
# Run from the worktree root: bash drunk-lib/snapshot.sh
#
# IMPORTANT — consumer scope:
#   Only "drunk-app" is captured because it is the sole chart that depends on the
#   local drunk-lib source (via file://../drunk-lib in Chart.yaml). Gateway charts
#   (drunk-traefik-gateway, drunk-nginx-gateway) have no drunk-lib dependency.
#   drunk-squid-basic-auth vendors a released drunk-app tarball, not local drunk-lib.
#   drunk-sample and microsoft-hello-world-app are values files, not Helm charts.
#
# Three renders are machine-diffable (stable, no random content):
#   drunk-app-default.yaml      — default values.yaml (renders empty; stable)
#   drunk-app-svc-disabled.yaml — service.enabled: false regression case
#   drunk-app-secretprovider.yaml — secretProvider.enabled: true regression case
#
# One render is human-review only (NOT machine-diffed in verify.sh):
#   drunk-app-example.yaml      — values.example.yaml; contains randAlphaNum Job names
#                                 that differ on every render
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GOLDEN_DIR="$SCRIPT_DIR/tests/golden"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

mkdir -p "$GOLDEN_DIR"

echo "==> Capturing drunk-app (values.yaml — machine-diffable) ..."
helm template test-release "$REPO_ROOT/drunk-app" \
  --values "$REPO_ROOT/drunk-app/values.yaml" \
  2>/dev/null > "$GOLDEN_DIR/drunk-app-default.yaml"
echo "    Written: $GOLDEN_DIR/drunk-app-default.yaml ($(wc -l < "$GOLDEN_DIR/drunk-app-default.yaml") lines)"

echo "==> Capturing drunk-app (service.enabled: false — machine-diffable) ..."
helm template test-release "$REPO_ROOT/drunk-app" \
  --values "$REPO_ROOT/drunk-app/values.yaml" \
  --set service.enabled=false \
  2>/dev/null > "$GOLDEN_DIR/drunk-app-svc-disabled.yaml"
echo "    Written: $GOLDEN_DIR/drunk-app-svc-disabled.yaml ($(wc -l < "$GOLDEN_DIR/drunk-app-svc-disabled.yaml") lines)"

echo "==> Capturing drunk-app (secretProvider.enabled: true — machine-diffable) ..."
helm template test-release "$REPO_ROOT/drunk-app" \
  --values "$REPO_ROOT/drunk-app/values.yaml" \
  --set secretProvider.enabled=true \
  --set secretProvider.tenantId=test-tenant \
  --set secretProvider.vaultName=test-vault \
  2>/dev/null > "$GOLDEN_DIR/drunk-app-secretprovider.yaml"
echo "    Written: $GOLDEN_DIR/drunk-app-secretprovider.yaml ($(wc -l < "$GOLDEN_DIR/drunk-app-secretprovider.yaml") lines)"

echo "==> Capturing drunk-app (values.example.yaml — HUMAN REVIEW ONLY, not machine-diffed) ..."
helm template test-release "$REPO_ROOT/drunk-app" \
  --values "$REPO_ROOT/drunk-app/values.example.yaml" \
  2>/dev/null > "$GOLDEN_DIR/drunk-app-example.yaml"
echo "    Written: $GOLDEN_DIR/drunk-app-example.yaml ($(wc -l < "$GOLDEN_DIR/drunk-app-example.yaml") lines)"
echo "    NOTE: This file is for human review only. Job names contain randAlphaNum suffixes"
echo "          that change on every render. Do not add it to the machine-diff list in verify.sh."

echo ""
echo "Golden files captured. Review them visually, then commit alongside your first template change."
