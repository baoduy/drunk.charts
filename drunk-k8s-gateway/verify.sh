#!/bin/bash
# Verify drunk-k8s-gateway chart
# Author: Duy Bao (baoduy)
# Repository: https://github.com/baoduy/drunk.charts

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="$SCRIPT_DIR"

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

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

ERRORS=0

echo "========================================"
echo "drunk-k8s-gateway Chart Verification"
echo "========================================"
echo ""

# Test 1: Lint the chart
print_info "Running helm lint..."
if helm lint "$CHART_DIR"; then
    print_success "Helm lint passed"
else
    print_error "Helm lint failed"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Test 2: Validate Chart.yaml
print_info "Validating Chart.yaml..."
if [[ -f "$CHART_DIR/Chart.yaml" ]]; then
    print_success "Chart.yaml exists"
    
    # Check required fields
    if grep -q "^name: drunk-k8s-gateway" "$CHART_DIR/Chart.yaml"; then
        print_success "Chart name is correct"
    else
        print_error "Chart name is incorrect"
        ERRORS=$((ERRORS + 1))
    fi
    
    if grep -q "^version:" "$CHART_DIR/Chart.yaml"; then
        VERSION=$(grep "^version:" "$CHART_DIR/Chart.yaml" | awk '{print $2}')
        print_success "Chart version: $VERSION"
    else
        print_error "Chart version is missing"
        ERRORS=$((ERRORS + 1))
    fi
else
    print_error "Chart.yaml not found"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Test 3: Check dependencies
print_info "Checking chart dependencies..."
if helm dependency list "$CHART_DIR" | grep -q "traefik"; then
    print_success "traefik dependency found"
else
    print_error "traefik dependency missing"
    ERRORS=$((ERRORS + 1))
fi
if helm dependency list "$CHART_DIR" | grep -q "cert-manager"; then
    print_success "cert-manager dependency found"
else
    print_error "cert-manager dependency missing"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Test 4: Verify templates exist
print_info "Verifying templates..."
REQUIRED_TEMPLATES=(
    "templates/_helpers.tpl"
    "templates/NOTES.txt"
    "templates/domain-gateways.yaml"
    "templates/clusterissuer.yaml"
)

for template in "${REQUIRED_TEMPLATES[@]}"; do
    if [[ -f "$CHART_DIR/$template" ]]; then
        print_success "$template exists"
    else
        print_error "$template is missing"
        ERRORS=$((ERRORS + 1))
    fi
done
echo ""

# Test 5: Template rendering tests
print_info "Testing template rendering..."

# Test default values
if helm template test "$CHART_DIR" > /dev/null 2>&1; then
    print_success "Default values render correctly"
else
    print_error "Failed to render with default values"
    ERRORS=$((ERRORS + 1))
fi

# Test with GatewayClass enabled
if helm template test "$CHART_DIR" --set gatewayClass.enabled=true > /dev/null 2>&1; then
    print_success "GatewayClass enabled renders correctly"
else
    print_error "Failed to render with GatewayClass enabled"
    ERRORS=$((ERRORS + 1))
fi

# Test with Gateway enabled
if helm template test "$CHART_DIR" --set gateway.enabled=true > /dev/null 2>&1; then
    print_success "Gateway enabled renders correctly"
else
    print_error "Failed to render with Gateway enabled"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Test 6: Verify scripts
print_info "Verifying scripts..."
if [[ -f "$CHART_DIR/install.sh" ]]; then
    print_success "install.sh exists"
    if [[ -x "$CHART_DIR/install.sh" ]]; then
        print_success "install.sh is executable"
    else
        print_error "install.sh is not executable"
        ERRORS=$((ERRORS + 1))
    fi
else
    print_error "install.sh is missing"
    ERRORS=$((ERRORS + 1))
fi

if [[ -f "$CHART_DIR/uninstall.sh" ]]; then
    print_success "uninstall.sh exists"
    if [[ -x "$CHART_DIR/uninstall.sh" ]]; then
        print_success "uninstall.sh is executable"
    else
        print_error "uninstall.sh is not executable"
        ERRORS=$((ERRORS + 1))
    fi
else
    print_error "uninstall.sh is missing"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Test 7: Validate values.yaml structure
print_info "Validating values.yaml structure..."
if [[ -f "$CHART_DIR/values.yaml" ]]; then
    print_success "values.yaml exists"
    
    # Check for key sections
    REQUIRED_KEYS=("gatewayAPI" "gatewayClass" "gateway" "domains" "certManager")
    for key in "${REQUIRED_KEYS[@]}"; do
        if grep -q "^$key:" "$CHART_DIR/values.yaml"; then
            print_success "$key section found"
        else
            print_error "$key section missing"
            ERRORS=$((ERRORS + 1))
        fi
    done
else
    print_error "values.yaml not found"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Test 8: Test specific scenarios
print_info "Testing specific scenarios..."

# Scenario 1: cert-manager integration
RENDERED=$(helm template test "$CHART_DIR" \
    --set certManager.clusterIssuersEnabled=true \
    --set 'certManager.clusterIssuers[0].name=test-issuer' \
    --set 'certManager.clusterIssuers[0].email=test@example.com' \
    --set 'certManager.clusterIssuers[0].server=https://acme.example.com' \
    --set 'certManager.clusterIssuers[0].privateKeySecretRef.name=test-key' \
    --set 'certManager.clusterIssuers[0].solvers[0].http01.gatewayHTTPRoute.parentRefs[0].name=test-gateway' 2>&1)

if echo "$RENDERED" | grep -q "kind: ClusterIssuer"; then
    print_success "cert-manager ClusterIssuer renders correctly"
else
    print_error "cert-manager ClusterIssuer failed to render"
    ERRORS=$((ERRORS + 1))
fi

# Scenario 2: Multiple domains
RENDERED=$(helm template test "$CHART_DIR" \
    --set 'domains[0].name=domain1' \
    --set 'domains[0].enabled=true' \
    --set 'domains[0].gatewayClassName=nginx' 2>&1)

if echo "$RENDERED" | grep -q "domain1-gateway"; then
    print_success "Domain-specific Gateway renders correctly"
else
    print_error "Domain-specific Gateway failed to render"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Summary
echo "========================================"
if [[ $ERRORS -eq 0 ]]; then
    print_success "All verification tests passed!"
    echo ""
    print_info "Chart is ready for deployment"
    exit 0
else
    print_error "Verification failed with $ERRORS error(s)"
    echo ""
    print_info "Please fix the errors before deploying"
    exit 1
fi
