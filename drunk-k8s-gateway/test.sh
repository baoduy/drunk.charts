#!/bin/bash
# Test script for drunk-k8s-gateway chart
# Author: Duy Bao (baoduy)
# Repository: https://github.com/baoduy/drunk.charts

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="$SCRIPT_DIR"
TEST_NAMESPACE="gateway-test"
RELEASE_NAME="test-gateway"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Cleanup function
cleanup() {
    print_info "Cleaning up test resources..."
    helm uninstall "$RELEASE_NAME" -n "$TEST_NAMESPACE" 2>/dev/null || true
    kubectl delete namespace "$TEST_NAMESPACE" 2>/dev/null || true
    print_success "Cleanup complete"
}

# Set trap for cleanup
trap cleanup EXIT

echo "========================================"
echo "drunk-k8s-gateway Chart Testing"
echo "========================================"
echo ""

# Check prerequisites
print_info "Checking prerequisites..."
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed"
    exit 1
fi

if ! command -v helm &> /dev/null; then
    print_error "helm is not installed"
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

print_success "Prerequisites met"
echo ""

# Create test namespace
print_info "Creating test namespace..."
kubectl create namespace "$TEST_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
print_success "Test namespace created"
echo ""

# Test 1: Install with minimal configuration
print_info "Test 1: Installing with minimal configuration..."
helm install "$RELEASE_NAME" "$CHART_DIR" \
    -n "$TEST_NAMESPACE" \
    --set gatewayClass.enabled=true \
    --set gatewayClass.name=test-gateway-class \
    --wait

if kubectl get gatewayclass test-gateway-class &> /dev/null; then
    print_success "GatewayClass created successfully"
else
    print_error "GatewayClass was not created"
    exit 1
fi
echo ""

# Test 2: Upgrade with Gateway enabled
print_info "Test 2: Upgrading with Gateway enabled..."
helm upgrade "$RELEASE_NAME" "$CHART_DIR" \
    -n "$TEST_NAMESPACE" \
    --set gatewayClass.enabled=true \
    --set gatewayClass.name=test-gateway-class \
    --set gateway.enabled=true \
    --set gateway.name=test-gateway \
    --set gateway.gatewayClassName=test-gateway-class \
    --wait

if kubectl get gateway test-gateway -n "$TEST_NAMESPACE" &> /dev/null; then
    print_success "Gateway created successfully"
else
    print_error "Gateway was not created"
    exit 1
fi
echo ""

# Test 3: Check Gateway status
print_info "Test 3: Checking Gateway status..."
kubectl describe gateway test-gateway -n "$TEST_NAMESPACE"
echo ""

# Test 4: Test domain-specific Gateway
print_info "Test 4: Testing domain-specific Gateway..."
helm upgrade "$RELEASE_NAME" "$CHART_DIR" \
    -n "$TEST_NAMESPACE" \
    --set gatewayClass.enabled=true \
    --set gatewayClass.name=test-gateway-class \
    --set 'domains[0].name=test-domain' \
    --set 'domains[0].enabled=true' \
    --set 'domains[0].gatewayClassName=test-gateway-class' \
    --wait

if kubectl get gateway test-domain-gateway -n "$TEST_NAMESPACE" &> /dev/null; then
    print_success "Domain-specific Gateway created successfully"
else
    print_error "Domain-specific Gateway was not created"
    exit 1
fi
echo ""

# Test 5: Verify all resources
print_info "Test 5: Verifying all resources..."
print_info "GatewayClasses:"
kubectl get gatewayclass
echo ""

print_info "Gateways in test namespace:"
kubectl get gateway -n "$TEST_NAMESPACE"
echo ""

print_info "All Gateways in cluster:"
kubectl get gateway -A
echo ""

# Summary
echo "========================================"
print_success "All tests passed!"
echo ""
print_info "Test resources will be cleaned up automatically"
print_info "To keep test resources, press Ctrl+C now"
sleep 3
