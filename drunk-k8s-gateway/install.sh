#!/bin/bash
#!/bin/bash
# Install script for drunk-k8s-gateway chart
# Two-phase installation:
#  1. Install Gateway API CRDs via kubectl (bypasses Helm 3MB limit)
#  2. Install Helm chart for GatewayClass, Gateway, HTTPRoute resources
#
# Usage (basic):
#   ./install.sh                 # uses defaults
#
# Environment / flags:
#   RELEASE_NAME=gateway         # Helm release name
#   NAMESPACE=drunk-gateway      # Target namespace
#   VALUES_FILE=values.local.yaml# Values file
#   GATEWAY_API_VERSION=v1.2.0   # Gateway API version to install
#   GATEWAY_API_CHANNEL=standard # standard|experimental
#   SKIP_CRDS=false              # Skip CRD installation (if already installed)
#   FORCE_REINSTALL_CRDS=false   # Delete and reinstall CRDs
#   BUILD_CHART=true             # Run ./build.sh before install
#
# Examples:
#   ./install.sh
#   SKIP_CRDS=true ./install.sh
#   FORCE_REINSTALL_CRDS=true ./install.sh
#   GATEWAY_API_VERSION=v1.1.0 ./install.sh

set -euo pipefail

RELEASE_NAME="${RELEASE_NAME:-gateway}"
NAMESPACE="${NAMESPACE:-drunk-gateway}"
VALUES_FILE="${VALUES_FILE:-values.local.yaml}"
GATEWAY_API_VERSION="${GATEWAY_API_VERSION:-v1.2.0}"
GATEWAY_API_CHANNEL="${GATEWAY_API_CHANNEL:-standard}"
SKIP_CRDS="${SKIP_CRDS:-false}"
FORCE_REINSTALL_CRDS="${FORCE_REINSTALL_CRDS:-false}"
BUILD_CHART="${BUILD_CHART:-false}"

CHART_DIR="$(cd "$(dirname "$0")" && pwd)"
GATEWAY_API_URL="https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/${GATEWAY_API_CHANNEL}-install.yaml"

CRDS=(
  gatewayclasses.gateway.networking.k8s.io
  gateways.gateway.networking.k8s.io
  httproutes.gateway.networking.k8s.io
  grpcroutes.gateway.networking.k8s.io
  referencegrants.gateway.networking.k8s.io
)

if [[ "$GATEWAY_API_CHANNEL" == "experimental" ]]; then
  CRDS+=(
    tcproutes.gateway.networking.k8s.io
    tlsroutes.gateway.networking.k8s.io
    udproutes.gateway.networking.k8s.io
  )
fi

info() { echo -e "\033[34m[INFO]\033[0m $*"; }
warn() { echo -e "\033[33m[WARN]\033[0m $*"; }
error() { echo -e "\033[31m[ERROR]\033[0m $*"; }
success() { echo -e "\033[32m[SUCCESS]\033[0m $*"; }

check_dep() { 
  command -v "$1" >/dev/null 2>&1 || { 
    error "Missing dependency: $1"
    exit 1
  }
}

check_dep helm
check_dep kubectl
check_dep curl

if [[ ! -f "$CHART_DIR/$VALUES_FILE" ]]; then
  error "Values file '$VALUES_FILE' not found in chart directory"
  exit 1
fi

echo ""
info "========================================="
info "drunk-k8s-gateway Installation"
info "========================================="
info "Release:   $RELEASE_NAME"
info "Namespace: $NAMESPACE"
info "Values:    $VALUES_FILE"
info "Gateway API: $GATEWAY_API_VERSION ($GATEWAY_API_CHANNEL)"
info "========================================="
echo ""

# Phase 1: Install Gateway API CRDs
if [[ "$SKIP_CRDS" == "true" ]]; then
  info "SKIP_CRDS=true, skipping Gateway API CRD installation"
else
  info "Phase 1: Installing Gateway API CRDs"
  
  existing_crds=()
  for crd in "${CRDS[@]}"; do
    if kubectl get crd "$crd" >/dev/null 2>&1; then
      existing_crds+=("$crd")
    fi
  done
  
  if (( ${#existing_crds[@]} > 0 )); then
    info "Found existing Gateway API CRDs: ${existing_crds[*]}"
    
    if [[ "$FORCE_REINSTALL_CRDS" == "true" ]]; then
      warn "FORCE_REINSTALL_CRDS=true, deleting existing CRDs..."
      kubectl delete crd "${existing_crds[@]}" 2>/dev/null || true
      info "Waiting for CRD deletion to complete..."
      sleep 3
      existing_crds=()
    else
      info "CRDs already installed, skipping installation"
      info "Use FORCE_REINSTALL_CRDS=true to reinstall"
    fi
  fi
  
  if (( ${#existing_crds[@]} == 0 )); then
    info "Downloading Gateway API CRDs from: $GATEWAY_API_URL"
    if curl -fsSL "$GATEWAY_API_URL" | kubectl apply -f - 2>&1 | grep -v "unrecognized format"; then
      success "Gateway API CRDs installed successfully"
    else
      error "Failed to install Gateway API CRDs"
      exit 1
    fi
    
    # Verify CRDs are established
    info "Waiting for CRDs to be established..."
    for crd in "${CRDS[@]}"; do
      kubectl wait --for condition=established --timeout=60s crd/"$crd" 2>/dev/null || warn "CRD $crd not established yet"
    done
    success "All CRDs are ready"
  fi
fi

echo ""
info "Phase 2: Installing Helm chart (GatewayClass, Gateway, HTTPRoute)"

if [[ "$BUILD_CHART" == "true" ]]; then
  info "Building chart..."
  SKIP_GATEWAY_API=true "$CHART_DIR/build.sh" || warn "Chart build failed, continuing with existing files"
fi

info "Installing Helm release: $RELEASE_NAME"
SUBCHART_ENABLED=$(grep -E '^nginxGatewayFabric:' -A3 "$CHART_DIR/$VALUES_FILE" | grep -E 'enabled:[[:space:]]*true' || true)

HELM_SKIP_CRDS_FLAG="--skip-crds"
if [[ -n "$SUBCHART_ENABLED" ]]; then
  info "nginx-gateway-fabric subchart enabled -> allowing its CRDs to install (omitting --skip-crds)"
  HELM_SKIP_CRDS_FLAG=""
elif [[ "$SKIP_CRDS" == "true" ]]; then
  info "--skip-crds will be used (no chart CRDs applied)"
else
  info "Installing chart CRDs (if any)"
  HELM_SKIP_CRDS_FLAG=""
fi

helm upgrade --install "$RELEASE_NAME" "$CHART_DIR" \
  --namespace "$NAMESPACE" \
  --create-namespace \
  --values "$CHART_DIR/$VALUES_FILE" \
  ${HELM_SKIP_CRDS_FLAG}

success "Helm chart installed successfully"

echo ""
success "========================================="
success "Installation Complete!"
success "========================================="
echo ""
info "Verify installation:"
echo "  kubectl get gatewayclass"
echo "  kubectl get gateway -n $NAMESPACE"
echo "  kubectl get httproute -n $NAMESPACE"
echo ""
info "Describe resources:"
echo "  kubectl describe gatewayclass"
echo "  kubectl describe gateway -n $NAMESPACE"
echo ""
info "Label namespaces to allow HTTPRoute access (if using Selector mode):"
echo "  kubectl label namespace $NAMESPACE gateway.drunk.charts/access=<gateway-label>"
echo "  kubectl label namespace <app-namespace> gateway.drunk.charts/access=<gateway-label>"
echo ""
info "Check Gateway status:"
echo "  kubectl get gateway <gateway-name> -n $NAMESPACE -o yaml"
echo ""