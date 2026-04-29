# Quick Start Guide

Get started with drunk-nginx-gateway in minutes.

## Prerequisites

- Kubernetes cluster (1.25+)
- kubectl configured
- Helm 3.8+

## One-shot install (recommended)

The included `install.sh` performs the two-phase install (Gateway API CRDs via
`kubectl`, then the chart via Helm) and uses `values.local.yaml`:

```bash
cd drunk-nginx-gateway
./install.sh
```

Defaults: `RELEASE_NAME=nginx-gateway`, `NAMESPACE=drunk-nginx-gateway`.

## Manual install (Helm)

### Step 1: Install Gateway API CRDs

The Gateway API CRDs are too large for Helm's annotation limit, so install them
separately with `kubectl`:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
```

Verify:

```bash
kubectl get crd | grep gateway
```

### Step 2: Install the chart with the vendored NGINX Gateway Fabric subchart

```bash
helm dependency update ./drunk-nginx-gateway   # pulls nginx-gateway-fabric (OCI)
helm upgrade --install nginx-gateway ./drunk-nginx-gateway \
  -n drunk-nginx-gateway --create-namespace \
  -f ./drunk-nginx-gateway/values.local.yaml
```

### Step 3: (Optional) cert-manager

`values.local.yaml` enables cert-manager with a self-signed ClusterIssuer for
local TLS testing. For production, swap in a real ACME issuer (see
`CERT-MANAGER-TESTING.md`).

## Azure AKS install (internal Load Balancer)

For deployments to Azure AKS that need an **internal** Azure Load Balancer
(private IP, not exposed to the public internet), use `values.aks.yaml`:

```bash
helm dependency update ./drunk-nginx-gateway
helm upgrade --install nginx-gateway ./drunk-nginx-gateway \
  -n drunk-nginx-gateway --create-namespace \
  -f ./drunk-nginx-gateway/values.aks.yaml
```

Before installing, edit `values.aks.yaml` and replace the `loadBalancerIP`
placeholder (`192.168.130.250`) with a free IP in your AKS subnet. To pin
the LB to a specific subnet, uncomment the
`service.beta.kubernetes.io/azure-load-balancer-internal-subnet`
annotation and set its value to your subnet name.

> **Note:** NGF 2.5.1 requires the internal-LB annotation to be applied via
> `nginx.service.patches` (StrategicMerge), not `nginx.service.annotations`,
> because the NginxProxy CRD prunes unknown fields. `values.aks.yaml` already
> uses the correct `patches` form — leave the structure as-is when customizing.

## Verify

```bash
kubectl get gatewayclass                                      # expect 'nginx'
kubectl get pods -n drunk-nginx-gateway                       # NGF pod Ready
kubectl get gateway -A                                        # programmed
kubectl get crd | grep nginx.org                              # NginxProxy + NginxGateway
```

## Deploy a sample app

Using `drunk-app` with HTTPRoute targeting the local Gateway:

```bash
helm install myapp drunk-charts/drunk-app \
  --set httpRoute.enabled=true \
  --set httpRoute.parentRefs[0].name=drunk-dev-gateway \
  --set httpRoute.hostnames[0]=myapp.dev.local
```

Map `myapp.dev.local` to your node IP in `/etc/hosts` and curl:

```bash
curl -H "Host: myapp.dev.local" http://<node-ip>:30080/
```

## Troubleshooting

If Gateway is not ready:

```bash
kubectl describe gateway <gateway-name>
kubectl logs -n drunk-nginx-gateway -l app.kubernetes.io/name=nginx-gateway-fabric
```

## Uninstall

```bash
./uninstall.sh                          # release + NGF/Gateway API CRDs (with confirmation)
FORCE=true ./uninstall.sh               # no prompts
DELETE_CRDS=false ./uninstall.sh        # keep CRDs
```

## Next Steps

- See [README.md](README.md) for full documentation
- See [CERT-MANAGER-TESTING.md](CERT-MANAGER-TESTING.md) for TLS scenarios
- Upstream NGF docs: https://docs.nginx.com/nginx-gateway-fabric/
