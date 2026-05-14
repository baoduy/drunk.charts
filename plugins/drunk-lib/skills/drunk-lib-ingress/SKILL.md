---
name: drunk-lib-ingress
description: "Use when configuring/validating the drunk-lib Ingress partial — answers questions, generates values.yaml snippets, validates a section. Use for **Ingress** (networking.k8s.io/v1) HTTP exposure via an ingress controller — for Gateway API exposure see the HTTPRoute sibling. Triggers on: ingress, ingress-nginx, ingress rule."
---

# drunk-lib · Ingress

You are an expert on the `drunk-lib` Helm library chart's `Ingress` partial (`drunk-lib/templates/_ingress.tpl`). Help developers configure, generate, and validate the `ingress` section of `values.yaml`.

## What it renders

The partial emits a single `networking.k8s.io/v1` `Ingress` named `{{ include "app.fullname" . }}` when `.Values.ingress.enabled` is `true`. The gate is **opt-in** (truthy `enabled` required). Every rule's backend is hard-wired to the in-chart Service (`{{ include "app.fullname" . }}`); per-path backend overrides to a different service name are **not** supported. Each host renders one HTTP rule, with one path per host (the partial does not loop over a `paths[]` list — see schema below). The backend port is read from each host entry's optional `.port`, otherwise it falls back to the shared helper `drunk.utils.ingressPort` (which returns `80` for a single-port workload, the first port's value for multi-port, or `8080` if no ports are defined anywhere). TLS is rendered as a **single** `tls` entry covering all configured hosts, using the value of `.Values.ingress.tls` as the **secret name string** — there is no list-of-objects shape for TLS in this partial.

## Include usage

```yaml
{{- include "drunk-lib.ingress" . -}}
```

The partial takes the root context `.` only.

## Values schema

Keys actually consumed by `_ingress.tpl`. Anything under `ingress:` not listed here is **silently ignored**.

| Key | Type | Default | Required? | Notes |
|-----|------|---------|-----------|-------|
| `.Values.ingress.enabled` | bool | `false` | yes | Gate. The partial is a no-op unless this is truthy. |
| `.Values.ingress.className` | string | `nginx` | no | Sets `spec.ingressClassName`. Common values: `nginx`, `traefik`, `azure-application-gateway`. |
| `.Values.ingress.annotations` | map | — | no | Rendered into `metadata.annotations` via `toYaml`. Controller-specific knobs (cert-manager, rewrite-target, auth-url, body-size) go here. |
| `.Values.ingress.hosts[]` | list[object] | — | yes (in practice) | Each entry produces one host rule with one path. If empty/unset, `spec.rules` is empty and the Ingress is effectively useless. |
| `.Values.ingress.hosts[].host` | string | — | yes | Hostname (e.g. `api.example.com`). Quoted in output. |
| `.Values.ingress.hosts[].path` | string | `/` | no | URL path for the single rule rendered per host. |
| `.Values.ingress.hosts[].pathType` | string | `Prefix` | no | `Prefix`, `Exact`, or `ImplementationSpecific`. |
| `.Values.ingress.hosts[].port` | int | `drunk.utils.ingressPort` (`80` for single-port, first port's value for multi-port, else `8080`) | no | Backend Service port number. |
| `.Values.ingress.tls` | string | — | no | **Secret name** as a string. When set, renders one `tls` entry whose `hosts` is the full host list and `secretName` is this value. |

### Keys that LOOK supported but are NOT read

These appear in the upstream Ingress API or in larger plans, but the partial does **not** read them. Setting them in `values.yaml` is silently ignored:

- `ingress.hosts[].paths[]` — the partial renders **exactly one path per host**, taken from `host.path`/`host.pathType`. A nested `paths[]` list is ignored; if you need multiple paths under the same host with different backends, you must either repeat the host entry (same `host`, different `path`) — which the partial will accept — or fork the partial.
- `ingress.hosts[].paths[].serviceName` / `servicePort` — per-path backend override is not supported; the backend is **always** `app.fullname` on the resolved port. Different backends require a hand-written Ingress.
- `ingress.tls[]` as a list-of-objects with `hosts` / `secretName` — the partial only accepts a **string** for `.Values.ingress.tls`. List shape renders as the string representation and produces invalid YAML.
- Multiple TLS secrets — only one secret name can be supplied. If different hosts need different certificates, fork the partial.
- `ingress.defaultBackend` — not rendered.

## Generate mode

When the developer says "give me a values.yaml for Ingress doing X":

**Minimal (single host, no TLS):**
```yaml
deployment:
  enabled: true
  ports:
    http: 8080   # ingressPort helper returns 80 (single-port → 80)

service:
  enabled: true

ingress:
  enabled: true
  hosts:
    - host: api.example.com
```

**Typical (TLS + cert-manager + multi-host):**
```yaml
deployment:
  enabled: true
  ports:
    http: 8080

service:
  enabled: true

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: 16m
  hosts:
    - host: api.example.com
      path: /
      pathType: Prefix
    - host: api-internal.example.com
      path: /v1
      pathType: Prefix
  tls: api-example-tls   # SINGLE secret name string — covers both hosts above
```

**Multi-path under same host (workaround for missing `paths[]`):**
```yaml
ingress:
  enabled: true
  hosts:
    - host: api.example.com
      path: /healthz
      pathType: Exact
    - host: api.example.com
      path: /
      pathType: Prefix
```

## Validate checklist

When the developer pastes a values.yaml section, check each of these and report any miss:

- [ ] **`tls[].secretName` missing from `tlsSecrets` block or external secret** — the partial does not create the TLS Secret. The name in `.Values.ingress.tls` must resolve to a Secret of type `kubernetes.io/tls` in the same namespace, produced by `drunk-lib.tls`, cert-manager (via `annotations`), an ExternalSecret, or manual `kubectl create secret tls`. Otherwise the controller serves the default certificate and browsers warn.
- [ ] **`paths[].serviceName` not declared as a Service** — moot for this partial: per-path backend override is not supported and the backend is **always** `app.fullname`. If the developer expects a different Service per path, they must hand-write the Ingress.
- [ ] **`pathType` missing — required since networking.k8s.io/v1** — the partial defaults to `Prefix` when unset, so output is valid. But if the developer explicitly sets `pathType: ""` or `null`, the empty value renders and `kubectl apply` rejects it. Use one of `Prefix` / `Exact` / `ImplementationSpecific`.
- [ ] **`tls` written as a list-of-objects** (e.g. `tls: [{ hosts: [...], secretName: foo }]`) — the partial expects a **string** secret name. Lists render as a Go-struct string and produce invalid YAML. Use `tls: foo-tls-secret`.
- [ ] **Multiple TLS secrets (different cert per host)** — not supported by this partial. Fork it or hand-write the Ingress.
- [ ] **Multi-path per host expressed as `paths:` list under one host entry** — silently ignored. Either repeat the host with different `path` values (workaround above) or fork the partial.
- [ ] **`hosts` empty/unset with `enabled: true`** — the Ingress renders with `rules: ` empty and no TLS hosts; controllers treat it as a no-op. Always supply at least one host.
- [ ] **Single-port workload with `host.port` unset** — `drunk.utils.ingressPort` returns `80` even though the container listens on something else (e.g. `8080`). This is correct because the **Service** also publishes `port: 80` in the single-port case (see drunk-lib-service); they line up. Confirm by checking the rendered Service.
- [ ] **`className` set to a controller not installed** — the Ingress will sit unprocessed. Verify `kubectl get ingressclass`.
- [ ] **Prefer HTTPRoute on Gateway API clusters** — if the cluster has a Gateway API controller (Istio, Envoy Gateway, NGINX Gateway Fabric, cilium-gw), prefer `drunk-lib-httproute` over Ingress for richer matching, header manipulation, and weighted routing.

## Cross-refs

- `drunk-lib-service` — the backend target. Every rule points at `app.fullname`; the Service must exist (its gate is opt-out, so usually fine) and expose the port the ingress port helper resolves to.
- `drunk-lib-tls-secrets` — if the value passed to `.Values.ingress.tls` is produced by the chart itself, it comes from this partial. Cert-manager-issued secrets are an alternative (via annotations).
- `drunk-lib-httproute` — Gateway API alternative. Prefer HTTPRoute on Gateway API-capable clusters; HTTPRoute also handles richer matching, traffic splitting, and header rewriting natively.

## Last-reviewed-commit

`1908a5a`
