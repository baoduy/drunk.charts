#!/bin/bash
# Build script for drunk-k8s-gateway chart
# Author: Duy Bao (baoduy)
# Repository: https://github.com/baoduy/drunk.charts

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="$SCRIPT_DIR"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Gateway API configuration (from values.yaml)
GATEWAY_API_VERSION="${GATEWAY_API_VERSION:-v1.2.0}"
GATEWAY_API_CHANNEL="${GATEWAY_API_CHANNEL:-standard}"

echo -e "${BLUE}Building drunk-k8s-gateway chart...${NC}"
cd "$CHART_DIR"

# Gateway API CRDs are installed separately via install.sh (kubectl)
# to bypass Helm's 3MB annotation size limit
echo -e "${BLUE}Note: Gateway API CRDs are installed separately via install.sh${NC}"
echo "  This chart installs GatewayClass, Gateway, and HTTPRoute resources only"
echo "  CRDs are applied via kubectl to avoid Helm's 3MB annotation limit"

CRD_DIR="crds"
mkdir -p "$CRD_DIR"

# Ensure .gitkeep exists
if [[ ! -f "$CRD_DIR/.gitkeep" ]]; then
    cat > "$CRD_DIR/.gitkeep" << 'EOF'
# Gateway API CRDs are installed separately via kubectl in install.sh
# This avoids Helm's 3MB annotation size limit (Gateway API CRDs > 3MB)
# 
# Installation happens in two phases:
#   1. kubectl apply -f https://github.com/.../gateway-api/releases/.../standard-install.yaml
#   2. helm upgrade --install --skip-crds ...
#
# This directory is preserved to maintain Helm chart structure.
EOF
    echo -e "${GREEN}✅ Created $CRD_DIR/.gitkeep${NC}"
fi

# Update dependencies
echo "Updating chart dependencies..."
helm dependency update

# Package the chart
echo "Packaging chart..."
helm package . -d .

# Generate/update index
echo "Updating chart index..."
helm repo index . --url https://baoduy.github.io/drunk.charts/drunk-k8s-gateway

echo -e "${GREEN}✅ Chart built successfully!${NC}"
echo ""
ls -lh *.tgz 2>/dev/null || echo "Package files will appear after first build"
