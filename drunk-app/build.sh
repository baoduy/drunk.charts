#!/usr/bin/env bash
# build.sh — populate the drunk-lib dependency for LOCAL rendering.
# CI does not use this script; it publishes drunk-lib first and resolves the
# OCI dependency by its real version. Locally the Chart.yaml dependency is the
# `0.0.0` placeholder, which cannot be pulled from OCI, so we package the
# sibling drunk-lib chart straight into charts/ instead.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

mkdir -p "$SCRIPT_DIR/charts"
# Keep only the freshest drunk-lib package; leave any other dependency charts.
find "$SCRIPT_DIR/charts" -maxdepth 1 -type f -name 'drunk-lib-*.tgz' -delete
helm package "$REPO_ROOT/drunk-lib" --destination "$SCRIPT_DIR/charts"
