# drunk-nginx-gateway

NGINX Gateway Fabric wrapper that bundles Gateway API CRDs, GatewayClass,
domain-specific Gateways, and (optionally) cert-manager for the drunk.charts
ecosystem.

## Overview

`drunk-nginx-gateway` automates the install of:

- **Gateway API CRDs** — applied via `kubectl` to bypass Helm's 3MB annotation limit
- **NGINX Gateway Fabric** — vendored as a subchart from `oci://ghcr.io/nginx/charts`
  (range `2.x.x`); always creates its own GatewayClass `nginx`
- **GatewayClass** — fallback template, only renders when the NGF subchart is disabled
  (so users running an external NGF or another controller still get a GatewayClass)
- **Gateway resources** — single shared Gateway and/or per-domain Gateways
- **cert-manager integration** — optional ClusterIssuer + Certificate templates

This chart mirrors the layout of `drunk-traefik-gateway`. Templates that are not
controller-specific (`domain-gateways.yaml`, `clusterissuer.yaml`, `certificate.yaml`,
`_helpers.tpl`) are shared verbatim.

## Prerequisites

- Kubernetes 1.25+
- Helm 3.8+
- kubectl
- (Optional) cert-manager — vendored as a dependency, installable with the chart

## Quick start

The fastest path:

```bash
cd drunk-nginx-gateway
./install.sh
```

This runs the two-phase install (Gateway API CRDs via `kubectl`, then the chart via
`helm upgrade --install`) using `values.local.yaml`. See [QUICKSTART.md](QUICKSTART.md)
for manual steps and overrides.

## Configuration

### Top-level values

| Parameter | Description | Default |
|---|---|---|
| `gatewayAPI.version` | Gateway API version (used for CRD URL) | `v1.2.0` |
| `gatewayAPI.channel` | Installation channel (`standard` / `experimental`) | `standard` |
| `gatewayClass.enabled` | Render wrapper-managed GatewayClass when NGF subchart is OFF | `true` |
| `gatewayClass.name` | GatewayClass name | `nginx` |
| `gatewayClass.controllerName` | Controller identifier | `gateway.nginx.org/nginx-gateway-controller` |
| `gateway.enabled` | Create default shared Gateway | `false` |
| `gateway.gatewayClassName` | GatewayClass referenced by the default Gateway | `nginx` |
| `domains[]` | Domain-specific Gateways | `[]` |
| `certManager.enabled` | Install vendored cert-manager subchart | `false` |
| `clusterIssuers.enabled` | Render ClusterIssuer/Certificate templates | `false` |
| `routeAccess.mode` | `All` / `Same` / `List` for auto-generated `allowedRoutes` | `Same` |
| `nginxGatewayFabric.enabled` | Install vendored NGF subchart | `false` |
| `nginxGatewayFabric.nginxGateway.gatewayClassName` | NGF-owned GatewayClass name (must match `gatewayClass.name`) | `nginx` |
| `nginxGatewayFabric.nginx.service.type` | Data-plane Service type | `LoadBalancer` |

### Why two GatewayClass paths?

The upstream `nginx-gateway-fabric` chart **always renders a GatewayClass** with no
opt-out flag. To avoid duplicate-resource errors, this chart's
`templates/gatewayclass.yaml` is suppressed automatically when
`nginxGatewayFabric.enabled: true`. In that mode, NGF owns the resource and the
wrapper just keeps `gatewayClass.name`/`controllerName` in sync via documentation.

When `nginxGatewayFabric.enabled: false` (e.g., you installed NGF separately or run
another controller), the wrapper template renders the GatewayClass for you.

### Vendored NGINX Gateway Fabric subchart

```yaml
nginxGatewayFabric:
  enabled: true
  nginxGateway:
    gatewayClassName: "nginx"
    gatewayControllerName: "gateway.nginx.org/nginx-gateway-controller"
  nginx:
    service:
      type: NodePort
      nodePorts:
        - port: 30080
          listenerPort: 80
        - port: 30443
          listenerPort: 443
```

Any upstream NGF value can be overridden under the `nginxGatewayFabric:` key. See the
upstream chart's [values.yaml](https://github.com/nginx/nginx-gateway-fabric/blob/main/charts/nginx-gateway-fabric/values.yaml)
for the full surface.

### Domain-specific Gateways

```yaml
domains:
  - name: drunk-dev
    enabled: true
    gatewayClassName: nginx
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
    listeners:
      - name: http
        protocol: HTTP
        port: 80
        hostname: "*.drunk.dev"
      - name: https
        protocol: HTTPS
        port: 443
        hostname: "*.drunk.dev"
        tls:
          mode: Terminate
          certificateRefs:
            - kind: Secret
              name: drunk-dev-tls
```

### cert-manager

```yaml
clusterIssuers:
  enabled: true
  issuers:
    - name: letsencrypt-prod
      spec:
        acme:
          email: admin@drunk.dev
          server: https://acme-v02.api.letsencrypt.org/directory
          privateKeySecretRef:
            name: letsencrypt-prod-key
          solvers:
            - http01:
                gatewayHTTPRoute:
                  parentRefs:
                    - kind: Gateway
                      name: drunk-dev-gateway
                      namespace: default
```

For wildcard certificates use a DNS-01 solver. See
[CERT-MANAGER-TESTING.md](CERT-MANAGER-TESTING.md).

### NginxProxy `parametersRef`

NGF supports per-GatewayClass data-plane configuration via the `NginxProxy` CRD
(installed by the subchart). Wire it through `gatewayClass.parametersRef`:

```yaml
gatewayClass:
  enabled: true
  name: nginx
  controllerName: gateway.nginx.org/nginx-gateway-controller
  parametersRef:
    group: gateway.nginx.org
    kind: NginxProxy
    name: nginx-proxy-config
```

(Note: when the NGF subchart is enabled it owns the GatewayClass, so this would need
to be set on the upstream values instead — `nginxGatewayFabric.nginxGateway.config.*`.)

## Operations

### Build

```bash
./build.sh                              # helm dependency update + helm package + index
```

### Install

```bash
./install.sh                            # default: nginx-gateway in drunk-nginx-gateway ns
RELEASE_NAME=foo NAMESPACE=bar ./install.sh
SKIP_CRDS=true ./install.sh             # if Gateway API CRDs already installed
FORCE_REINSTALL_CRDS=true ./install.sh
```

#### Azure AKS (internal Load Balancer)

- `values.aks.yaml` — ready-to-go values for Azure AKS deployments using an
  internal Azure Load Balancer. Customize `loadBalancerIP` and (optionally)
  the internal-LB subnet annotation before installing. See `QUICKSTART.md`.

### Verify

```bash
./verify.sh                             # helm lint + dependency + template tests
```

### Uninstall

```bash
./uninstall.sh                          # release + NGF/Gateway API CRDs (confirmations)
FORCE=true ./uninstall.sh               # no prompts
DELETE_CRDS=false ./uninstall.sh        # keep CRDs
```

## Verification commands

```bash
kubectl get gatewayclass                                      # 'nginx' Accepted
kubectl get gateway -A
kubectl get pods -n drunk-nginx-gateway -l app.kubernetes.io/name=nginx-gateway-fabric
kubectl get crd | grep -E '(gateway\.networking|nginx\.org)'
```

## Resources

- Gateway API: https://gateway-api.sigs.k8s.io/
- NGINX Gateway Fabric: https://docs.nginx.com/nginx-gateway-fabric/
- Upstream chart: https://github.com/nginx/nginx-gateway-fabric/tree/main/charts/nginx-gateway-fabric
- cert-manager (Gateway API): https://cert-manager.io/docs/usage/gateway/
- Sibling Traefik wrapper: [`../drunk-traefik-gateway`](../drunk-traefik-gateway)

## Author

- **Duy Bao (baoduy)**
- Email: drunkcoding@outlook.com
- Repository: https://github.com/baoduy/drunk.charts
