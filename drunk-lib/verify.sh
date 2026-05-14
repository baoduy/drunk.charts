#!/usr/bin/env bash
# verify.sh — package drunk-lib, copy to drunk-app, then verify golden-file regression.
# Run from inside drunk-lib/: bash verify.sh   OR from repo root: bash drunk-lib/verify.sh
#
# Machine-diffed golden files (stable, no random content):
#   tests/golden/drunk-app-default.yaml       — default values (empty render)
#   tests/golden/drunk-app-svc-disabled.yaml  — service.enabled: false
#   tests/golden/drunk-app-secretprovider.yaml — secretProvider.enabled: true
#
# Excluded from machine diff (intentionally non-deterministic):
#   tests/golden/drunk-app-example.yaml       — contains randAlphaNum Job names;
#                                               committed for human PR review only
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GOLDEN_DIR="$SCRIPT_DIR/tests/golden"

# ── Step 1: Package and index ──────────────────────────────────────────────
cd "$SCRIPT_DIR"
helm package ./
helm repo index ./

# ── Step 2: Copy latest .tgz to drunk-app/charts ──────────────────────────
latest_tgz=$(ls -t ./*.tgz 2>/dev/null | head -n1)
if [ -z "$latest_tgz" ] || [ ! -f "$latest_tgz" ]; then
    echo "No .tgz files found"
    exit 1
fi
mkdir -p "$REPO_ROOT/drunk-app/charts"
cp -f "$latest_tgz" "$REPO_ROOT/drunk-app/charts/"

# ── Step 3: Golden-file regression check ──────────────────────────────────
# Skip entirely if golden directory has not been initialised yet.
if [ ! -d "$GOLDEN_DIR" ]; then
    echo "No golden directory found at $GOLDEN_DIR — skipping regression check."
    echo "Run: bash drunk-lib/snapshot.sh"
    exit 0
fi

FAIL=0

run_diff() {
    local label="$1"
    local chart_dir="$2"
    local golden_file="$3"
    shift 3
    # remaining args are passed verbatim to helm template (--values / --set flags)

    if [ ! -f "$golden_file" ]; then
        echo "[SKIP] $label — golden file not found: $golden_file"
        return
    fi

    local tmp
    tmp="${TMPDIR:-/tmp}/drunk-lib-verify-$$.yaml"
    helm template test-release "$chart_dir" "$@" 2>/dev/null > "$tmp"

    if ! diff -u "$golden_file" "$tmp"; then
        echo ""
        echo "[FAIL] $label — output differs from golden file"
        FAIL=1
    else
        echo "[OK]   $label"
    fi
    rm -f "$tmp"
}

echo ""
echo "==> Running golden-file regression checks (machine-diffable renders only) ..."

run_diff "drunk-app (values.yaml)" \
    "$REPO_ROOT/drunk-app" \
    "$GOLDEN_DIR/drunk-app-default.yaml" \
    --values "$REPO_ROOT/drunk-app/values.yaml"

run_diff "drunk-app (service.enabled: false)" \
    "$REPO_ROOT/drunk-app" \
    "$GOLDEN_DIR/drunk-app-svc-disabled.yaml" \
    --values "$REPO_ROOT/drunk-app/values.yaml" \
    --set service.enabled=false

run_diff "drunk-app (secretProvider.enabled: true)" \
    "$REPO_ROOT/drunk-app" \
    "$GOLDEN_DIR/drunk-app-secretprovider.yaml" \
    --values "$REPO_ROOT/drunk-app/values.yaml" \
    --set secretProvider.enabled=true \
    --set secretProvider.tenantId=test-tenant \
    --set secretProvider.vaultName=test-vault

# drunk-app-example.yaml is intentionally excluded: _job.tpl uses randAlphaNum 5
# in Job names → non-deterministic output. It is committed for human PR review only.

if [ "$FAIL" -eq 1 ]; then
    echo ""
    echo "ERROR: Golden-file regression detected. See diff above."
    echo "If the change is intentional, update golden files: bash drunk-lib/snapshot.sh"
    exit 1
fi

echo ""
echo "All checks passed."
