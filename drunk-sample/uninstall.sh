#!/bin/bash
# Uninstall sample application
set -euo pipefail

SAMPLE_APP_NAMESPACE="${SAMPLE_APP_NAMESPACE:-drunk-dev-apps}"
SAMPLE_APP_NAME="${SAMPLE_APP_NAME:-dotnet-sample}"

info() { echo -e "\033[34m[INFO]\033[0m $*"; }
success() { echo -e "\033[32m[SUCCESS]\033[0m $*"; }

echo ""
info "Uninstalling sample application..."
info "App:       $SAMPLE_APP_NAME"
info "Namespace: $SAMPLE_APP_NAMESPACE"
echo ""

helm uninstall "$SAMPLE_APP_NAME" -n "$SAMPLE_APP_NAMESPACE" || true

success "Sample application uninstalled!"
echo ""
info "To also delete the namespace:"
echo "  kubectl delete namespace $SAMPLE_APP_NAMESPACE"
echo ""
