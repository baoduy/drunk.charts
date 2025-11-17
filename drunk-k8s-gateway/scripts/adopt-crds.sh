#!/bin/bash
# Adopt pre-existing Gateway API CRDs into the Helm release by adding Helm ownership
# annotations and labels so helm install/upgrade no longer fails.
# Usage:
#   ./scripts/adopt-crds.sh gateway drunk-gateway
# Where first arg is the intended Helm release name, second is the namespace.

set -euo pipefail

RELEASE_NAME="${1:-gateway}"
RELEASE_NS="${2:-drunk-gateway}"

CRDS=(
  gatewayclasses.gateway.networking.k8s.io
  gateways.gateway.networking.k8s.io
  httproutes.gateway.networking.k8s.io
  tcproutes.gateway.networking.k8s.io
  tlsroutes.gateway.networking.k8s.io
  udproutes.gateway.networking.k8s.io
  grpcroutes.gateway.networking.k8s.io
  referencegrants.gateway.networking.k8s.io
)

echo "Adopting Gateway API CRDs for Helm release: $RELEASE_NAME (namespace: $RELEASE_NS)"
for crd in "${CRDS[@]}"; do
  if kubectl get crd "$crd" >/dev/null 2>&1; then
    echo "  -> Patching $crd"
    kubectl patch crd "$crd" --type merge -p "{\"metadata\":{\"annotations\":{\"meta.helm.sh/release-name\":\"$RELEASE_NAME\",\"meta.helm.sh/release-namespace\":\"$RELEASE_NS\"},\"labels\":{\"app.kubernetes.io/managed-by\":\"Helm\"}}}"
  else
    echo "  -> CRD $crd not found (skipping)"
  fi
done

echo "Done. You can now run: helm upgrade --install $RELEASE_NAME ./drunk-k8s-gateway -n $RELEASE_NS --create-namespace -f values.local.yaml"
