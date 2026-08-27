#!/bin/bash
# Verify drunk-cloudflare-tunnel-gateway chart
# Author: Duy Bao (baoduy)
# Repository: https://github.com/baoduy/drunk.charts

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="$SCRIPT_DIR"

# The vendored cloudflare-tunnel-gateway-controller subchart hard-`required`s
# gatewayClassConfig.tunnelID when create: true. The shipped default is
# intentionally empty (real deploys must set it explicitly), so every lint
# and render call below supplies this dummy value.
DUMMY_TUNNEL_ID="00000000-0000-0000-0000-000000000000"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

print_success() {
    echo -e "${GREEN}[OK]   $1${NC}"
}

print_error() {
    echo -e "${RED}[FAIL] $1${NC}"
}

ERRORS=0

echo "========================================"
echo "drunk-cloudflare-tunnel-gateway Chart Verification"
echo "========================================"
echo ""

# Test 1: Lint the chart
print_info "Running helm lint..."
if helm lint "$CHART_DIR" --set cloudflareTunnel.gatewayClassConfig.tunnelID="$DUMMY_TUNNEL_ID"; then
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

    if grep -q "^name: drunk-cloudflare-tunnel-gateway" "$CHART_DIR/Chart.yaml"; then
        print_success "Chart name is correct"
    else
        print_error "Chart name is incorrect (expected: drunk-cloudflare-tunnel-gateway)"
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
if helm dependency list "$CHART_DIR" | grep -q "cloudflare-tunnel-gateway-controller"; then
    print_success "cloudflare-tunnel-gateway-controller dependency found"
else
    print_error "cloudflare-tunnel-gateway-controller dependency missing"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Test 4: Verify templates exist
print_info "Verifying templates..."
REQUIRED_TEMPLATES=(
    "templates/_helpers.tpl"
    "templates/NOTES.txt"
    "templates/domain-gateways.yaml"
)

for template in "${REQUIRED_TEMPLATES[@]}"; do
    if [[ -f "$CHART_DIR/$template" ]]; then
        print_success "$template exists"
    else
        print_error "$template is missing"
        ERRORS=$((ERRORS + 1))
    fi
done

# The subchart owns the GatewayClass — this chart must not ship its own.
if [[ -f "$CHART_DIR/templates/gatewayclass.yaml" ]]; then
    print_error "templates/gatewayclass.yaml exists (GatewayClass is owned by the cloudflareTunnel subchart)"
    ERRORS=$((ERRORS + 1))
else
    print_success "templates/gatewayclass.yaml absent (as expected)"
fi
echo ""

# Test 5: Template rendering tests
print_info "Building chart dependencies..."
if helm dependency build "$CHART_DIR" > /dev/null 2>&1; then
    print_success "helm dependency build succeeded"
else
    print_error "helm dependency build failed (OCI subchart unavailable)"
    ERRORS=$((ERRORS + 1))
fi
echo ""

print_info "Testing template rendering..."

if helm template test "$CHART_DIR" --set cloudflareTunnel.gatewayClassConfig.tunnelID="$DUMMY_TUNNEL_ID" > /dev/null 2>&1; then
    print_success "Default values render correctly"
else
    print_error "Failed to render with default values"
    ERRORS=$((ERRORS + 1))
fi

# Subchart should render its GatewayClassConfig
if helm template test "$CHART_DIR" --set cloudflareTunnel.gatewayClassConfig.tunnelID="$DUMMY_TUNNEL_ID" 2>/dev/null | grep -q "kind: GatewayClassConfig"; then
    print_success "GatewayClassConfig renders from subchart"
else
    print_error "GatewayClassConfig missing in default render"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Test 6: Verify scripts
print_info "Verifying scripts..."
for script in install.sh uninstall.sh build.sh; do
    if [[ -f "$CHART_DIR/$script" ]]; then
        print_success "$script exists"
        if [[ -x "$CHART_DIR/$script" ]]; then
            print_success "$script is executable"
        else
            print_error "$script is not executable"
            ERRORS=$((ERRORS + 1))
        fi
    else
        print_error "$script is missing"
        ERRORS=$((ERRORS + 1))
    fi
done
echo ""

# Test 7: Validate values.yaml structure
print_info "Validating values.yaml structure..."
if [[ -f "$CHART_DIR/values.yaml" ]]; then
    print_success "values.yaml exists"

    REQUIRED_KEYS=("gatewayAPI" "domains" "routeAccess" "cloudflareTunnel")
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

# Test 8: Specific scenarios
print_info "Testing specific scenarios..."

# Scenario: Multiple domain gateways
RENDERED=$(helm template test "$CHART_DIR" \
    --set cloudflareTunnel.gatewayClassConfig.tunnelID="$DUMMY_TUNNEL_ID" \
    --set 'domains[0].name=domain1' \
    --set 'domains[0].enabled=true' \
    --set 'domains[0].gatewayClassName=cloudflare-tunnel' \
    --set 'domains[0].listeners[0].name=http' \
    --set 'domains[0].listeners[0].protocol=HTTP' \
    --set 'domains[0].listeners[0].port=80' \
    --set 'domains[0].listeners[0].hostname=*.example.com' 2>&1 || true)

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
