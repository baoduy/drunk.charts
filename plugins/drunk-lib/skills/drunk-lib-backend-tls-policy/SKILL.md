---
name: drunk-lib-backend-tls-policy
description: "Use when configuring/validating the drunk-lib BackendTLSPolicy partial — answers questions, generates values.yaml snippets, validates a section. Use to validate upstream TLS from a Gateway/HTTPRoute to a backend Service (`gateway.networking.k8s.io/v1` BackendTLSPolicy). Triggers on: backendtlspolicy, backend tls, upstream tls."
---

# drunk-lib · BackendTLSPolicy

You are an expert on the `drunk-lib` Helm library chart's `BackendTLSPolicy` partial (`drunk-lib/templates/_backend-tls-policy.tpl`). Help developers configure, generate, and validate the `httpRoute.tlsValidation` section of `values.yaml`.

## What it renders

The partial emits a single `gateway.networking.k8s.io/v1` `BackendTLSPolicy` named `{{ include "app.fullname" . }}-tls-policy` when **all** of the following hold:

1. `.Values.httpRoute` is not nil,
2. `.Values.httpRoute.enabled` is truthy, and
3. `.Values.httpRoute.tlsValidation` is set (truthy).

This is unusual: the gate lives under `httpRoute:`, not under a `backendTlsPolicy:` block. There is no `.Values.backendTlsPolicy.enabled` / `.Values.backendTlsPolicy.targetRefs[]` key — those proposed schema fields are **not read**. Instead, the partial hard-codes a single `targetRefs[]` entry pointing at the in-chart Service (`app.fullname`) with `sectionName: "https"`, and inserts a static `options: { tls-verify-depth: "1" }` block (note: `options` on a `BackendTLSPolicy` is implementation-specific and not all controllers honor it). The `validation` body is built by `toYaml`-rendering whatever object lives under `.Values.httpRoute.tlsValidation`; when `.Values.httpRoute.hostnames` is set, `hostname:` is prepended as the **first** entry from that list (un-quoted). The resource's namespace is `.Values.httpRoute.namespace | default .Release.Namespace`.

## Include usage

```yaml
{{- include "drunk-lib.backendTlsPolicy" . -}}
```

The partial takes the root context `.` only.

## Values schema

Keys actually consumed by `_backend-tls-policy.tpl`. The partial intentionally exposes very few knobs.

| Key | Type | Default | Required? | Notes |
|-----|------|---------|-----------|-------|
| `.Values.httpRoute.enabled` | bool | `false` | yes | Shared gate with the HTTPRoute. The BackendTLSPolicy renders only when this is truthy. |
| `.Values.httpRoute.tlsValidation` | map | — | yes | When set (truthy), the BackendTLSPolicy renders. The whole map is dumped into `spec.validation` via `toYaml`. Pass the standard Gateway API shape: `caCertificateRefs` and/or `wellKnownCACertificates`, optionally `subjectAltNames`. |
| `.Values.httpRoute.hostnames` | list[string] | — | no | If non-empty, the **first** hostname is inserted as `validation.hostname:` (the standard Gateway API field). |
| `.Values.httpRoute.namespace` | string | `.Release.Namespace` | no | Namespace of the BackendTLSPolicy resource. |

### Keys that the plan/spec lists but the partial does NOT read

These are the proposed fields from the plan; the partial does **not** read any of them, and setting them does nothing:

- `backendTlsPolicy.enabled` — there is no separate gate; the partial reuses `httpRoute.enabled`.
- `backendTlsPolicy.targetRefs[]` — `targetRefs` is hard-coded to a single entry `{ group: "", kind: Service, name: <app.fullname>, sectionName: "https" }`. You cannot target a different Service or a different `sectionName` through values.
- `backendTlsPolicy.validation.caCertificateRefs` / `.hostname` / `.wellKnownCACertificates` — these ARE rendered, but only via `.Values.httpRoute.tlsValidation` (`caCertificateRefs`, `wellKnownCACertificates`) and `.Values.httpRoute.hostnames[0]` (`hostname`). The partial does not read them under a `backendTlsPolicy:` key.
- Multiple target services — the partial cannot attach the policy to more than one Service.

### Implicit / hard-coded fields

- `metadata.name`: `{{ include "app.fullname" . }}-tls-policy`
- `metadata.namespace`: `.Values.httpRoute.namespace | default .Release.Namespace`
- `spec.options`: `{ tls-verify-depth: "1" }` — implementation-specific; ignored by controllers that don't recognize it.
- `spec.targetRefs`: `[{ group: "", kind: Service, name: <app.fullname>, sectionName: "https" }]`

## Generate mode

When the developer says "give me a values.yaml for BackendTLSPolicy doing X":

**Minimal (system CA roots, no SAN check):**
```yaml
httpRoute:
  enabled: true
  hostnames:
    - api.backend.svc.cluster.local
  tlsValidation:
    wellKnownCACertificates: System
```

The rendered policy validates the backend's certificate against the OS / controller trust bundle, using `api.backend.svc.cluster.local` as the expected SNI/SAN.

**Typical (custom CA Secret, explicit SAN):**
```yaml
httpRoute:
  enabled: true
  hostnames:
    - api.backend.svc.cluster.local
  tlsValidation:
    caCertificateRefs:
      - name: internal-ca-bundle
        kind: ConfigMap   # or Secret, controller-dependent
        group: ""
    subjectAltNames:
      - type: Hostname
        hostname: api.backend.svc.cluster.local
```

**Custom namespace for the policy resource:**
```yaml
httpRoute:
  enabled: true
  namespace: gateway-system   # BackendTLSPolicy lands here, not in Release.Namespace
  hostnames:
    - api.backend.example.com
  tlsValidation:
    wellKnownCACertificates: System
```

## Validate checklist

When the developer pastes a values.yaml section, check each of these and report any miss:

- [ ] **No CA refs AND no `wellKnownCACertificates: System` — validation fails** — `tlsValidation` must contain at least one of `caCertificateRefs[]` or `wellKnownCACertificates: System`. With neither, the controller has nothing to verify against and the policy is rejected (or, worse, silently no-ops on lenient controllers).
- [ ] **`hostname` mismatch with backend SAN** — the partial uses `.Values.httpRoute.hostnames[0]` as `validation.hostname`. If that hostname is the **public** hostname clients use, but the backend cert's SAN is the **internal** service DNS (`*.svc.cluster.local`), verification fails. Either align `hostnames[0]` with the cert SAN or move public hostnames to a non-first position and put the internal SAN first.
- [ ] **TargetRef to a non-Service kind** — not possible through this partial: `targetRefs` is hard-coded to `kind: Service, name: <app.fullname>`. If you wanted to target a different kind (e.g. an ExternalName or a different workload's Service), fork the partial.
- [ ] **`backendTlsPolicy.*` keys set in values** — silently ignored. The gate lives under `httpRoute.tlsValidation`. Move CA refs and validation knobs there.
- [ ] **Backend Service does not expose a port named `https`** — `targetRefs[0].sectionName: "https"` is hard-coded. The policy only applies to the Service port whose `name` is `https`. If your chart's `service.ports` (or `deployment.ports`) uses a different name like `tls` or `secure`, the policy attaches to nothing. Rename the port to `https`, or fork the partial.
- [ ] **`tlsValidation` accidentally rendered alongside an HTTPRoute that targets a different backend** — the policy always targets `app.fullname`. If the route's `backendRefs[]` point at another Service, the policy is on the wrong target.
- [ ] **`tlsValidation: {}` empty map** — counts as truthy in Helm, so the partial renders the policy with an empty `validation:` block. Controllers reject it. Either omit `tlsValidation` entirely or supply at least one validator.
- [ ] **`httpRoute.namespace` mismatched with the parent Gateway / target Service namespace** — the BackendTLSPolicy must live in the **same namespace as its target Service**. Cross-namespace target refs are not supported here.
- [ ] **`options.tls-verify-depth: "1"` not honored** — this field is hard-coded but is implementation-specific. Most upstream Gateway API conformance suites do not require it. Confirm the controller (Istio, Envoy Gateway, NGINX Gateway Fabric, cilium) honors it; otherwise it's a no-op.

## Cross-refs

- `drunk-lib-httproute` — same gate (`httpRoute.enabled`) and the same `hostnames[0]` feeds `validation.hostname`. The BackendTLSPolicy is meaningless without an HTTPRoute carrying traffic to the backend.
- `drunk-lib-gateway` — the upstream that initiates the TLS connection to the backend. The Gateway terminates client TLS; the BackendTLSPolicy governs the **re-encrypted** connection from the Gateway to the Service.
- `drunk-lib-service` — the policy's hard-coded target. The Service must expose a port named `https` for `sectionName: "https"` to attach correctly.

## Last-reviewed-commit

`4523599`
