# Quick Start Guide

Get started with drunk-k8s-gateway in minutes!

## Prerequisites

- Kubernetes cluster (1.25+)
- kubectl configured
- Helm 3.8+

## Step 1: Install Gateway API CRDs

**Option A: Install with Helm (Recommended - CRDs included in chart)**

The Gateway API CRDs are now automatically included when you install the chart:

```bash
# CRDs will be installed automatically
helm install gateway drunk-charts/drunk-k8s-gateway \
  -n gateway-system \
  --create-namespace
```

Skip to Step 2 if using this option.

**Option B: Install CRDs separately**

If you prefer to manage CRDs separately:

```bash
cd scripts
chmod +x install-crds.sh
./install-crds.sh
```

Verify:

```bash
kubectl get crd | grep gateway
```

## Step 2: Install Gateway Controller

### Option A: Traefik via Vendored Chart (Recommended for K3s/Local)

Install everything in one command using values.local.yaml:

```bash
helm upgrade --install gateway ./drunk-k8s-gateway \
  -n drunk-gateway --create-namespace \
  -f values.local.yaml
```

### Option B: Traefik Separately

```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm install traefik traefik/traefik \
  --namespace traefik --create-namespace \
  --set experimental.kubernetesGateway.enabled=true \
  --set providers.kubernetesGateway.enabled=true
```

### Option C: Istio

```bash
istioctl install --set profile=default
```

## Step 3: (Optional) Install cert-manager

For automatic TLS certificate management, choose one option:

### Option A: Install with the chart (Recommended)

cert-manager will be installed automatically as a dependency:

```bash
# Install with cert-manager included
helm install gateway . \
  --set certManager.enabled=true \
  --set certManager.installCRDs=true \
  -f examples/drunk-dev-domain.yaml \
  -n default
```

### Option B: Install separately

```bash
helm install cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --version v1.19.1 \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true
```

Verify:

```bash
kubectl get pods -n cert-manager
```

## Step 4: Install drunk-k8s-gateway

### For drunk.dev domain:

```bash
# Without cert-manager (if installed separately or not needed)
helm install gateway . \
  -f examples/drunk-dev-domain.yaml \
  -n default

# With cert-manager as dependency
helm install gateway . \
  --set certManager.enabled=true \
  --set certManager.installCRDs=true \
  -f examples/drunk-dev-domain.yaml \
  -n default
```

### For basic shared Gateway:

```bash
helm install gateway . \
  -f examples/basic-gateway.yaml \
  -n gateway-system \
  --create-namespace
```

## Step 5: Verify Installation

```bash
# Check GatewayClass
kubectl get gatewayclass

# Check Gateway
kubectl get gateway -A

# Get Gateway address
kubectl get gateway <gateway-name> -o jsonpath='{.status.addresses[0].value}'
```

## Step 6: Deploy an Application

Use drunk-app to deploy with HTTPRoute:

```bash
helm install myapp drunk-charts/drunk-app \
  --set httpRoute.enabled=true \
  --set httpRoute.parentRefs[0].name=drunk-dev-gateway \
  --set httpRoute.hostnames[0]=myapp.drunk.dev
```

## Next Steps

- See [README.md](README.md) for full documentation
- Check [examples/](examples/) for more configurations
- Read [nginx-to-gateway-migration.md](../docs/nginx-to-gateway-migration.md) for migration guide

## Troubleshooting

If Gateway is not ready:

```bash
kubectl describe gateway <gateway-name>
kubectl logs -n gateway-system -l app=gateway-controller
```

## Uninstall

```bash
# Remove chart
helm uninstall gateway

# Remove CRDs (WARNING: deletes all Gateway resources)
./scripts/uninstall-crds.sh
```
