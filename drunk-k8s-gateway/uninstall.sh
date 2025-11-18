#!/bin/bash
# Uninstall script for drunk-k8s-gateway chart
# Removes Helm release, Gateway API CRDs, and Traefik RBAC
#
# Usage (basic):
#   ./uninstall.sh                 # uses defaults
#
# Environment / flags:
#   RELEASE_NAME=gateway         # Helm release name
#   NAMESPACE=drunk-gateway      # Target namespace
#   DELETE_NAMESPACE=false       # Delete the namespace after uninstall
#   DELETE_CRDS=false            # Delete Gateway API CRDs (WARNING: affects all Gateway resources)
#   DELETE_TRAEFIK_RBAC=false    # Delete Traefik Gateway API RBAC
#   FORCE=false                  # Skip confirmations
#
# Examples:
#   ./uninstall.sh
#   DELETE_CRDS=true ./uninstall.sh
#   DELETE_NAMESPACE=true DELETE_CRDS=true ./uninstall.sh
#   FORCE=true DELETE_CRDS=true ./uninstall.sh

set -euo pipefail

RELEASE_NAME="${RELEASE_NAME:-gateway}"
NAMESPACE="${NAMESPACE:-drunk-gateway}"
DELETE_NAMESPACE="${DELETE_NAMESPACE:-false}"
DELETE_CRDS="${DELETE_CRDS:-false}"
DELETE_TRAEFIK_RBAC="${DELETE_TRAEFIK_RBAC:-false}"
FORCE="${FORCE:-false}"

CHART_DIR="$(cd "$(dirname "$0")" && pwd)"
TRAEFIK_RBAC_URL="https://raw.githubusercontent.com/traefik/traefik/v3.6/docs/content/reference/dynamic-configuration/kubernetes-gateway-rbac.yml"

# Gateway API CRDs
GATEWAY_CRDS=(
  gatewayclasses.gateway.networking.k8s.io
  gateways.gateway.networking.k8s.io
  httproutes.gateway.networking.k8s.io
  grpcroutes.gateway.networking.k8s.io
  referencegrants.gateway.networking.k8s.io
  tcproutes.gateway.networking.k8s.io
  tlsroutes.gateway.networking.k8s.io
  udproutes.gateway.networking.k8s.io
  backendtlspolicies.gateway.networking.k8s.io
)

# Traefik Custom CRDs
TRAEFIK_CRDS=(
  ingressroutes.traefik.io
  ingressroutetcps.traefik.io
  ingressrouteudps.traefik.io
  middlewares.traefik.io
  middlewaretcps.traefik.io
  serverstransports.traefik.io
  serverstransporttcps.traefik.io
  tlsoptions.traefik.io
  tlsstores.traefik.io
  traefikservices.traefik.io
)

# Traefik Hub CRDs (from hub.traefik.io)
TRAEFIK_HUB_CRDS=()

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
  
  # Find all Gateway API CRDs
  mapfile -t DISCOVERED_GATEWAY_CRDS < <(kubectl get crd -o name 2>/dev/null | grep -E 'gateway\.networking\.k8s\.io$' | sed 's|customresourcedefinition.apiextensions.k8s.io/||')
  
  # Find all Traefik CRDs
  mapfile -t DISCOVERED_TRAEFIK_CRDS < <(kubectl get crd -o name 2>/dev/null | grep -E 'traefik\.(io|containo\.us)$' | sed 's|customresourcedefinition.apiextensions.k8s.io/||')
  
  # Find all Traefik Hub CRDs
  mapfile -t TRAEFIK_HUB_CRDS < <(kubectl get crd -o name 2>/dev/null | grep -E 'hub\.traefik\.io$' | sed 's|customresourcedefinition.apiextensions.k8s.io/||')
  
  if (( ${#DISCOVERED_GATEWAY_CRDS[@]} > 0 )); then
    info "Found Gateway API CRDs: ${DISCOVERED_GATEWAY_CRDS[*]}"
  fi
  
  if (( ${#DISCOVERED_TRAEFIK_CRDS[@]} > 0 )); then
    info "Found Traefik CRDs: ${DISCOVERED_TRAEFIK_CRDS[*]}"
  fi
  
  if (( ${#TRAEFIK_HUB_CRDS[@]} > 0 )); then
    info "Found Traefik Hub CRDs: ${TRAEFIK_HUB_CRDS[*]}"
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
info "drunk-k8s-gateway Uninstallation"
info "========================================="
info "Release:   $RELEASE_NAME"
info "Namespace: $NAMESPACE"

# Discover all related CRDs in the cluster
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

# Delete Traefik Gateway API RBAC
if [[ "$DELETE_TRAEFIK_RBAC" == "true" ]]; then
  echo ""
  if confirm "Delete Traefik Gateway API RBAC? This will affect all Traefik Gateway API resources."; then
    info "Deleting Traefik Gateway API RBAC..."
    if curl -fsSL "$TRAEFIK_RBAC_URL" | kubectl delete -f - 2>&1 | grep -v "NotFound"; then
      success "Traefik Gateway API RBAC deleted successfully"
    else
      warn "Traefik Gateway API RBAC not found or already deleted"
    fi
  fi
fi

# Delete Traefik Custom CRDs
if [[ "$DELETE_CRDS" == "true" ]]; then
  echo ""
  if confirm "Delete Traefik Custom CRDs (traefik.io)? WARNING: This will delete ALL Traefik custom resources cluster-wide!"; then
    info "Deleting Traefik Custom CRDs..."
    
    # Use discovered CRDs instead of hardcoded list
    existing_traefik_crds=("${DISCOVERED_TRAEFIK_CRDS[@]}")
    
    if (( ${#existing_traefik_crds[@]} > 0 )); then
      info "Found Traefik CRDs to delete: ${existing_traefik_crds[*]}"
      if kubectl delete crd "${existing_traefik_crds[@]}" 2>&1 | grep -v "NotFound"; then
        success "Traefik Custom CRDs deleted successfully"
        info "Waiting for CRD deletion to complete..."
        sleep 3
      else
        warn "Some Traefik CRDs may not have been deleted"
      fi
    else
      info "No Traefik Custom CRDs found"
  
      # Delete Traefik Hub CRDs
      if (( ${#TRAEFIK_HUB_CRDS[@]} > 0 )); then
        echo ""
        if confirm "Delete Traefik Hub CRDs (hub.traefik.io)? WARNING: This will delete ALL Traefik Hub resources cluster-wide!"; then
          info "Deleting Traefik Hub CRDs..."
          info "Found Traefik Hub CRDs to delete: ${TRAEFIK_HUB_CRDS[*]}"
          if kubectl delete crd "${TRAEFIK_HUB_CRDS[@]}" 2>&1 | grep -v "NotFound"; then
            success "Traefik Hub CRDs deleted successfully"
            info "Waiting for CRD deletion to complete..."
            sleep 3
          else
            warn "Some Traefik Hub CRDs may not have been deleted"
          fi
        fi
      fi
    fi
  fi
fi

# Delete Gateway API CRDs
if [[ "$DELETE_CRDS" == "true" ]]; then
  echo ""
  if confirm "Delete Gateway API CRDs? WARNING: This will delete ALL Gateway resources cluster-wide!"; then
    info "Deleting Gateway API CRDs..."
    
    # Use discovered CRDs instead of hardcoded list
    existing_crds=("${DISCOVERED_GATEWAY_CRDS[@]}")
    
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
info "To completely remove Gateway API CRDs (if not already deleted):"
echo "  DELETE_CRDS=true ./uninstall.sh"
echo ""
info "To remove namespace and all resources:"
echo "  DELETE_NAMESPACE=true ./uninstall.sh"
echo ""
info "To remove everything without confirmations:"
echo "  FORCE=true DELETE_CRDS=true DELETE_NAMESPACE=true DELETE_TRAEFIK_RBAC=true ./uninstall.sh"
echo ""
