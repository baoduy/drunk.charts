#!/bin/bash
# Script to uninstall Gateway API CRDs
# Author: Duy Bao (baoduy)
# Repository: https://github.com/baoduy/drunk.charts

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning "This will remove ALL Gateway API CRDs and related resources!"
print_info "This includes:"
echo "  - GatewayClasses"
echo "  - Gateways"
echo "  - HTTPRoutes"
echo "  - All other Gateway API resources"
echo ""

read -p "Are you sure you want to continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Uninstallation cancelled"
    exit 0
fi

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# List existing resources before deletion
print_info "Listing existing Gateway API resources..."
kubectl get gatewayclasses -A 2>/dev/null || true
kubectl get gateways -A 2>/dev/null || true
kubectl get httproutes -A 2>/dev/null || true
echo ""

print_info "Deleting Gateway API CRDs..."
kubectl delete crd -l gateway.networking.k8s.io/bundle-version 2>/dev/null || \
kubectl delete crd \
  gatewayclasses.gateway.networking.k8s.io \
  gateways.gateway.networking.k8s.io \
  httproutes.gateway.networking.k8s.io \
  referencegrants.gateway.networking.k8s.io \
  grpcroutes.gateway.networking.k8s.io \
  tcproutes.gateway.networking.k8s.io \
  tlsroutes.gateway.networking.k8s.io \
  udproutes.gateway.networking.k8s.io \
  2>/dev/null || true

print_success "Gateway API CRDs removed"
