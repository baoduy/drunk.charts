#!/bin/bash
# Deploy sample .NET application to test the drunk-k8s-gateway
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DRUNK_APP_DIR="$SCRIPT_DIR/../drunk-app"
SAMPLE_APP_NAMESPACE="${SAMPLE_APP_NAMESPACE:-drunk-dev-apps}"
SAMPLE_APP_NAME="${SAMPLE_APP_NAME:-dotnet-sample}"
GATEWAY_NAMESPACE="${GATEWAY_NAMESPACE:-drunk-gateway}"
GATEWAY_LABEL_KEY="${GATEWAY_LABEL_KEY:-gateway.drunk.charts/access}"
GATEWAY_LABEL_VALUE="${GATEWAY_LABEL_VALUE:-drunk-dev-gateway}"

info() { echo -e "\033[34m[INFO]\033[0m $*"; }
warn() { echo -e "\033[33m[WARN]\033[0m $*"; }
error() { echo -e "\033[31m[ERROR]\033[0m $*"; }
success() { echo -e "\033[32m[SUCCESS]\033[0m $*"; }

if [[ ! -d "$DRUNK_APP_DIR" ]]; then
  error "drunk-app chart not found at $DRUNK_APP_DIR"
  error "Please ensure drunk-app is in the parent directory"
  exit 1
fi

echo ""
info "========================================="
info "Deploy Sample Application"
info "========================================="
info "App:       $SAMPLE_APP_NAME"
info "Namespace: $SAMPLE_APP_NAMESPACE"
info "Gateway:   drunk-dev-gateway ($GATEWAY_NAMESPACE)"
info "========================================="
echo ""

# Create namespace if not exists
if ! kubectl get namespace "$SAMPLE_APP_NAMESPACE" >/dev/null 2>&1; then
  info "Creating namespace: $SAMPLE_APP_NAMESPACE"
  kubectl create namespace "$SAMPLE_APP_NAMESPACE"
else
  info "Namespace $SAMPLE_APP_NAMESPACE already exists"
fi

# Label namespace for Gateway access
info "Labeling namespace for Gateway access..."
kubectl label namespace "$SAMPLE_APP_NAMESPACE" "$GATEWAY_LABEL_KEY=$GATEWAY_LABEL_VALUE" --overwrite

# Install the sample app
info "Installing sample application using drunk-app chart..."
helm upgrade --install "$SAMPLE_APP_NAME" "$DRUNK_APP_DIR" \
  --namespace "$SAMPLE_APP_NAMESPACE" \
  --values "$SCRIPT_DIR/values.yaml"

success "Sample application deployed successfully!"

echo ""
info "Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=120s \
  deployment/"$SAMPLE_APP_NAME" -n "$SAMPLE_APP_NAMESPACE" || warn "Timeout waiting for deployment"

echo ""
success "========================================="
success "Deployment Complete!"
success "========================================="
echo ""
info "Verify the deployment:"
echo "  kubectl get pods -n $SAMPLE_APP_NAMESPACE"
echo "  kubectl get svc -n $SAMPLE_APP_NAMESPACE"
echo "  kubectl get httproute -n $SAMPLE_APP_NAMESPACE"
echo ""
info "Check HTTPRoute status:"
echo "  kubectl describe httproute $SAMPLE_APP_NAME -n $SAMPLE_APP_NAMESPACE"
echo ""
info "Add to /etc/hosts:"
echo "  echo '127.0.0.1 dotnet-sample.dev.local' | sudo tee -a /etc/hosts"
echo ""
info "Get Gateway address:"
echo "  kubectl get gateway drunk-dev-gateway -n $GATEWAY_NAMESPACE"
echo ""
info "Test the application:"
echo "  # If using minikube"
echo "  minikube tunnel  # In a separate terminal"
echo "  curl http://dotnet-sample.dev.local"
echo ""
echo "  # If using port-forward"
echo "  kubectl port-forward -n $GATEWAY_NAMESPACE svc/drunk-dev-gateway 8080:80"
echo "  curl http://dotnet-sample.dev.local:8080"
echo ""
info "View logs:"
echo "  kubectl logs -n $SAMPLE_APP_NAMESPACE -l app=$SAMPLE_APP_NAME --tail=50 -f"
echo ""
