#!/bin/bash
# Uninstall script for drunk-cloudflare-tunnel-gateway chart
# Removes the Helm release, and optionally (opt-in) the Gateway API CRDs.
#
# Usage (basic):
#   ./uninstall.sh                 # uses defaults
#
# Environment / flags:
#   RELEASE_NAME=cf-tunnel                  # Helm release name
#   NAMESPACE=cloudflare-tunnel-system      # Target namespace
#   DELETE_NAMESPACE=true             # Delete the namespace after uninstall
#   DELETE_CRDS=false                 # Delete Gateway API CRDs (cluster-wide impact, opt-in)
#   FORCE=false                       # Skip confirmations
#
# Examples:
#   ./uninstall.sh
#   DELETE_CRDS=true ./uninstall.sh
#   FORCE=true DELETE_CRDS=true ./uninstall.sh

set -euo pipefail

RELEASE_NAME="${RELEASE_NAME:-cf-tunnel}"
NAMESPACE="${NAMESPACE:-cloudflare-tunnel-system}"
DELETE_NAMESPACE="${DELETE_NAMESPACE:-true}"
DELETE_CRDS="${DELETE_CRDS:-false}"
FORCE="${FORCE:-false}"

CHART_DIR="$(cd "$(dirname "$0")" && pwd)"

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

# Discover CRDs dynamically
discover_related_crds() {
  info "Discovering related CRDs in the cluster..."

  DISCOVERED_GATEWAY_CRDS=()
  while IFS= read -r crd; do
    [[ -n "$crd" ]] && DISCOVERED_GATEWAY_CRDS+=("$crd")
  done <<< "$(kubectl get crd -o name 2>/dev/null | grep -E 'gateway\.networking\.k8s\.io$' | sed 's|customresourcedefinition.apiextensions.k8s.io/||')"

  if (( ${#DISCOVERED_GATEWAY_CRDS[@]} > 0 )); then
    info "Found Gateway API CRDs: ${DISCOVERED_GATEWAY_CRDS[*]}"
  fi
}

confirm() {
  if [[ "$FORCE" == "true" ]]; then
    return 0
  fi

  local message="$1"
  echo ""
  warn "$message"
  read -p "Continue? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "Operation cancelled"
    return 1
  fi
  return 0
}

echo ""
info "========================================="
info "drunk-cloudflare-tunnel-gateway Uninstallation"
info "========================================="
info "Release:   $RELEASE_NAME"
info "Namespace: $NAMESPACE"

discover_related_crds
echo ""
info "========================================="
echo ""

# Check if release exists
if ! helm list -n "$NAMESPACE" | grep -q "^$RELEASE_NAME"; then
  warn "Helm release '$RELEASE_NAME' not found in namespace '$NAMESPACE'"
  info "Available releases in namespace:"
  helm list -n "$NAMESPACE" || echo "  (none)"
else
  info "Uninstalling Helm release: $RELEASE_NAME"
  if helm uninstall "$RELEASE_NAME" -n "$NAMESPACE"; then
    success "Helm release uninstalled successfully"
  else
    error "Failed to uninstall Helm release"
    exit 1
  fi
fi

# Delete Gateway API CRDs
if [[ "$DELETE_CRDS" == "true" ]]; then
  echo ""
  if confirm "Delete Gateway API CRDs? WARNING: This will delete ALL Gateway resources cluster-wide!"; then
    info "Deleting Gateway API CRDs..."

    existing_crds=(${DISCOVERED_GATEWAY_CRDS[@]+"${DISCOVERED_GATEWAY_CRDS[@]}"})

    if (( ${#existing_crds[@]} > 0 )); then
      info "Found CRDs to delete: ${existing_crds[*]}"
      if kubectl delete crd "${existing_crds[@]}" 2>&1 | grep -v "NotFound"; then
        success "Gateway API CRDs deleted successfully"
        info "Waiting for CRD deletion to complete..."
        sleep 3
      else
        warn "Some CRDs may not have been deleted"
      fi
    else
      info "No Gateway API CRDs found"
    fi
  fi
else
  info "Skipping CRD deletion (use DELETE_CRDS=true to delete)"
fi

# Delete namespace
if [[ "$DELETE_NAMESPACE" == "true" ]]; then
  echo ""
  if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    if confirm "Delete namespace '$NAMESPACE'? This will delete all resources in the namespace."; then
      info "Deleting namespace: $NAMESPACE"
      if kubectl delete namespace "$NAMESPACE" --timeout=60s; then
        success "Namespace deleted successfully"
      else
        error "Failed to delete namespace (may contain finalizers or protected resources)"
        info "You can force delete with: kubectl delete namespace $NAMESPACE --grace-period=0 --force"
      fi
    fi
  else
    info "Namespace '$NAMESPACE' not found, skipping"
  fi
else
  info "Namespace '$NAMESPACE' preserved (use DELETE_NAMESPACE=true to delete)"
fi

echo ""
success "========================================="
success "Uninstallation Complete!"
success "========================================="
echo ""
info "Verify cleanup:"
echo "  kubectl get gatewayclass"
echo "  kubectl get gateway -n $NAMESPACE"
echo "  kubectl get namespace $NAMESPACE"
echo ""
info "Referenced Secrets (cloudflare-credentials, cloudflare-tunnel-token) were not created by this chart and are left in place."
echo ""
info "To completely remove Gateway API CRDs (if not already deleted):"
echo "  DELETE_CRDS=true ./uninstall.sh"
echo ""
info "To remove namespace and all resources:"
echo "  DELETE_NAMESPACE=true ./uninstall.sh"
echo ""
info "To remove everything without confirmations:"
echo "  FORCE=true DELETE_CRDS=true DELETE_NAMESPACE=true ./uninstall.sh"
echo ""
