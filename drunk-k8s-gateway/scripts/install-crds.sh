#!/bin/bash
# Script to install Gateway API CRDs
# Author: Duy Bao (baoduy)
# Repository: https://github.com/baoduy/drunk.charts

set -e

# Default values
VERSION="${GATEWAY_API_VERSION:-v1.2.0}"
CHANNEL="${GATEWAY_API_CHANNEL:-standard}"
DRY_RUN="${DRY_RUN:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored message
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

# Display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Install Kubernetes Gateway API CRDs

OPTIONS:
    -v, --version VERSION    Gateway API version (default: v1.2.0)
    -c, --channel CHANNEL    Installation channel: standard or experimental (default: standard)
    -d, --dry-run            Show what would be installed without applying
    -h, --help               Display this help message

ENVIRONMENT VARIABLES:
    GATEWAY_API_VERSION      Gateway API version to install
    GATEWAY_API_CHANNEL      Installation channel (standard or experimental)
    DRY_RUN                  Set to 'true' for dry-run mode

EXAMPLES:
    # Install standard Gateway API v1.2.0 (default)
    $0

    # Install specific version
    $0 --version v1.1.0

    # Install experimental channel (includes GRPC, TCP, TLS, UDP routes)
    $0 --channel experimental

    # Dry run to see what would be installed
    $0 --dry-run

    # Using environment variables
    GATEWAY_API_VERSION=v1.2.0 GATEWAY_API_CHANNEL=experimental $0

EOF
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -c|--channel)
            CHANNEL="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN="true"
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate channel
if [[ "$CHANNEL" != "standard" && "$CHANNEL" != "experimental" ]]; then
    print_error "Invalid channel: $CHANNEL. Must be 'standard' or 'experimental'"
    exit 1
fi

# Construct URL
URL="https://github.com/kubernetes-sigs/gateway-api/releases/download/${VERSION}/${CHANNEL}-install.yaml"

print_info "Gateway API CRD Installation"
echo "================================"
echo "Version: $VERSION"
echo "Channel: $CHANNEL"
echo "URL: $URL"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check cluster connectivity
print_info "Checking cluster connectivity..."
if ! kubectl cluster-info &> /dev/null; then
    print_error "Unable to connect to Kubernetes cluster"
    print_info "Please ensure kubectl is configured correctly"
    exit 1
fi

print_success "Connected to cluster"
echo ""

# Check existing CRDs
print_info "Checking for existing Gateway API CRDs..."
EXISTING_CRDS=$(kubectl get crd -o name 2>/dev/null | grep -E "gateway.networking.k8s.io" || true)

if [[ -n "$EXISTING_CRDS" ]]; then
    print_warning "Found existing Gateway API CRDs:"
    echo "$EXISTING_CRDS" | sed 's/^/  /'
    echo ""
    
    # Get current version if available
    CURRENT_VERSION=$(kubectl get crd gateways.gateway.networking.k8s.io -o jsonpath='{.metadata.labels.gateway\.networking\.k8s\.io/bundle-version}' 2>/dev/null || echo "unknown")
    print_info "Current version: $CURRENT_VERSION"
    
    read -p "Do you want to upgrade/reinstall? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Installation cancelled"
        exit 0
    fi
fi

# Download and display CRDs if dry-run
if [[ "$DRY_RUN" == "true" ]]; then
    print_info "DRY RUN MODE - Downloading and displaying CRDs (not applying)"
    echo ""
    
    print_info "Fetching CRDs from $URL..."
    MANIFEST=$(curl -sL "$URL")
    
    if [[ -z "$MANIFEST" ]]; then
        print_error "Failed to fetch CRDs from $URL"
        exit 1
    fi
    
    print_success "Successfully fetched CRDs"
    echo ""
    print_info "CRDs that would be installed:"
    echo "$MANIFEST" | grep "^kind: CustomResourceDefinition" -A 2 | grep "name:" | awk '{print "  - " $2}'
    echo ""
    print_info "To install, run without --dry-run flag"
    exit 0
fi

# Install CRDs
print_info "Installing Gateway API CRDs..."
echo ""

if kubectl apply -f "$URL"; then
    print_success "Gateway API CRDs installed successfully!"
    echo ""
    
    # Wait for CRDs to be established
    print_info "Waiting for CRDs to be established..."
    sleep 2
    
    # Verify installation
    print_info "Verifying installed CRDs..."
    INSTALLED_CRDS=$(kubectl get crd -o name | grep -E "gateway.networking.k8s.io" || true)
    
    if [[ -n "$INSTALLED_CRDS" ]]; then
        print_success "Installed CRDs:"
        echo "$INSTALLED_CRDS" | sed 's/^/  /'
        echo ""
        
        # Get version
        VERSION_LABEL=$(kubectl get crd gateways.gateway.networking.k8s.io -o jsonpath='{.metadata.labels.gateway\.networking\.k8s\.io/bundle-version}' 2>/dev/null || echo "unknown")
        print_success "Bundle version: $VERSION_LABEL"
        
        # Display next steps
        echo ""
        print_success "Installation complete!"
        echo ""
        print_info "Next steps:"
        echo "  1. Install a Gateway controller (e.g., NGINX Gateway Fabric, Istio, etc.)"
        echo "  2. Create a GatewayClass resource"
        echo "  3. Create Gateway and HTTPRoute resources"
        echo ""
        print_info "To install using drunk-k8s-gateway chart:"
        echo "  helm install gateway drunk-charts/drunk-k8s-gateway"
        
    else
        print_error "CRDs were not installed correctly"
        exit 1
    fi
else
    print_error "Failed to install Gateway API CRDs"
    exit 1
fi
