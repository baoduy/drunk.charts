---
name: drunk-lib-service
description: "Use when configuring/validating the drunk-lib Service partial — answers questions, generates values.yaml snippets, validates a section. Use for in-cluster Service exposure of a workload's container ports (ClusterIP, NodePort, LoadBalancer). Triggers on: service, svc, clusterip, nodeport, loadbalancer."
---

# drunk-lib · Service

You are an expert on the `drunk-lib` Helm library chart's `Service` partial (`drunk-lib/templates/_service.tpl`). Help developers configure, generate, and validate the `service` section of `values.yaml`.

## What it renders

The partial emits a single `v1` `Service` named `{{ include "app.fullname" . }}` when a port source is resolvable AND `.Values.service.enabled` is not explicitly `false`. The gate is **opt-out**: if `.Values.service` is unset, the Service still renders as long as ports exist somewhere; you must write `service: { enabled: false }` to suppress it. Port source resolution is hard-wired: first `.Values.service.ports` (when it is a map), else fall back to `.Values.deployment.ports`. If both are empty/missing, the partial silently emits nothing. **Special case for a single port**: when exactly one port is resolved, the Service publishes `port: 80` mapping to `targetPort: <portName>` — the value in the map (the container port number) is **ignored** on the Service side. With two or more ports, each entry renders as `port: <value>`, `targetPort: <key>`, `name: <key>`, `protocol: TCP`. Selector is built from `app.selectorLabels`, so it matches the Deployment/StatefulSet rendered by the same chart.

## Include usage

```yaml
{{- include "drunk-lib.service" . -}}
```

The partial takes the root context `.` only.

## Values schema

Keys actually consumed by `_service.tpl`. Anything under `service:` not listed here is **silently ignored**.

| Key | Type | Default | Required? | Notes |
|-----|------|---------|-----------|-------|
| `.Values.service.enabled` | bool | implicit `true` | no | **Opt-out gate.** The Service renders unless this is explicitly the literal `false` (checked via `eq (toString $svc.enabled) "false"`). Omitting it does NOT suppress the Service. |
| `.Values.service.type` | string | `ClusterIP` | no | Sets `spec.type`. Any K8s-supported value (`ClusterIP`, `NodePort`, `LoadBalancer`, `ExternalName`). |
| `.Values.service.ports` | map[name→int] | — | no | Map of `name: containerPort`. When present, takes precedence over `deployment.ports`. Must be a map; lists are ignored. |
| `.Values.deployment.ports` | map[name→int] | — | no | Fallback port source when `service.ports` is unset. Same `name: containerPort` shape. |

### Keys that LOOK supported but are NOT read

These appear in the plan/spec but the partial does **not** read them. Setting them in `values.yaml` is silently ignored:

- `service.ports[].port` / `targetPort` / `protocol` / `nodePort` — the partial does not accept a list-of-objects shape for ports; it only reads the **map** form `{ name: containerPort }`. Per-port `protocol` is hard-coded to `TCP`; `nodePort` cannot be set; `port`/`targetPort` are derived as described above (single-port → `port: 80`).
- `service.annotations` — not rendered. Cloud-controller / metallb / external-dns annotations cannot be set through this partial.
- `service.clusterIP` — not rendered. Headless services (`clusterIP: None`) are not supported by this partial; pair the StatefulSet with a hand-written Service if you need one.
- `service.externalTrafficPolicy` — not rendered.
- `service.sessionAffinity` — not rendered.

## Generate mode

When the developer says "give me a values.yaml for Service doing X":

**Minimal (single port, relies on deployment.ports):**
```yaml
deployment:
  enabled: true
  ports:
    http: 8080

# .Values.service can be omitted entirely; the Service still renders
# because deployment.ports has one entry. The published port will be 80,
# mapped to targetPort: http.
```

**Typical (multi-port, explicit type):**
```yaml
deployment:
  enabled: true
  ports:
    http: 8080
    metrics: 9090

service:
  enabled: true
  type: ClusterIP
  # ports omitted → falls back to deployment.ports (recommended;
  # avoids drift between Service and container ports).

# To suppress the Service entirely even though ports exist:
# service:
#   enabled: false
```

**Override ports explicitly (e.g. expose only a subset):**
```yaml
deployment:
  enabled: true
  ports:
    http: 8080
    debug: 5005     # not exposed by Service

service:
  enabled: true
  type: LoadBalancer
  ports:
    http: 8080      # only this one will be published
```

## Validate checklist

When the developer pastes a values.yaml section, check each of these and report any miss:

- [ ] **`targetPort` not declared by Deployment/StatefulSet container ports** — `targetPort` is set to the map **key**, which must match a `containerPort` `name` on the workload. If `deployment.ports` (or `statefulSet.ports`) does not include the same name, the Service has no endpoints. Either align the names or remove the entry.
- [ ] **`type: LoadBalancer` without cloud-controller annotations on managed clusters** — this partial does **not** render `service.annotations`. Cloud-specific knobs (AWS NLB scheme, Azure internal LB, GCP backend config, metallb pool, external-dns hostname) cannot be supplied here. If the cluster needs them, fork the partial or hand-write the Service.
- [ ] **Headless Service for StatefulSet missing `clusterIP: None`** — the partial does not expose `clusterIP`. StatefulSets that need stable DNS-per-pod (`<pod>.<svc>`) require a headless governing Service; this partial cannot produce one. Hand-write the headless Service alongside, or fork the partial.
- [ ] **Ports written as a list of objects** (e.g. `ports: [{ name: http, port: 80, targetPort: 8080 }]`) — the partial only accepts the map shape `{ http: 8080 }`. The list shape is silently ignored and the Service renders with no ports (or nothing at all).
- [ ] **Single-port surprise: `port: 80` regardless of value** — with exactly one port in the resolved map, the published `port` is hard-coded to `80` and the map value is ignored. If you expected the Service `port` to equal the container port, add a second port (e.g. a `metrics` port) or fork the partial.
- [ ] **`service.enabled` omitted, expecting "off by default"** — the gate is **opt-out**. Omitting `service:` while `deployment.ports` is non-empty still renders a Service. Set `service: { enabled: false }` to suppress.
- [ ] **Non-TCP protocol expected** — `protocol` is hard-coded to `TCP`. `UDP` / `SCTP` ports are not supported.
- [ ] **`nodePort` set on a `NodePort`/`LoadBalancer` Service** — not read. The cluster auto-assigns a node port; you cannot pin it through this partial.

## Cross-refs

- `drunk-lib-deployment` — the most common port source. The map keys in `deployment.ports` become Service port `name`s and `targetPort`s; the values become container ports (and Service `port` when there are 2+ entries).
- `drunk-lib-statefulset` — same port-source pattern as Deployment. Note this partial cannot render a headless governing Service; if you need stable per-pod DNS, hand-write that Service.
- `drunk-lib-ingress` — backends reference this Service by `app.fullname`. With a single port, Ingress targets port `80` (see `drunk.utils.ingressPort`); with multiple, the first port's value is used.
- `drunk-lib-httproute` — `backendRefs[].name` defaults to `app.fullname` and resolves to this Service. Port resolution uses the same `drunk.utils.ingressPort` helper.

## Last-reviewed-commit

`11f84f0`
