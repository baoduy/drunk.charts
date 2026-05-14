---
name: drunk-lib-gateway
description: "Use when configuring/validating the drunk-lib Gateway partial — answers questions, generates values.yaml snippets, validates a section. Use for Kubernetes Gateway API `Gateway` resources (`gateway.networking.k8s.io/v1`) — for the routes attached to them, see HTTPRoute. Triggers on: gateway, gateway-api gateway, listener."
---

# drunk-lib · Gateway

You are an expert on the `drunk-lib` Helm library chart's `Gateway` partial (`drunk-lib/templates/_gateway.tpl`). Help developers configure, generate, and validate the `gateway` section of `values.yaml`.

## What it renders

The partial emits a single `gateway.networking.k8s.io/v1` `Gateway` named `{{ include "app.fullname" . }}` when `.Values.gateway.enabled` is `true`. The gate is **opt-in**. `gatewayClassName` is **required** (the partial calls `required` and halts otherwise) and is quoted in output. `listeners` is iterated as a list; each entry mandates `name`, `protocol`, and `port` via `required`, with optional `hostname`, `allowedRoutes`, and `tls`. `allowedRoutes` is rendered verbatim via `toYaml`, so any K8s-supported shape (`namespaces: { from: All }`, selector-based) passes through unvalidated. The `tls` block supports `mode`, `certificateRefs[]` (with optional `namespace`, `group`, `kind`), and arbitrary `options` (rendered via `toYaml`). Listener-level annotations are not supported; only `gateway.annotations` at the top level.

## Include usage

```yaml
{{- include "drunk-lib.gateway" . -}}
```

The partial takes the root context `.` only.

## Values schema

Keys actually consumed by `_gateway.tpl`. Anything under `gateway:` not listed here is **silently ignored** (except for the `required` cases noted, which halt rendering).

| Key | Type | Default | Required? | Notes |
|-----|------|---------|-----------|-------|
| `.Values.gateway.enabled` | bool | `false` | yes | Gate. The partial is a no-op unless truthy. |
| `.Values.gateway.gatewayClassName` | string | — | **yes** | The partial halts with `gateway.gatewayClassName is required` if unset. Common values: `istio`, `envoy-gateway`, `nginx`, `cilium`. Quoted in output. |
| `.Values.gateway.annotations` | map | — | no | Rendered into `metadata.annotations` via `toYaml`. |
| `.Values.gateway.listeners[]` | list[object] | — | yes (in practice) | Iterated to produce `spec.listeners`. With no entries, the Gateway has no listeners and accepts no traffic. |
| `.Values.gateway.listeners[].name` | string | — | **yes** | Quoted. The partial halts if unset. Must be a valid DNS-1123 label, unique within the Gateway. |
| `.Values.gateway.listeners[].protocol` | string | — | **yes** | Quoted. The partial halts if unset. One of `HTTP`, `HTTPS`, `TCP`, `TLS`, `UDP`. |
| `.Values.gateway.listeners[].port` | int | — | **yes** | The partial halts if unset. |
| `.Values.gateway.listeners[].hostname` | string | — | no | Quoted. Optional SNI / Host filter. |
| `.Values.gateway.listeners[].allowedRoutes` | map | — | no | Rendered via `toYaml`. Supports `namespaces: { from: All\|Same\|Selector, selector: {...} }` and `kinds: [...]`. |
| `.Values.gateway.listeners[].tls.mode` | string | — | no | `Terminate` or `Passthrough`. Quoted in output. |
| `.Values.gateway.listeners[].tls.certificateRefs[]` | list[object] | — | no | Each entry: `name` (quoted), optional `namespace` (quoted), `group` (quoted), `kind` (quoted). |
| `.Values.gateway.listeners[].tls.options` | map | — | no | Rendered via `toYaml`. Implementation-specific TLS knobs (e.g. cipher suites, min-version) for Istio/Envoy/etc. |

### Keys that LOOK supported but are NOT read

- `gateway.addresses` — Gateway API supports `spec.addresses` for requesting specific load-balancer IPs / named addresses; the partial does not render it. Use controller-specific annotations on `gateway.annotations` instead, where supported.
- `gateway.infrastructure` — `spec.infrastructure` (labels/annotations propagated to managed LB resources) is not rendered.
- Per-listener annotations / labels — only the top-level `gateway.annotations` exists.
- `gateway.namespace` — not read. The Gateway lands in the release namespace.

## Generate mode

When the developer says "give me a values.yaml for Gateway doing X":

**Minimal (single HTTP listener):**
```yaml
gateway:
  enabled: true
  gatewayClassName: envoy-gateway
  listeners:
    - name: http
      protocol: HTTP
      port: 80
```

**Typical (HTTP + HTTPS with TLS termination, cross-namespace routes allowed):**
```yaml
gateway:
  enabled: true
  gatewayClassName: istio
  annotations:
    external-dns.alpha.kubernetes.io/hostname: api.example.com
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      hostname: api.example.com
      allowedRoutes:
        namespaces:
          from: All

    - name: https
      protocol: HTTPS
      port: 443
      hostname: api.example.com
      tls:
        mode: Terminate
        certificateRefs:
          - name: api-example-tls
            kind: Secret
            group: ""
        options:
          # Istio-specific min TLS version, for example.
          tls.istio.io/minProtocolVersion: TLSV1_3
      allowedRoutes:
        namespaces:
          from: Selector
          selector:
            matchLabels:
              shared-gateway-access: "true"
```

**TLS Passthrough (mTLS at the workload):**
```yaml
gateway:
  enabled: true
  gatewayClassName: envoy-gateway
  listeners:
    - name: tls-passthrough
      protocol: TLS
      port: 443
      hostname: secure.example.com
      tls:
        mode: Passthrough
      allowedRoutes:
        kinds:
          - kind: TLSRoute
```

## Validate checklist

When the developer pastes a values.yaml section, check each of these and report any miss:

- [ ] **TLS listener missing `certificateRefs`** — for `protocol: HTTPS` with `tls.mode: Terminate` (or unset), the Gateway needs at least one `certificateRefs[]` entry pointing at a `kubernetes.io/tls` Secret. Without it, the listener cannot start; the Gateway reports `Programmed: False`. Exception: `tls.mode: Passthrough` does NOT need `certificateRefs` (cert lives on the backend).
- [ ] **`allowedRoutes.namespaces.from: Selector` with no `selector` defined** — when `from` is `Selector`, you must supply `selector.matchLabels` (or `matchExpressions`); otherwise no namespace matches and no routes can attach. Use `from: All` or `from: Same` if you don't need a selector.
- [ ] **Duplicate `(port, protocol, hostname)` across listeners** — Gateway API requires each listener tuple to be unique. Duplicate listeners cause `Accepted: False` on the conflicting entries. Pick distinct hostnames or merge into one listener.
- [ ] **`gatewayClassName` set to a class not installed in the cluster** — verify with `kubectl get gatewayclass`. An unknown class leaves the Gateway in `Accepted: False, reason: InvalidParameters` or unprocessed.
- [ ] **HTTPS listener with `tls.certificateRefs[].namespace` set but no `ReferenceGrant`** — cross-namespace Secret references require an explicit `ReferenceGrant` in the Secret's namespace. Without it, the listener fails to load the cert.
- [ ] **`certificateRefs[].kind` set to something other than `Secret`** — most controllers only honor `kind: Secret` (the API default). Custom kinds require explicit controller support.
- [ ] **Listener `name` clashing across listeners** — must be unique within the Gateway; the partial does not deduplicate.
- [ ] **`protocol` lowercase** (e.g. `http`) — Gateway API enums are uppercase: `HTTP`, `HTTPS`, `TCP`, `TLS`, `UDP`. Lowercase values are rejected by the API server.
- [ ] **Expected `addresses` / `infrastructure` settings ignored** — the partial does not render either field. Use controller annotations or fork the partial.

## Cross-refs

- `drunk-lib-httproute` — the routes attached to this Gateway. Default HTTPRoute `parentRefs` targets a Gateway named `app.fullname`, so a co-rendered Gateway + HTTPRoute Just Works out of the box.
- `drunk-lib-tls-secrets` — produces the TLS Secrets named in `certificateRefs[]`. Alternative: cert-manager via top-level `gateway.annotations`.
- `drunk-lib-backend-tls-policy` — attaches `BackendTLSPolicy` to the Service so traffic from this Gateway to the backend is verified over TLS.

## Last-reviewed-commit

`b964e97`
