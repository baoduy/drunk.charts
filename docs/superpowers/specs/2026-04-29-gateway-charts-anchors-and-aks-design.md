# Gateway Charts: YAML Anchor DRY + AKS Support — Design

**Date:** 2026-04-29
**Scope:** `drunk-nginx-gateway`, `drunk-traefik-gateway`
**Type:** Refactor (values files only) + new feature (AKS deployment values)

## Problem

Two gateway charts duplicate identifying values across multiple paths within a single values file:

- `drunk-nginx-gateway/values.yaml`: `"nginx"` appears in 3 paths (`gatewayClass.name`, `gateway.gatewayClassName`, `nginxGatewayFabric.nginxGateway.gatewayClassName`); `"gateway.nginx.org/nginx-gateway-controller"` appears in 2 paths.
- `drunk-traefik-gateway/values.yaml`: `"traefik"` appears in 2 paths.
- The same duplication recurs in each chart's `values.local.yaml`.

Drift between these duplicates produces silent misconfiguration (Gateways pointing at non-existent GatewayClasses).

Additionally, the charts ship `values.local.yaml` for k3s/kind/minikube but have no ready-to-use values file for Azure AKS deployments using an internal Azure Load Balancer.

## Goals

1. **DRY the defaults** in each values file using YAML anchors (`&`) and aliases (`*`), so the GatewayClass identity (name + controller) lives in exactly one place per file.
2. **Add AKS support** as a new `values.aks.yaml` per chart, mirroring the `values.local.yaml` convention, configured for an internal Azure Load Balancer.

## Non-Goals

- **Override-time propagation.** Anchors are resolved at YAML parse time, per file. Helm merges resolved structures, so an override of `gatewayClassName` via `--set` or in another values file affects only the path being set. This is acceptable: defaults stay DRY; overrides remain path-explicit, matching how Helm users already think about `--set`.
- **Template-level helpers.** No changes to `templates/*.yaml` or `_helpers.tpl`. Existing `.Values.gatewayClass.name` etc. references continue to work.
- **Azure-specific concerns out of scope:** workload identity wiring, ACR image overrides, real subnet names, real LoadBalancer IPs, real domain names, DNS-01 solver configuration. The AKS values file ships placeholders and commented examples.
- **Wider value DRY** (gateway names, TLS secret names, hostnames, label keys) — these are user-facing knobs that legitimately vary per deployment; anchoring them adds noise without clear win.
- **No new `ingressClass` anchor.** In Gateway API, `gatewayClassName` is the equivalent concept; a separate `ingressClass` anchor would be unused in these charts.

## Design

### 1. Anchor Convention

Each values file gets a `# variables` block at the top declaring anchors. Anchors are referenced via `*` everywhere the value is consumed within the same file.

**Anchors per chart:**

| Chart | Anchor name | Default value | Purpose |
|---|---|---|---|
| nginx | `&gatewayClassName` | `"nginx"` | Gateway API class name |
| nginx | `&gatewayControllerName` | `"gateway.nginx.org/nginx-gateway-controller"` | Controller identifier |
| traefik | `&gatewayClassName` | `"traefik"` | Gateway API class name |
| traefik | `&gatewayControllerName` | `"traefik.io/gateway-controller"` | Controller identifier (anchored for symmetry) |

**Files updated per chart:** `values.yaml`, `values.local.yaml`, and the new `values.aks.yaml`. Each file is self-contained: anchors do not cross files in the YAML parser.

### 2. drunk-nginx-gateway — values.yaml shape (after)

```yaml
# variables
gatewayClassName: &gatewayClassName "nginx"
gatewayControllerName: &gatewayControllerName "gateway.nginx.org/nginx-gateway-controller"

namespace: ""

gatewayAPI:
  version: "v1.2.0"
  channel: "standard"

gatewayClass:
  enabled: true
  name: *gatewayClassName
  controllerName: *gatewayControllerName
  description: "NGINX Gateway Fabric Controller"
  annotations: {}
  labels: {}
  parametersRef: {}

gateway:
  enabled: false
  name: "shared-gateway"
  gatewayClassName: *gatewayClassName
  # ... rest unchanged ...

# domains, certManager, clusterIssuers, routeAccess, cert-manager — unchanged

nginxGatewayFabric:
  enabled: false
  nginxGateway:
    gatewayClassName: *gatewayClassName
    gatewayControllerName: *gatewayControllerName
  nginx:
    service:
      type: LoadBalancer
```

The top-level `gatewayClassName` and `gatewayControllerName` keys become real values in the Helm values tree (Helm sees the post-parse, anchor-resolved structure). They are not currently consumed by templates. Templates continue to read `.Values.gatewayClass.name`, `.Values.gateway.gatewayClassName`, and `.Values.nginxGatewayFabric.nginxGateway.gatewayClassName` as before.

### 3. drunk-nginx-gateway — values.local.yaml shape (after)

```yaml
# variables
gatewayClassName: &gatewayClassName "nginx"
gatewayControllerName: &gatewayControllerName "gateway.nginx.org/nginx-gateway-controller"

gatewayAPI:
  version: "v1.2.0"
  channel: "experimental"

gatewayClass:
  enabled: true
  name: *gatewayClassName
  controllerName: *gatewayControllerName

nginxGatewayFabric:
  enabled: true
  nginxGateway:
    gatewayClassName: *gatewayClassName
    gatewayControllerName: *gatewayControllerName
  nginx:
    service:
      type: NodePort
      nodePorts:
        - port: 30080
          listenerPort: 80
        - port: 30443
          listenerPort: 443

domains:
  - name: "drunk-dev"
    enabled: true
    gatewayClassName: *gatewayClassName
    annotations:
      cert-manager.io/cluster-issuer: "selfsigned-issuer"
    listeners:
      # unchanged

# routeAccess, cert-manager, clusterIssuers — unchanged
```

Note: `domains[].gatewayClassName` is also DRYed via `*gatewayClassName`.

### 4. drunk-nginx-gateway — values.aks.yaml (new)

```yaml
# Azure AKS deployment values for drunk-nginx-gateway
# Purpose: Deploy NGINX Gateway Fabric on AKS with an INTERNAL Azure Load Balancer.
#
# Usage:
#   helm upgrade --install gateway ./drunk-nginx-gateway -f values.aks.yaml
#
# Customize the loadBalancerIP and domain hostname for your environment.

# variables
gatewayClassName: &gatewayClassName "nginx"
gatewayControllerName: &gatewayControllerName "gateway.nginx.org/nginx-gateway-controller"
loadBalancerIP: &loadBalancerIP "192.168.130.250"  # CHANGE ME — must be in your AKS subnet

gatewayAPI:
  version: "v1.2.0"
  channel: "experimental"

gatewayClass:
  enabled: true
  name: *gatewayClassName
  controllerName: *gatewayControllerName

nginxGatewayFabric:
  enabled: true
  nginxGateway:
    gatewayClassName: *gatewayClassName
    gatewayControllerName: *gatewayControllerName
  nginx:
    service:
      type: LoadBalancer
      annotations:
        service.beta.kubernetes.io/azure-load-balancer-internal: "true"
        # Optional: pin to a specific subnet
        # service.beta.kubernetes.io/azure-load-balancer-internal-subnet: "<subnet-name>"
      externalTrafficPolicy: "Local"
      loadBalancerIP: *loadBalancerIP

# Example domain Gateway — uncomment and customize.
domains: []
  # - name: "aks-internal"
  #   enabled: true
  #   gatewayClassName: *gatewayClassName
  #   annotations:
  #     cert-manager.io/cluster-issuer: "letsencrypt-prod"
  #   listeners:
  #     - name: http
  #       protocol: HTTP
  #       port: 80
  #       hostname: "*.aks.example.com"
  #     - name: https
  #       protocol: HTTPS
  #       port: 443
  #       hostname: "*.aks.example.com"
  #       tls:
  #         mode: Terminate
  #         certificateRefs:
  #           - kind: Secret
  #             name: aks-tls

routeAccess:
  mode: "Same"
  labelKey: "gateway.drunk.charts/access"
  labelValue: ""

# cert-manager / clusterIssuers left disabled by default.
# Enable and configure once your DNS-01 solver / ACME credentials are in place.
cert-manager:
  enabled: false
clusterIssuers:
  enabled: false
```

### 5. drunk-traefik-gateway — values.yaml shape (after)

```yaml
# variables
gatewayClassName: &gatewayClassName "traefik"
gatewayControllerName: &gatewayControllerName "traefik.io/gateway-controller"

namespace: ""

gatewayAPI:
  version: "v1.2.0"
  channel: "standard"

gatewayClass:
  enabled: true
  name: *gatewayClassName
  controllerName: *gatewayControllerName
  description: "Traefik Gateway Controller"
  annotations: {}
  labels: {}
  parametersRef: {}

gateway:
  enabled: false
  name: "shared-gateway"
  gatewayClassName: *gatewayClassName
  # ... rest unchanged ...

# domains, certManager, routeAccess — unchanged

traefik:
  enabled: false
  gateway:
    enabled: false
  providers:
    kubernetesGateway:
      enabled: true
  service:
    type: LoadBalancer
  # ports, resources — unchanged
```

### 6. drunk-traefik-gateway — values.local.yaml shape (after)

```yaml
# variables
gatewayClassName: &gatewayClassName "traefik"
gatewayControllerName: &gatewayControllerName "traefik.io/gateway-controller"

gatewayAPI:
  enabled: true
  version: "v1.2.0"
  channel: "experimental"

traefik:
  enabled: true
  providers:
    kubernetesGateway:
      enabled: true
  gateway:
    enabled: false
  service:
    type: NodePort
  ports:
    web:
      port: 80
      nodePort: 30080
    websecure:
      port: 443
      nodePort: 30443
  # hostNetwork, resources — unchanged

domains:
  - name: "drunk-dev"
    enabled: true
    gatewayClassName: *gatewayClassName
    # rest unchanged
```

### 7. drunk-traefik-gateway — values.aks.yaml (new)

```yaml
# Azure AKS deployment values for drunk-traefik-gateway
# Usage:
#   helm upgrade --install gateway ./drunk-traefik-gateway -f values.aks.yaml

# variables
gatewayClassName: &gatewayClassName "traefik"
gatewayControllerName: &gatewayControllerName "traefik.io/gateway-controller"
loadBalancerIP: &loadBalancerIP "192.168.130.250"  # CHANGE ME

gatewayAPI:
  enabled: true
  version: "v1.2.0"
  channel: "experimental"

gatewayClass:
  enabled: true
  name: *gatewayClassName
  controllerName: *gatewayControllerName

traefik:
  enabled: true
  providers:
    kubernetesGateway:
      enabled: true
  gateway:
    enabled: false
  service:
    type: LoadBalancer
    annotations:
      service.beta.kubernetes.io/azure-load-balancer-internal: "true"
      # Optional: pin to a specific subnet
      # service.beta.kubernetes.io/azure-load-balancer-internal-subnet: "<subnet-name>"
    spec:
      externalTrafficPolicy: Local
      loadBalancerIP: *loadBalancerIP
  ports:
    web:
      port: 80
    websecure:
      port: 443

domains: []
  # - name: "aks-internal"
  #   enabled: true
  #   gatewayClassName: *gatewayClassName
  #   listeners:
  #     - name: http
  #       protocol: HTTP
  #       port: 80
  #       hostname: "*.aks.example.com"
  #     - name: https
  #       protocol: HTTPS
  #       port: 443
  #       hostname: "*.aks.example.com"
  #       tls:
  #         mode: Terminate
  #         certificateRefs:
  #           - kind: Secret
  #             name: aks-tls

routeAccess:
  mode: "Same"
  labelKey: "gateway.drunk.charts/access"
  labelValue: ""
```

> **Note on Traefik subchart service spec:** The Traefik upstream chart accepts `service.spec.externalTrafficPolicy` and `service.spec.loadBalancerIP` under a `spec:` key (verify against the pinned Traefik chart version 33.2.0 during implementation). If the upstream schema differs, place these directly under `traefik.service` (matching the upstream schema) — the values file shape adapts but the anchor pattern remains unchanged.

## What Is NOT Changed

- `templates/*.yaml`, `_helpers.tpl`, `Chart.yaml`, `crds/`, `install.sh`, `build.sh`, `verify.sh`, `uninstall.sh`, `test.sh` — untouched.
- Default behavior of `values.yaml` and `values.local.yaml` (after refactor) is byte-for-byte equivalent in `helm template` output to the pre-refactor versions.

## Verification

For each chart, in the order listed:

1. **Lint:** `helm lint ./drunk-<name>-gateway` produces no errors.
2. **Render diff (regression):**
   - **Before any edits**, capture baseline renders from the unmodified chart on a clean working tree:
     - `helm template ./drunk-<name>-gateway > /tmp/before-default.yaml`
     - `helm template ./drunk-<name>-gateway -f values.local.yaml > /tmp/before-local.yaml`
   - After the refactor, capture post-refactor renders to `/tmp/after-default.yaml` and `/tmp/after-local.yaml`.
   - `diff /tmp/before-default.yaml /tmp/after-default.yaml` must produce no output.
   - `diff /tmp/before-local.yaml /tmp/after-local.yaml` must produce no output.
   - If diffs appear, the anchor refactor changed rendered output (a bug); investigate before proceeding.
3. **AKS render (new file):** `helm template ./drunk-<name>-gateway -f values.aks.yaml` renders without errors. Visually inspect that the Service has:
   - `service.beta.kubernetes.io/azure-load-balancer-internal: "true"` annotation
   - `externalTrafficPolicy: Local`
   - `loadBalancerIP: 192.168.130.250`
   - GatewayClass / Gateway / NGF (or Traefik) all reference the same `gatewayClassName`.
4. **verify.sh:** Run `./drunk-nginx-gateway/verify.sh` and `./drunk-traefik-gateway/verify.sh`. Address any failures before declaring done.
5. **Documentation updates:**
   - Each chart's `README.md` and `QUICKSTART.md` mention `values.aks.yaml` with the install command.
   - `CHANGELOG.md` entry per chart describing the anchor refactor and AKS values file addition.

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Anchor refactor changes rendered output unexpectedly | Render-diff regression check (Verification step 2) |
| User assumes overriding the top-level anchor key (`--set gatewayClassName=foo`) propagates everywhere | Document explicitly in each values file's header comment that anchors only DRY the defaults; overrides must target the specific path (`gatewayClass.name`, `gateway.gatewayClassName`, etc.) |
| Traefik upstream chart schema mismatch on `service.spec.externalTrafficPolicy` | Verify against vendored Traefik chart version during implementation; fall back to `traefik.service.externalTrafficPolicy` if needed |
| AKS placeholder IP `192.168.130.250` accidentally used in real deploys | Inline `# CHANGE ME` comment + README note |

## Files Touched

**drunk-nginx-gateway/**
- `values.yaml` (modified — anchor block added, references added)
- `values.local.yaml` (modified — same)
- `values.aks.yaml` (new)
- `README.md` (modified — AKS section)
- `QUICKSTART.md` (modified — AKS install command)
- `CHANGELOG.md` (modified — entry)

**drunk-traefik-gateway/**
- `values.yaml` (modified)
- `values.local.yaml` (modified)
- `values.aks.yaml` (new)
- `README.md` (modified)
- `QUICKSTART.md` (modified)
- `CHANGELOG.md` (modified)

**docs/**
- `docs/superpowers/specs/2026-04-29-gateway-charts-anchors-and-aks-design.md` (this file)
