# drunk-cloudflare-tunnel-gateway — Design

Date: 2026-08-27
Status: Approved for planning

## 1. Purpose

Add a new Helm application chart `drunk-cloudflare-tunnel-gateway` to the
`drunk.charts` repo. It exposes in-cluster services through a **Cloudflare
Tunnel** using standard Gateway API resources (GatewayClass, Gateway,
HTTPRoute) — no public LoadBalancer, no inbound firewall rule, no in-cluster
TLS.

It is the tunnel-based sibling of `drunk-nginx-gateway`: same Gateway API
authoring model (`domains[]` → Gateways), opposite network model (outbound
tunnel + Cloudflare-edge TLS instead of inbound LoadBalancer + cert-manager).

Upstream controller vendored as a subchart:
[lexfrei/cloudflare-tunnel-gateway-controller](https://github.com/lexfrei/cloudflare-tunnel-gateway-controller)
(`oci://ghcr.io/lexfrei/charts/cloudflare-tunnel-gateway-controller`).

## 2. Key facts about the upstream controller

- GatewayClass name (created by the controller/subchart): **`cloudflare-tunnel`**
  (`controller.gatewayClassName`).
- GatewayClass `controllerName`: **`cf.k8s.lex.la/tunnel-controller`**
  (`controller.controllerName`).
- The subchart **creates its own GatewayClass** when configured — so this
  wrapper must NOT render a GatewayClass (avoids duplicate-resource errors),
  exactly like NGF in `drunk-nginx-gateway`.
- Required subchart config:
  - `gatewayClassConfig.create: true`
  - `gatewayClassConfig.tunnelID` (REQUIRED — Cloudflare Tunnel ID)
  - `gatewayClassConfig.cloudflareCredentialsSecretRef.name` → Secret with an
    `api-token` key (optional `account-id`, else auto-detected).
  - `proxy.tunnelTokenSecretRef.name` → Secret with the tunnel token for the
    in-process cloudflared data plane.
- The controller ships its own `GatewayClassConfig` CRD via the subchart.
- Gateway API CRDs (GatewayClass/Gateway/HTTPRoute/GRPCRoute/ReferenceGrant)
  are installed separately (upstream targets **v1.6.1**), same two-phase
  install pattern as `drunk-nginx-gateway` (kubectl for the >3MB CRDs, then
  helm for the chart).
- ⚠️ The controller assumes **exclusive ownership** of the tunnel config and
  removes ingress rules it does not manage. Document this prominently.

## 3. Scope decisions (confirmed with user)

1. **Lean wrapper.** Vendor the controller + render Gateway/domain-gateways +
   provide install.sh for Gateway API CRDs. Drop cert-manager, ClusterIssuer,
   Certificate, LoadBalancer, HTTPS/TLS listeners, and the aks/local values
   split — Cloudflare edge handles TLS, and the tunnel is outbound.
2. **Secrets referenced by name only.** Chart carries secret *names*; the two
   Secrets are created out-of-band (install.sh prints the `kubectl create
   secret` commands). No credentials in values/git.
3. **Controller vendored as a subchart** (Chart.yaml dependency, alias
   `cloudflareTunnel`). One `helm install` brings up controller + Gateways.
4. **`domains[]` only** for the Gateway abstraction (no redundant shared
   `gateway:` block). HTTP listeners only.

## 4. File layout

```
drunk-cloudflare-tunnel-gateway/
├── Chart.yaml               # type: application; dep: cloudflare-tunnel-gateway-controller (alias cloudflareTunnel)
├── values.yaml              # glue values + passthrough subchart config
├── values.example.yaml      # tunnelID + secret refs filled in
├── templates/
│   ├── _helpers.tpl         # gateway.name/fullname/chart/labels/selectorLabels/ns/crdURL
│   ├── domain-gateways.yaml # per-domain Gateway resources (HTTP listeners)
│   └── NOTES.txt
├── crds/.gitkeep
├── build.sh
├── verify.sh
├── install.sh
├── uninstall.sh
├── README.md
├── .helmignore
└── .gitignore
```

Deliberately NOT included (vs nginx chart): `gatewayclass.yaml`,
`clusterissuer.yaml`, `certificate.yaml`, `values.aks.yaml`,
`values.local.yaml`, cert-manager dependency.

## 5. Chart.yaml

```yaml
apiVersion: v2
name: drunk-cloudflare-tunnel-gateway
icon: https://drunkcoding.net/assets/logo.png
description: Cloudflare Tunnel Gateway API wrapper — expose services via Cloudflare Tunnel with no public LoadBalancer, for drunk.charts
type: application
version: 1.0.0
appVersion: "..."   # pin to a released controller appVersion at implementation time
keywords: [gateway-api, ingress, kubernetes, networking, cloudflare, tunnel, zero-trust]
home: https://github.com/baoduy/drunk.charts
sources:
  - https://github.com/baoduy/drunk.charts
  - https://github.com/kubernetes-sigs/gateway-api
  - https://github.com/lexfrei/cloudflare-tunnel-gateway-controller
maintainers:
  - name: baoduy
    email: drunkcoding@outlook.com
dependencies:
  - name: cloudflare-tunnel-gateway-controller
    version: <pin at impl time>
    repository: oci://ghcr.io/lexfrei/charts
    alias: cloudflareTunnel
    condition: cloudflareTunnel.enabled
```

## 6. values.yaml

```yaml
# variables (YAML anchor — DRY only, does not propagate through --set)
gatewayClassName: &gatewayClassName "cloudflare-tunnel"

# Target namespace for Gateway resources. Empty → release namespace.
namespace: ""

# Gateway API CRD install settings (informational; CRDs applied via install.sh).
gatewayAPI:
  version: "v1.6.1"
  channel: "standard"
  # url: ""   # override full URL if needed

# Domain-specific Gateways (rendered by templates/domain-gateways.yaml).
domains: []
  # - name: "drunk-dev"
  #   enabled: true
  #   gatewayClassName: "cloudflare-tunnel"
  #   annotations: {}
  #   labels: {}
  #   listeners:
  #     - name: http
  #       protocol: HTTP
  #       port: 80
  #       hostname: "*.drunk.dev"
  #       allowedRoutes:
  #         namespaces:
  #           from: Same

# allowedRoutes generated when a listener omits allowedRoutes.
# Modes: All | Same | List (labeled namespaces).
routeAccess:
  mode: "Same"
  namespaces: []
  labelKey: "gateway.drunk.charts/access"
  labelValue: ""

# Vendored controller subchart (Chart.yaml dep, alias cloudflareTunnel).
cloudflareTunnel:
  enabled: true
  gatewayClassConfig:
    create: true
    tunnelID: ""                       # REQUIRED — set per environment
    cloudflareCredentialsSecretRef:
      name: "cloudflare-credentials"   # Secret with key: api-token
    # accountId: ""                    # optional; auto-detected from token
  proxy:
    tunnelTokenSecretRef:
      name: "cloudflare-tunnel-token"  # Secret with key: tunnel-token
  controller:
    gatewayClassName: *gatewayClassName
    controllerName: "cf.k8s.lex.la/tunnel-controller"
```

Notes:
- The anchor DRYs the default but does not propagate through `--set` (documented
  inline, matching the nginx chart convention).
- Exact nested key paths (`proxy.tunnelTokenSecretRef`, etc.) are verified
  against the pinned upstream `values.yaml` during implementation before
  declaring done.

## 7. Templates

### 7.1 domain-gateways.yaml
Port of `drunk-nginx-gateway/templates/domain-gateways.yaml` verbatim in
structure: iterates `.Values.domains`, renders one `Gateway` per enabled entry
with `gatewayClassName`, listeners, `tls` passthrough (kept optional — a user
*could* still terminate TLS in-cluster, but the default examples are HTTP), and
the `routeAccess`-driven `allowedRoutes` fallback. No changes to this logic; it
is controller-agnostic.

### 7.2 _helpers.tpl
Subset of the nginx helpers actually used here:
`gateway.name`, `gateway.fullname`, `gateway.chart`, `gateway.labels`,
`gateway.selectorLabels`, `gateway.ns`, `gateway.crdURL`. Drop
`gateway.serviceAccountName` (unused).

### 7.3 NOTES.txt
Rewritten for the tunnel model:
- Gateway API CRD install reminder (`gateway.crdURL`, v1.6.1).
- Confirm the two required Secrets exist.
- GatewayClass is owned by the subchart (`cloudflare-tunnel` /
  `cf.k8s.lex.la/tunnel-controller`).
- List rendered domain Gateways.
- ⚠️ Exclusive-tunnel-ownership warning.
- Example HTTPRoute + drunk-app usage.

No GatewayClass / cert-manager sections.

## 8. Scripts

- **build.sh** — port of nginx `build.sh`: ensures `crds/.gitkeep`, `helm
  dependency update` (pulls the controller subchart), `helm package`, `helm
  repo index` with URL `.../drunk-cloudflare-tunnel-gateway`.
- **install.sh** — two-phase, ported and simplified:
  - Phase 1: install Gateway API CRDs (default `v1.6.1`) via kubectl, unless
    `SKIP_CRDS=true`.
  - Phase 1.5: **print the two `kubectl create secret` commands** and check the
    secrets exist (warn if missing) — we reference, not create them.
  - Phase 2: `helm upgrade --install` (subchart CRDs allowed, no `--skip-crds`
    since the controller ships `GatewayClassConfig`).
  - Drop all NGF/cert-manager-specific branches.
- **uninstall.sh** — helm uninstall + optional Gateway API CRD cleanup; note
  that the referenced Secrets are left to the user (we never created them).
- **verify.sh** — adapted checks:
  - `helm lint`
  - Chart.yaml name = `drunk-cloudflare-tunnel-gateway`, has version
  - dependency `cloudflare-tunnel-gateway-controller` present
  - required templates exist (`_helpers.tpl`, `NOTES.txt`,
    `domain-gateways.yaml`)
  - `helm dependency build` then `helm template` renders with defaults
  - `domains[0]` scenario renders `<name>-gateway`
  - required values keys present (`gatewayAPI`, `domains`, `routeAccess`,
    `cloudflareTunnel`)
  - scripts exist and are executable

## 9. README.md
Concise: what it does, prerequisites (Cloudflare account, a created Tunnel +
Tunnel ID, an API token), the two Secrets and how to create them, install via
`install.sh` or raw helm, the `domains[]` + HTTPRoute authoring model, the
exclusive-ownership warning, and uninstall.

## 10. Success criteria

1. `helm dependency build drunk-cloudflare-tunnel-gateway` resolves the
   vendored controller subchart.
2. `helm lint` passes.
3. `helm template` with defaults renders cleanly (subchart controller +
   GatewayClassConfig; no GatewayClass rendered by this wrapper).
4. `helm template --set domains[0]...` renders a `<name>-gateway` Gateway with
   `gatewayClassName: cloudflare-tunnel`.
5. `bash drunk-cloudflare-tunnel-gateway/verify.sh` exits 0.
6. No credentials appear anywhere in the chart; only Secret *names*.
7. No cert-manager / LoadBalancer / GatewayClass template exists in the chart.

## 11. Out of scope

- CI wiring in `.github/workflows/publish-oci.yml` (add later if the user wants
  it published to GHCR — flag as a follow-up, do not modify CI in this task).
- Per-Gateway dedicated data planes (`GatewayConfig` / `spec.infrastructure`) —
  users can set these on their own Gateways; the chart does not template them.
- BackendTLSPolicy, GRPCRoute, ReferenceGrant templating — user-authored.
```
