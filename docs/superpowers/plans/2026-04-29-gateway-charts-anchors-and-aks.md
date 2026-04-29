# Gateway Charts: YAML Anchors + AKS Support — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** DRY the GatewayClass identity (name + controller) in `drunk-nginx-gateway` and `drunk-traefik-gateway` values files via top-of-file YAML anchors, and add a new `values.aks.yaml` per chart for internal Azure Load Balancer deployments.

**Architecture:** Pure values-file refactor — no template, helper, Chart.yaml, or script changes. Each values file gets a `# variables` block with `&anchor` declarations; consumers in the same file use `*alias`. AKS support ships as a sibling to the existing `values.local.yaml` convention. Regression is verified by `helm template` diff against pre-refactor baselines (the diff must be empty).

**Tech Stack:** Helm 3.8+, Gateway API v1.2.0, NGINX Gateway Fabric (vendored OCI subchart), Traefik 33.2.0 (vendored subchart), bash.

**Spec:** `docs/superpowers/specs/2026-04-29-gateway-charts-anchors-and-aks-design.md`

---

## File Map

**drunk-nginx-gateway/**
- `values.yaml` — modify (add anchor block, replace duplicate string literals with aliases)
- `values.local.yaml` — modify (same pattern)
- `values.aks.yaml` — **create** (new file mirroring `values.local.yaml` shape, configured for internal Azure LB)
- `README.md` — modify (add brief AKS section)
- `QUICKSTART.md` — modify (add AKS install command)
- `CHANGELOG.md` — modify (entry under `[Unreleased]`)

**drunk-traefik-gateway/**
- `values.yaml` — modify
- `values.local.yaml` — modify
- `values.aks.yaml` — **create**
- `README.md` — modify
- `QUICKSTART.md` — modify
- `CHANGELOG.md` — modify

**Untouched:** `templates/*.yaml`, `_helpers.tpl`, `Chart.yaml`, `crds/`, `install.sh`, `build.sh`, `uninstall.sh`, `test.sh`, `verify.sh`.

---

## Task 1: Capture pre-refactor baselines (regression fixtures)

**Why:** The anchor refactor must produce byte-for-byte identical `helm template` output for `values.yaml` and `values.local.yaml`. We capture the baselines on the unmodified working tree so we can diff after each refactor.

**Files:**
- Create (transient, not committed): `/tmp/before-nginx-default.yaml`, `/tmp/before-nginx-local.yaml`, `/tmp/before-traefik-default.yaml`, `/tmp/before-traefik-local.yaml`

- [ ] **Step 1: Confirm clean working tree on the right branch**

Run:
```bash
git status
git rev-parse --abbrev-ref HEAD
```

Expected: working tree clean (or only the design spec already committed). Branch is `baoduy/helm-yaml-anchor-refactor`.

If dirty, stop and resolve before continuing.

- [ ] **Step 2: Update Helm subchart dependencies**

Run:
```bash
helm dependency update ./drunk-nginx-gateway
helm dependency update ./drunk-traefik-gateway
```

Expected: each prints `Saving N charts` / `Deleting outdated charts` and exits 0. The vendored subcharts (`nginx-gateway-fabric`, `cert-manager`, `traefik`) are pulled into `charts/`.

- [ ] **Step 3: Capture nginx baselines**

Run:
```bash
helm template test ./drunk-nginx-gateway > /tmp/before-nginx-default.yaml
helm template test ./drunk-nginx-gateway -f drunk-nginx-gateway/values.local.yaml > /tmp/before-nginx-local.yaml
wc -l /tmp/before-nginx-default.yaml /tmp/before-nginx-local.yaml
```

Expected: both files non-empty (line count > 0). No errors printed.

- [ ] **Step 4: Capture traefik baselines**

Run:
```bash
helm template test ./drunk-traefik-gateway > /tmp/before-traefik-default.yaml
helm template test ./drunk-traefik-gateway -f drunk-traefik-gateway/values.local.yaml > /tmp/before-traefik-local.yaml
wc -l /tmp/before-traefik-default.yaml /tmp/before-traefik-local.yaml
```

Expected: both files non-empty. No errors.

- [ ] **Step 5: No commit (transient files)**

These `/tmp/` baselines are not committed. They exist only for in-flight regression checks during this plan's execution.

---

## Task 2: Refactor `drunk-nginx-gateway/values.yaml`

**Files:**
- Modify: `drunk-nginx-gateway/values.yaml` (full file rewrite for clarity — content shown in Step 2)

- [ ] **Step 1: Verify expected duplicate count (sanity check)**

Run:
```bash
grep -cE '"nginx"|"gateway\.nginx\.org/nginx-gateway-controller"' drunk-nginx-gateway/values.yaml
```

Expected: `5` (3 occurrences of `"nginx"` + 2 of the controller name).

- [ ] **Step 2: Rewrite `drunk-nginx-gateway/values.yaml`**

Replace the file contents with:

```yaml
# Default values for drunk-nginx-gateway
# This chart deploys Kubernetes Gateway API CRDs, a GatewayClass, and optionally
# the NGINX Gateway Fabric controller (vendored as a subchart).
#
# YAML anchors (DRY defaults):
#   The `# variables` block below declares anchors used elsewhere in this file
#   to keep the GatewayClass identity (name + controller) consistent. Anchors
#   are resolved at YAML parse time, per file — they DRY the defaults but do
#   NOT propagate through `--set` overrides. To override the gateway class
#   name, set each consumer path explicitly (e.g.
#   `--set gatewayClass.name=foo --set gateway.gatewayClassName=foo
#   --set nginxGatewayFabric.nginxGateway.gatewayClassName=foo`).

# variables
gatewayClassName: &gatewayClassName "nginx"
gatewayControllerName: &gatewayControllerName "gateway.nginx.org/nginx-gateway-controller"

# Target namespace for Gateway resources (Gateways). If empty, uses release namespace.
namespace: ""

# Gateway API CRD installation settings (CRDs are applied via install.sh / kubectl
# to bypass Helm's 3MB annotation limit; this block is informational).
gatewayAPI:
  version: "v1.2.0"
  channel: "standard"
  # url: "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml"

# GatewayClass configuration (cluster-scoped).
# When the nginxGatewayFabric subchart is enabled, NGF creates the GatewayClass itself
# and the template below is suppressed (to avoid duplicate-resource errors). In that
# case, keep `name`/`controllerName` here in sync with
# `nginxGatewayFabric.nginxGateway.gatewayClassName` / `gatewayControllerName`.
gatewayClass:
  enabled: true
  name: *gatewayClassName
  controllerName: *gatewayControllerName
  description: "NGINX Gateway Fabric Controller"
  annotations: {}
  labels: {}
  # parametersRef points to an NginxProxy resource for data-plane configuration.
  parametersRef: {}
    # group: gateway.nginx.org
    # kind: NginxProxy
    # name: nginx-proxy-config

# Default Gateway configuration (namespace-scoped).
# Creates a shared Gateway that applications can use.
gateway:
  enabled: false
  name: "shared-gateway"
  gatewayClassName: *gatewayClassName
  annotations:
    # cert-manager.io/cluster-issuer: "letsencrypt-prod"
  labels: {}

  listeners:
    - name: http
      protocol: HTTP
      port: 80
      hostname: "*"
      allowedRoutes:
        namespaces:
          from: All

    - name: https
      protocol: HTTPS
      port: 443
      hostname: "*"
      tls:
        mode: Terminate
        certificateRefs:
          - kind: Secret
            name: tls-secret
      allowedRoutes:
        namespaces:
          from: All

# Domain-specific Gateways (rendered by templates/domain-gateways.yaml).
domains: []
  # - name: "drunk-dev"
  #   enabled: true
  #   gatewayClassName: "nginx"
  #   annotations:
  #     cert-manager.io/cluster-issuer: "letsencrypt-prod"
  #   listeners:
  #     - name: http
  #       protocol: HTTP
  #       port: 80
  #       hostname: "*.drunk.dev"
  #       allowedRoutes:
  #         namespaces:
  #           from: Same
  #     - name: https
  #       protocol: HTTPS
  #       port: 443
  #       hostname: "*.drunk.dev"
  #       tls:
  #         mode: Terminate
  #         certificateRefs:
  #           - kind: Secret
  #             name: drunk-dev-tls
  #       allowedRoutes:
  #         namespaces:
  #           from: Same

# cert-manager integration. The `cert-manager` subchart (alias) is enabled separately
# under `cert-manager.enabled`; the keys below configure ClusterIssuers and Certificates
# rendered by this chart's templates.
certManager:
  enabled: false
  installCRDs: true
  clusterIssuersEnabled: false

# ClusterIssuer / Certificate configuration consumed by templates/clusterissuer.yaml
# and templates/certificate.yaml.
clusterIssuers:
  enabled: false
  issuers: []
    # - name: "letsencrypt-prod"
    #   spec:
    #     acme:
    #       email: "admin@drunk.dev"
    #       server: "https://acme-v02.api.letsencrypt.org/directory"
    #       privateKeySecretRef:
    #         name: "letsencrypt-prod-key"
    #       solvers:
    #         - http01:
    #             gatewayHTTPRoute:
    #               parentRefs:
    #                 - kind: Gateway
    #                   name: shared-gateway
    #                   namespace: default

# Route access configuration for automatically generated allowedRoutes when
# listener.allowedRoutes is omitted in values. Modes:
#   All  : Allow routes from all namespaces
#   Same : Allow routes only from same namespace as the Gateway
#   List : Allow routes from a labeled set of namespaces (namespaces must already exist)
routeAccess:
  mode: "Same"
  namespaces: []
  labelKey: "gateway.drunk.charts/access"
  labelValue: ""

# Vendored cert-manager subchart toggle (Chart.yaml dependency `condition: cert-manager.enabled`).
# Helm treats a missing condition value as "enabled", so we set it explicitly to false here.
cert-manager:
  enabled: false

# NGINX Gateway Fabric vendored subchart (alias: nginxGatewayFabric).
# When enabled, installs the upstream `nginx-gateway-fabric` chart from
# oci://ghcr.io/nginx/charts. Gateway API CRDs MUST be installed first
# (handled by install.sh).
nginxGatewayFabric:
  enabled: false
  nginxGateway:
    # MUST match `gatewayClass.name` above when subchart-enabled.
    gatewayClassName: *gatewayClassName
    gatewayControllerName: *gatewayControllerName
  nginx:
    service:
      type: LoadBalancer
```

- [ ] **Step 3: Render and diff against baseline**

Run:
```bash
helm template test ./drunk-nginx-gateway > /tmp/after-nginx-default.yaml
diff /tmp/before-nginx-default.yaml /tmp/after-nginx-default.yaml
echo "exit=$?"
```

Expected: no output before `exit=0`. Any diff means the refactor changed rendered behavior — investigate.

- [ ] **Step 4: Lint the chart**

Run:
```bash
helm lint ./drunk-nginx-gateway
```

Expected: `1 chart(s) linted, 0 chart(s) failed`.

- [ ] **Step 5: Commit**

```bash
git add drunk-nginx-gateway/values.yaml
git commit -m "$(cat <<'EOF'
drunk-nginx-gateway: DRY values.yaml with YAML anchors

Replace duplicated GatewayClass identity literals (name + controller)
with top-of-file `&gatewayClassName` and `&gatewayControllerName`
anchors. Rendered output is byte-for-byte identical to the previous
defaults (verified via helm template diff).
EOF
)"
```

---

## Task 3: Refactor `drunk-nginx-gateway/values.local.yaml`

**Files:**
- Modify: `drunk-nginx-gateway/values.local.yaml` (full file rewrite)

- [ ] **Step 1: Rewrite `drunk-nginx-gateway/values.local.yaml`**

Replace the file contents with:

```yaml
# Local development override values for drunk-nginx-gateway
# Purpose: Quickly install Gateway API CRDs + NGINX Gateway Fabric + a domain-specific
# Gateway on a local Kubernetes cluster (kind / minikube / k3d / k3s).
#
# Usage:
#   helm upgrade --install gateway ./drunk-nginx-gateway -f values.local.yaml
#   ./install.sh                       (recommended; installs CRDs first)
#
# After install:
#   kubectl get gatewayclasses
#   kubectl get gateways -A
#   kubectl describe gateway drunk-dev-gateway -n default
#
# Notes:
# - Enables the vendored NGINX Gateway Fabric subchart; you do not need to install
#   the controller separately.
# - For local clusters without a LoadBalancer, NGF's data-plane Service is exposed via
#   NodePort on standard dev ports (30080 / 30443).
# - cert-manager is enabled with a self-signed ClusterIssuer for local TLS testing.
#
# YAML anchors: this file is parsed independently from values.yaml, so anchors
# are re-declared here. Overriding the top-level `gatewayClassName` key does NOT
# propagate through `--set`; override each consumer path explicitly if needed.

# variables
gatewayClassName: &gatewayClassName "nginx"
gatewayControllerName: &gatewayControllerName "gateway.nginx.org/nginx-gateway-controller"

gatewayAPI:
  version: "v1.2.0"
  channel: "experimental" # Required for BackendTLSPolicy and other experimental features

# Wrapper-managed GatewayClass — suppressed automatically because the NGF subchart
# is enabled below and creates the GatewayClass itself.
gatewayClass:
  enabled: true
  name: *gatewayClassName
  controllerName: *gatewayControllerName

# Enable vendored NGINX Gateway Fabric subchart.
nginxGatewayFabric:
  enabled: true
  nginxGateway:
    gatewayClassName: *gatewayClassName
    gatewayControllerName: *gatewayControllerName
  nginx:
    service:
      type: NodePort
      # NGF schema: list of {port (NodePort), listenerPort (Gateway listener port)}
      nodePorts:
        - port: 30080
          listenerPort: 80
        - port: 30443
          listenerPort: 443

# Provide a single domain-specific Gateway for local testing.
# Map *.dev.local to the cluster ingress IP in /etc/hosts to test.
domains:
  - name: "drunk-dev"
    enabled: true
    gatewayClassName: *gatewayClassName
    annotations:
      cert-manager.io/cluster-issuer: "selfsigned-issuer"
    listeners:
      - name: http
        protocol: HTTP
        port: 80
        hostname: "*.dev.local"
      - name: https
        protocol: HTTPS
        port: 443
        hostname: "*.dev.local"
        tls:
          mode: Terminate
          certificateRefs:
            - kind: Secret
              name: drunk-dev-tls

# Allow routes from a labeled namespace in addition to the Gateway's own namespace.
routeAccess:
  mode: "List"
  namespaces:
    - drunk-dev-apps
  labelKey: "gateway.drunk.charts/access"
  labelValue: "drunk-dev-gateway"

# Install cert-manager with self-signed ClusterIssuer for local TLS testing.
cert-manager:
  enabled: true
  crds:
    enabled: true
  config:
    apiVersion: controller.config.cert-manager.io/v1alpha1
    kind: ControllerConfiguration
    enableGatewayAPI: true

clusterIssuers:
  enabled: true
  issuers:
    - name: "selfsigned-issuer"
      spec:
        selfSigned: {}
```

- [ ] **Step 2: Render and diff against baseline**

Run:
```bash
helm template test ./drunk-nginx-gateway -f drunk-nginx-gateway/values.local.yaml > /tmp/after-nginx-local.yaml
diff /tmp/before-nginx-local.yaml /tmp/after-nginx-local.yaml
echo "exit=$?"
```

Expected: no output before `exit=0`.

- [ ] **Step 3: Commit**

```bash
git add drunk-nginx-gateway/values.local.yaml
git commit -m "$(cat <<'EOF'
drunk-nginx-gateway: DRY values.local.yaml with YAML anchors

Apply same anchor pattern as values.yaml: declare gatewayClassName and
gatewayControllerName at the top, reference via *alias throughout.
Rendered output is byte-for-byte identical (verified via helm template
diff).
EOF
)"
```

---

## Task 4: Create `drunk-nginx-gateway/values.aks.yaml`

**Files:**
- Create: `drunk-nginx-gateway/values.aks.yaml`

- [ ] **Step 1: Create the file**

Write `drunk-nginx-gateway/values.aks.yaml` with these contents:

```yaml
# Azure AKS deployment values for drunk-nginx-gateway
# Purpose: Deploy NGINX Gateway Fabric on AKS with an INTERNAL Azure Load Balancer.
#
# Usage:
#   helm dependency update ./drunk-nginx-gateway
#   helm upgrade --install gateway ./drunk-nginx-gateway \
#     -n drunk-nginx-gateway --create-namespace \
#     -f drunk-nginx-gateway/values.aks.yaml
#
# Customize the loadBalancerIP and any domain hostnames for your environment.
# The IP must be free and routable inside your AKS subnet.
#
# YAML anchors are local to this file; overriding the top-level
# `loadBalancerIP` / `gatewayClassName` keys via `--set` does NOT propagate.
# Override each consumer path explicitly if needed.

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

# Enable vendored NGINX Gateway Fabric subchart with an internal Azure LB.
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

# Example domain Gateway for AKS — uncomment and customize.
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
  namespaces: []
  labelKey: "gateway.drunk.charts/access"
  labelValue: ""

# cert-manager left disabled by default. Enable and configure once your
# DNS-01 solver / ACME credentials are in place.
cert-manager:
  enabled: false

clusterIssuers:
  enabled: false
  issuers: []
```

- [ ] **Step 2: Render the AKS values**

Run:
```bash
helm template test ./drunk-nginx-gateway -f drunk-nginx-gateway/values.aks.yaml > /tmp/after-nginx-aks.yaml
echo "exit=$?"
wc -l /tmp/after-nginx-aks.yaml
```

Expected: exit 0, file is non-empty.

- [ ] **Step 3: Verify the internal-LB Service annotations and IP are present**

Run:
```bash
grep -A3 "kind: Service" /tmp/after-nginx-aks.yaml | head -40
grep -E "azure-load-balancer-internal|loadBalancerIP|externalTrafficPolicy" /tmp/after-nginx-aks.yaml
```

Expected: a Service rendered by the NGF subchart contains:
- annotation `service.beta.kubernetes.io/azure-load-balancer-internal: "true"`
- `loadBalancerIP: 192.168.130.250`
- `externalTrafficPolicy: Local`

If any are missing, check that NGF's `nginx.service` schema accepts those keys at the top level (NGF 2.x.x — adjust nesting if needed; e.g. some versions use `nginx.service.spec.externalTrafficPolicy`).

- [ ] **Step 4: Verify GatewayClass identity is consistent**

Run:
```bash
grep -E "name: nginx$|gatewayClassName: nginx" /tmp/after-nginx-aks.yaml | sort -u
```

Expected: GatewayClass `name: nginx` and Gateway/HTTPRoute consumers all reference `nginx`.

- [ ] **Step 5: Lint**

Run:
```bash
helm lint ./drunk-nginx-gateway -f drunk-nginx-gateway/values.aks.yaml
```

Expected: `0 chart(s) failed`.

- [ ] **Step 6: Commit**

```bash
git add drunk-nginx-gateway/values.aks.yaml
git commit -m "$(cat <<'EOF'
drunk-nginx-gateway: add values.aks.yaml for internal Azure LB

New values file mirrors the values.local.yaml convention but targets
Azure AKS with an internal Load Balancer (annotation
service.beta.kubernetes.io/azure-load-balancer-internal=true,
externalTrafficPolicy=Local, static loadBalancerIP). Uses the same
top-of-file YAML anchor pattern (gatewayClassName, gatewayControllerName,
loadBalancerIP).
EOF
)"
```

---

## Task 5: Update drunk-nginx-gateway docs

**Files:**
- Modify: `drunk-nginx-gateway/QUICKSTART.md`
- Modify: `drunk-nginx-gateway/README.md`
- Modify: `drunk-nginx-gateway/CHANGELOG.md`

- [ ] **Step 1: Add AKS section to `drunk-nginx-gateway/QUICKSTART.md`**

Insert this section immediately after the "Manual install (Helm)" section (after the existing Step 3 `(Optional) cert-manager` block, before the `## Verify` heading):

```markdown
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
```

- [ ] **Step 2: Add a brief AKS mention to `drunk-nginx-gateway/README.md`**

Find the section that lists `values.local.yaml` (search for `values.local.yaml` in README.md). Immediately after it, add a parallel mention:

```markdown
- `values.aks.yaml` — ready-to-go values for Azure AKS deployments using an
  internal Azure Load Balancer. Customize `loadBalancerIP` and (optionally)
  the internal-LB subnet annotation before installing. See `QUICKSTART.md`.
```

If README.md does not currently mention `values.local.yaml` in a list-shaped section, instead add an "Azure AKS" subsection at a sensible place (e.g., next to other deployment scenarios) referencing `values.aks.yaml` and pointing readers to `QUICKSTART.md`.

- [ ] **Step 3: Add CHANGELOG entry**

Edit `drunk-nginx-gateway/CHANGELOG.md`. Locate the `## [Unreleased]` section. Add an `### Added` subsection ABOVE the existing `### Planned` subsection (do not remove `### Planned`):

```markdown
## [Unreleased]

### Added

- `values.aks.yaml` for Azure AKS deployments with an internal Azure Load
  Balancer (annotation `service.beta.kubernetes.io/azure-load-balancer-internal`,
  `externalTrafficPolicy: Local`, static `loadBalancerIP`).
- Top-of-file YAML anchors in `values.yaml`, `values.local.yaml`, and
  `values.aks.yaml` to DRY the GatewayClass identity (`gatewayClassName`,
  `gatewayControllerName`).

### Planned
```

(The existing bullet list under `### Planned` stays unchanged below.)

- [ ] **Step 4: Commit**

```bash
git add drunk-nginx-gateway/QUICKSTART.md drunk-nginx-gateway/README.md drunk-nginx-gateway/CHANGELOG.md
git commit -m "$(cat <<'EOF'
drunk-nginx-gateway: docs for AKS values and anchor refactor

Add AKS install section to QUICKSTART, mention values.aks.yaml in README,
and record the anchor refactor + AKS values file under the Unreleased
CHANGELOG section.
EOF
)"
```

---

## Task 6: Refactor `drunk-traefik-gateway/values.yaml`

**Files:**
- Modify: `drunk-traefik-gateway/values.yaml` (full file rewrite)

- [ ] **Step 1: Verify expected duplicate count (sanity check)**

Run:
```bash
grep -cE '"traefik"' drunk-traefik-gateway/values.yaml
```

Expected: `2` (occurrences of `"traefik"` as `gatewayClass.name` and `gateway.gatewayClassName`).

- [ ] **Step 2: Rewrite `drunk-traefik-gateway/values.yaml`**

Replace the file contents with:

```yaml
# Default values for drunk-traefik-gateway
# This chart deploys Kubernetes Gateway API CRDs and cluster-level Gateway resources.
#
# YAML anchors (DRY defaults):
#   The `# variables` block below declares anchors used elsewhere in this file
#   to keep the GatewayClass identity (name + controller) consistent. Anchors
#   are resolved at YAML parse time, per file — they DRY the defaults but do
#   NOT propagate through `--set` overrides.

# variables
gatewayClassName: &gatewayClassName "traefik"
gatewayControllerName: &gatewayControllerName "traefik.io/gateway-controller"

# Target namespace for Gateway resources (Gateways). If empty, uses release namespace.
namespace: ""

# Gateway API CRD installation settings
gatewayAPI:
  # Gateway API version to embed into chart (used at build time)
  version: "v1.2.0"
  # Installation channel: standard, experimental
  channel: "standard"
  # Custom URL override (normally derived from version/channel)
  # url: "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml"

# GatewayClass configuration (cluster-scoped)
# Defines which Gateway controller implementation to use
gatewayClass:
  enabled: true
  # Name of the GatewayClass
  name: *gatewayClassName
  # Controller name (must match your Gateway controller)
  controllerName: *gatewayControllerName
  # Optional description
  description: "Traefik Gateway Controller"
  # Additional annotations
  annotations: {}
  # Additional labels
  labels: {}
  # Optional parameters reference for controller-specific config
  parametersRef: {}
    # group: gateway.nginx.org
    # kind: NginxProxy
    # name: nginx-proxy-config

# Default Gateway configuration (namespace-scoped)
# Creates a shared Gateway that applications can use
gateway:
  enabled: false
  # Gateway name
  name: "shared-gateway"
  # GatewayClass to use
  gatewayClassName: *gatewayClassName
  # Annotations for the Gateway
  annotations:
    # Example: cert-manager integration
    # cert-manager.io/cluster-issuer: "letsencrypt-prod"
  # Labels for the Gateway
  labels: {}

  # Gateway listeners configuration
  listeners:
    # HTTP listener (port 80)
    - name: http
      protocol: HTTP
      port: 80
      hostname: "*"
      allowedRoutes:
        namespaces:
          from: All # Allow HTTPRoutes from all namespaces

    # HTTPS listener (port 443)
    - name: https
      protocol: HTTPS
      port: 443
      hostname: "*"
      tls:
        mode: Terminate
        # certificateRefs must be specified when mode is Terminate
        # Certificate references (secrets must exist in same namespace as Gateway)
        certificateRefs:
          - kind: Secret
            name: tls-secret # Replace with your actual TLS secret name
      allowedRoutes:
        namespaces:
          from: All # Allow HTTPRoutes from all namespaces

# Example: Domain-specific Gateway for drunk.dev
# Uncomment and customize for your domain
domains: []
  # - name: "drunk-dev"
  #   enabled: true
  #   gatewayClassName: "nginx"
  #   annotations:
  #     cert-manager.io/cluster-issuer: "letsencrypt-prod"
  #   listeners:
  #     - name: http
  #       protocol: HTTP
  #       port: 80
  #       hostname: "*.drunk.dev"
  #       allowedRoutes:
  #         namespaces:
  #           from: Same
  #     - name: https
  #       protocol: HTTPS
  #       port: 443
  #       hostname: "*.drunk.dev"
  #       tls:
  #         mode: Terminate
  #         certificateRefs:
  #           - kind: Secret
  #             name: drunk-dev-tls
  #       allowedRoutes:
  #         namespaces:
  #           from: Same

# cert-manager ClusterIssuer for automatic TLS certificate management
certManager:
  # Install cert-manager as a dependency (optional)
  enabled: false
  # Install cert-manager CRDs
  installCRDs: true
  # Create ClusterIssuers defined below (separate from installing dependency)
  clusterIssuersEnabled: false
  # ClusterIssuer configuration list (used only if clusterIssuersEnabled=true)
  clusterIssuers: []
    # - name: "letsencrypt-prod"
    #   email: "admin@drunk.dev"
    #   server: "https://acme-v02.api.letsencrypt.org/directory"
    #   privateKeySecretRef:
    #     name: "letsencrypt-prod-key"
    #   solvers:
    #     - http01:
    #         gatewayHTTPRoute:
    #           parentRefs:
    #             - kind: Gateway
    #               name: shared-gateway
    #               namespace: default
    #     # For wildcard certificates, use DNS-01
    #     # - dns01:
    #     #     cloudflare:
    #     #       apiTokenSecretRef:
    #     #         name: cloudflare-api-token
    #     #         key: api-token
    #     #   selector:
    #     #     dnsZones:
    #     #       - "drunk.dev"

# Route access configuration for automatically generated allowedRoutes when
# listener.allowedRoutes is omitted in values. Modes:
#  - All  : Allow routes from all namespaces
#  - Same : Allow routes only from same namespace as the Gateway
#  - List : Allow routes from a labeled set of namespaces (namespaces must already exist)
routeAccess:
  mode: "Same"
  # List of namespaces granted access when mode=List
  # These namespaces must already exist and be labeled with labelKey:labelValue
  namespaces: []
  # Label key applied to namespaces when mode=List
  labelKey: "gateway.drunk.charts/access"
  # Label value for selector (default falls back to Gateway name if empty)
  labelValue: ""

# Traefik deployment configuration via vendored subchart.
# When enabled, installs the traefik chart (version 33.2.0) with Kubernetes Gateway API support.
# NOTE: Gateway API CRDs must already be installed (this chart installs them automatically via gatewayAPI.enabled).
traefik:
  enabled: false
  # Disable default Gateway creation by Traefik (we manage our own)
  gateway:
    enabled: false
  # Enable Kubernetes Gateway provider
  providers:
    kubernetesGateway:
      enabled: true
  # Service configuration
  service:
    type: LoadBalancer
  # Ports configuration
  ports:
    web:
      port: 80
    websecure:
      port: 443
  # Resource limits
  resources:
    requests:
      cpu: "100m"
      memory: "50Mi"
    limits:
      cpu: "300m"
      memory: "150Mi"
```

- [ ] **Step 3: Render and diff against baseline**

Run:
```bash
helm template test ./drunk-traefik-gateway > /tmp/after-traefik-default.yaml
diff /tmp/before-traefik-default.yaml /tmp/after-traefik-default.yaml
echo "exit=$?"
```

Expected: no output before `exit=0`.

- [ ] **Step 4: Lint**

Run:
```bash
helm lint ./drunk-traefik-gateway
```

Expected: `0 chart(s) failed`.

- [ ] **Step 5: Commit**

```bash
git add drunk-traefik-gateway/values.yaml
git commit -m "$(cat <<'EOF'
drunk-traefik-gateway: DRY values.yaml with YAML anchors

Replace duplicated GatewayClass identity literals (name + controller)
with top-of-file `&gatewayClassName` and `&gatewayControllerName`
anchors. Rendered output is byte-for-byte identical (verified via
helm template diff).
EOF
)"
```

---

## Task 7: Refactor `drunk-traefik-gateway/values.local.yaml`

**Files:**
- Modify: `drunk-traefik-gateway/values.local.yaml` (full file rewrite)

- [ ] **Step 1: Rewrite `drunk-traefik-gateway/values.local.yaml`**

Replace the file contents with:

```yaml
# Local development override values for drunk-traefik-gateway
# Purpose: Quickly install Gateway API CRDs + a GatewayClass + a domain-specific Gateway
# on a local Kubernetes cluster (kind / minikube / k3d / k3s).
#
# Usage:
#   helm upgrade --install gateway ./drunk-traefik-gateway -f values.local.yaml
#
# After install (k3s/kind/minikube):
#   kubectl get gatewayclasses
#   kubectl get gateways -A
#   kubectl describe gateway drunk-dev-gateway -n default
#
# Notes:
# - This file ENABLES the vendored Traefik Helm subchart with Kubernetes Gateway API support
#   so you do NOT need to install the controller separately.
# - Traefik is lightweight and perfect for K3s local development.
# - For local clusters without a LoadBalancer, we configure NodePort for the data plane service.
# - cert-manager remains disabled by default (local TLS usually uses manual/self-signed secrets).
#
# YAML anchors are local to this file; overriding the top-level
# `gatewayClassName` key via `--set` does NOT propagate.

# variables
gatewayClassName: &gatewayClassName "traefik"
gatewayControllerName: &gatewayControllerName "traefik.io/gateway-controller"

# Ensure CRDs are installed
gatewayAPI:
  enabled: true
  version: "v1.2.0"
  channel: "experimental" # Required for BackendTLSPolicy and other experimental features

gatewayClass:
  enabled: true
  name: *gatewayClassName
  controllerName: *gatewayControllerName

# Enable vendored Traefik subchart with Gateway API support
traefik:
  enabled: true
  # Use specific Traefik version
  # image:
  #   registry: docker.io
  #   repository: traefik
  #   tag: "v3.6.1"
  # Enable Kubernetes Gateway provider
  providers:
    kubernetesGateway:
      enabled: true
  # Disable default Gateway creation by Traefik (we manage our own)
  gateway:
    enabled: false
  # Service configuration - use LoadBalancer on K3s for automatic external IP
  service:
    type: NodePort
  # Ports configuration - use NodePort with standard ports
  ports:
    web:
      port: 80
      nodePort: 30080
    websecure:
      port: 443
      nodePort: 30443
  # Disable hostNetwork to avoid port conflicts
  hostNetwork: false
  # Lightweight resource configuration for local development
  resources:
    requests:
      cpu: "50m"
      memory: "50Mi"
    limits:
      cpu: "200m"
      memory: "100Mi"

# Provide a single domain-specific Gateway for local testing.
# You can map dev.local or *.dev.local in /etc/hosts to the cluster ingress IP
# (e.g. minikube ip / kind ingress controller service).
# For TLS testing locally, create a secret manually or configure an ACME staging issuer.
domains:
  - name: "drunk-dev"
    enabled: true
    gatewayClassName: *gatewayClassName
    annotations:
      # Request cert-manager to create certificate
      cert-manager.io/cluster-issuer: "selfsigned-issuer"
    listeners:
      - name: http
        protocol: HTTP
        port: 80
        hostname: "*.dev.local"
        # allowedRoutes will be auto-generated from routeAccess below
      - name: https
        protocol: HTTPS
        port: 443
        hostname: "*.dev.local"
        tls:
          mode: Terminate
          certificateRefs:
            - kind: Secret
              name: drunk-dev-tls
        # allowedRoutes will be auto-generated from routeAccess below

# Allow routes from specific namespaces (List mode) in addition to the Gateway's own namespace
# Note: These namespaces must already exist and be labeled with the labelKey:labelValue
routeAccess:
  mode: "List"
  namespaces:
    - drunk-dev-apps
  labelKey: "gateway.drunk.charts/access"
  labelValue: "drunk-dev-gateway"

# Install cert-manager with self-signed ClusterIssuer for local TLS testing
cert-manager:
  enabled: true
  crds:
    enabled: true
  config:
    apiVersion: controller.config.cert-manager.io/v1alpha1
    kind: ControllerConfiguration
    enableGatewayAPI: true

# ClusterIssuer configuration
clusterIssuers:
  enabled: true
  issuers:
    - name: "selfsigned-issuer"
      spec:
        selfSigned: {}
```

- [ ] **Step 2: Render and diff against baseline**

Run:
```bash
helm template test ./drunk-traefik-gateway -f drunk-traefik-gateway/values.local.yaml > /tmp/after-traefik-local.yaml
diff /tmp/before-traefik-local.yaml /tmp/after-traefik-local.yaml
echo "exit=$?"
```

Expected: no output before `exit=0`.

- [ ] **Step 3: Commit**

```bash
git add drunk-traefik-gateway/values.local.yaml
git commit -m "$(cat <<'EOF'
drunk-traefik-gateway: DRY values.local.yaml with YAML anchors

Apply the same anchor pattern as values.yaml. Rendered output is
byte-for-byte identical (verified via helm template diff).
EOF
)"
```

---

## Task 8: Create `drunk-traefik-gateway/values.aks.yaml`

**Files:**
- Create: `drunk-traefik-gateway/values.aks.yaml`

**Schema note:** The Traefik upstream chart (v33.2.0) accepts service-level options under `traefik.service`. Some Traefik chart versions place `externalTrafficPolicy` and `loadBalancerIP` directly under `service`; others nest them under `service.spec`. We default to direct placement (matches the local file's `service.type: NodePort` shape). If `helm template` errors or omits the values, switch to the `service.spec.*` nested form documented in `_helpers.tpl` of the vendored Traefik chart.

- [ ] **Step 1: Create the file**

Write `drunk-traefik-gateway/values.aks.yaml` with these contents:

```yaml
# Azure AKS deployment values for drunk-traefik-gateway
# Purpose: Deploy Traefik with Kubernetes Gateway API on AKS using an INTERNAL Azure
# Load Balancer (private IP, not public).
#
# Usage:
#   helm dependency update ./drunk-traefik-gateway
#   helm upgrade --install gateway ./drunk-traefik-gateway \
#     -n drunk-traefik-gateway --create-namespace \
#     -f drunk-traefik-gateway/values.aks.yaml
#
# Customize the loadBalancerIP for your AKS subnet before installing.
#
# YAML anchors are local to this file; overriding the top-level keys via
# `--set` does NOT propagate. Override each consumer path explicitly.

# variables
gatewayClassName: &gatewayClassName "traefik"
gatewayControllerName: &gatewayControllerName "traefik.io/gateway-controller"
loadBalancerIP: &loadBalancerIP "192.168.130.250"  # CHANGE ME — must be in your AKS subnet

gatewayAPI:
  enabled: true
  version: "v1.2.0"
  channel: "experimental"

gatewayClass:
  enabled: true
  name: *gatewayClassName
  controllerName: *gatewayControllerName

# Enable vendored Traefik subchart with internal Azure LB
traefik:
  enabled: true
  providers:
    kubernetesGateway:
      enabled: true
  # Disable default Gateway creation by Traefik (we manage our own)
  gateway:
    enabled: false
  service:
    type: LoadBalancer
    annotations:
      service.beta.kubernetes.io/azure-load-balancer-internal: "true"
      # Optional: pin to a specific subnet
      # service.beta.kubernetes.io/azure-load-balancer-internal-subnet: "<subnet-name>"
    externalTrafficPolicy: "Local"
    loadBalancerIP: *loadBalancerIP
  ports:
    web:
      port: 80
    websecure:
      port: 443
  hostNetwork: false
  resources:
    requests:
      cpu: "100m"
      memory: "50Mi"
    limits:
      cpu: "300m"
      memory: "150Mi"

# Example domain Gateway for AKS — uncomment and customize.
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
  namespaces: []
  labelKey: "gateway.drunk.charts/access"
  labelValue: ""

# cert-manager left disabled by default. Enable once your DNS-01 / ACME setup is ready.
cert-manager:
  enabled: false

clusterIssuers:
  enabled: false
  issuers: []
```

- [ ] **Step 2: Render the AKS values**

Run:
```bash
helm template test ./drunk-traefik-gateway -f drunk-traefik-gateway/values.aks.yaml > /tmp/after-traefik-aks.yaml
echo "exit=$?"
wc -l /tmp/after-traefik-aks.yaml
```

Expected: exit 0, file is non-empty.

- [ ] **Step 3: Verify the internal-LB Service annotations and IP are present**

Run:
```bash
grep -E "azure-load-balancer-internal|loadBalancerIP|externalTrafficPolicy" /tmp/after-traefik-aks.yaml
```

Expected output includes:
- `service.beta.kubernetes.io/azure-load-balancer-internal: "true"` (annotation on the Traefik Service)
- `loadBalancerIP: 192.168.130.250`
- `externalTrafficPolicy: Local`

If any are missing, the Traefik upstream chart schema differs from the assumed flat shape. Inspect the rendered Service and adjust `values.aks.yaml` to nest under `service.spec.externalTrafficPolicy` / `service.spec.loadBalancerIP`. Re-render and re-grep until all three appear. Document the chosen nesting in a values-file comment.

- [ ] **Step 4: Verify GatewayClass identity**

Run:
```bash
grep -E "name: traefik$|gatewayClassName: traefik" /tmp/after-traefik-aks.yaml | sort -u
```

Expected: GatewayClass `name: traefik` rendered.

- [ ] **Step 5: Lint**

Run:
```bash
helm lint ./drunk-traefik-gateway -f drunk-traefik-gateway/values.aks.yaml
```

Expected: `0 chart(s) failed`.

- [ ] **Step 6: Commit**

```bash
git add drunk-traefik-gateway/values.aks.yaml
git commit -m "$(cat <<'EOF'
drunk-traefik-gateway: add values.aks.yaml for internal Azure LB

New values file mirrors the values.local.yaml convention but targets
Azure AKS with an internal Load Balancer (annotation
service.beta.kubernetes.io/azure-load-balancer-internal=true,
externalTrafficPolicy=Local, static loadBalancerIP). Uses the same
top-of-file YAML anchor pattern (gatewayClassName, gatewayControllerName,
loadBalancerIP).
EOF
)"
```

---

## Task 9: Update drunk-traefik-gateway docs

**Files:**
- Modify: `drunk-traefik-gateway/QUICKSTART.md`
- Modify: `drunk-traefik-gateway/README.md`
- Modify: `drunk-traefik-gateway/CHANGELOG.md`

- [ ] **Step 1: Add AKS section to `drunk-traefik-gateway/QUICKSTART.md`**

Insert this section at a natural place (next to or after the existing local install section). If unsure where, append before the final "Next Steps"/"Troubleshooting" section:

```markdown
## Azure AKS install (internal Load Balancer)

For Azure AKS deployments needing an **internal** Azure Load Balancer
(private IP, not public), use `values.aks.yaml`:

```bash
helm dependency update ./drunk-traefik-gateway
helm upgrade --install traefik-gateway ./drunk-traefik-gateway \
  -n drunk-traefik-gateway --create-namespace \
  -f ./drunk-traefik-gateway/values.aks.yaml
```

Before installing, edit `values.aks.yaml` and replace the `loadBalancerIP`
placeholder (`192.168.130.250`) with a free IP in your AKS subnet. To pin
the LB to a specific subnet, uncomment the
`service.beta.kubernetes.io/azure-load-balancer-internal-subnet`
annotation.
```

- [ ] **Step 2: Mention AKS values in `drunk-traefik-gateway/README.md`**

Find where `values.local.yaml` is described in README.md and add a parallel entry:

```markdown
- `values.aks.yaml` — ready-to-go values for Azure AKS deployments using an
  internal Azure Load Balancer. Customize `loadBalancerIP` (and optionally
  the internal-LB subnet annotation) before installing. See `QUICKSTART.md`.
```

If README.md does not currently describe `values.local.yaml`, instead add a brief "Azure AKS" subsection in a sensible location referencing `values.aks.yaml` and pointing readers to `QUICKSTART.md`.

- [ ] **Step 3: Add CHANGELOG entry**

Edit `drunk-traefik-gateway/CHANGELOG.md`. Locate the `## [Unreleased]` section. Add an `### Added` subsection ABOVE the existing `### Planned Features` subsection (do not remove `### Planned Features`):

```markdown
## [Unreleased]

### Added

- `values.aks.yaml` for Azure AKS deployments with an internal Azure Load
  Balancer (annotation `service.beta.kubernetes.io/azure-load-balancer-internal`,
  `externalTrafficPolicy: Local`, static `loadBalancerIP`).
- Top-of-file YAML anchors in `values.yaml`, `values.local.yaml`, and
  `values.aks.yaml` to DRY the GatewayClass identity (`gatewayClassName`,
  `gatewayControllerName`).

### Planned Features
```

(The existing bullet list under `### Planned Features` stays unchanged below.)

- [ ] **Step 4: Commit**

```bash
git add drunk-traefik-gateway/QUICKSTART.md drunk-traefik-gateway/README.md drunk-traefik-gateway/CHANGELOG.md
git commit -m "$(cat <<'EOF'
drunk-traefik-gateway: docs for AKS values and anchor refactor

Add AKS install section to QUICKSTART, mention values.aks.yaml in README,
and record the anchor refactor + AKS values file under the Unreleased
CHANGELOG section.
EOF
)"
```

---

## Task 10: Final verification

**Files:** none modified — runs the chart-provided verification scripts and a final whole-chart render check.

- [ ] **Step 1: Run nginx chart verify.sh**

Run:
```bash
./drunk-nginx-gateway/verify.sh
```

Expected: ends with `[OK]   All verification tests passed!` and exit 0.

If it fails, read the `[FAIL]` lines, fix the underlying issue, and re-run. Common causes: missing required key in values.yaml (the script greps for `^gatewayAPI:`, `^gatewayClass:`, `^gateway:`, `^domains:`, `^certManager:`, `^nginxGatewayFabric:` at column 0 — make sure the anchor block at the top of values.yaml does NOT shift these keys' indentation).

- [ ] **Step 2: Run traefik chart verify.sh**

Run:
```bash
./drunk-traefik-gateway/verify.sh
```

Expected: ends with `[OK]   All verification tests passed!` and exit 0. Same troubleshooting guidance as Step 1.

- [ ] **Step 3: Final render-diff sanity (both charts, both default and local)**

Run:
```bash
helm template test ./drunk-nginx-gateway > /tmp/final-nginx-default.yaml
helm template test ./drunk-nginx-gateway -f drunk-nginx-gateway/values.local.yaml > /tmp/final-nginx-local.yaml
helm template test ./drunk-traefik-gateway > /tmp/final-traefik-default.yaml
helm template test ./drunk-traefik-gateway -f drunk-traefik-gateway/values.local.yaml > /tmp/final-traefik-local.yaml

diff /tmp/before-nginx-default.yaml /tmp/final-nginx-default.yaml
diff /tmp/before-nginx-local.yaml /tmp/final-nginx-local.yaml
diff /tmp/before-traefik-default.yaml /tmp/final-traefik-default.yaml
diff /tmp/before-traefik-local.yaml /tmp/final-traefik-local.yaml
echo "all-diffs exit=$?"
```

Expected: all four diffs produce no output. Final exit code 0.

- [ ] **Step 4: AKS files render cleanly end-to-end**

Run:
```bash
helm template test ./drunk-nginx-gateway -f drunk-nginx-gateway/values.aks.yaml > /dev/null && echo "nginx aks OK"
helm template test ./drunk-traefik-gateway -f drunk-traefik-gateway/values.aks.yaml > /dev/null && echo "traefik aks OK"
```

Expected: prints `nginx aks OK` and `traefik aks OK`.

- [ ] **Step 5: Confirm working tree is clean and review commit history**

Run:
```bash
git status
git log --oneline -10
```

Expected: clean working tree. Recent commits reflect the 8 work commits from Tasks 2–9 (the design spec commit predates this plan).

- [ ] **Step 6: No commit (verification only — nothing to commit)**

Verification produced no file changes. The plan is complete.

---

## Summary of commits this plan produces

In order:
1. `drunk-nginx-gateway: DRY values.yaml with YAML anchors`
2. `drunk-nginx-gateway: DRY values.local.yaml with YAML anchors`
3. `drunk-nginx-gateway: add values.aks.yaml for internal Azure LB`
4. `drunk-nginx-gateway: docs for AKS values and anchor refactor`
5. `drunk-traefik-gateway: DRY values.yaml with YAML anchors`
6. `drunk-traefik-gateway: DRY values.local.yaml with YAML anchors`
7. `drunk-traefik-gateway: add values.aks.yaml for internal Azure LB`
8. `drunk-traefik-gateway: docs for AKS values and anchor refactor`

(Plus the design spec commit from earlier, on the same branch.)
