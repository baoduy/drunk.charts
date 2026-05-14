---
name: drunk-lib-httproute
description: "Use when configuring/validating the drunk-lib HTTPRoute partial — answers questions, generates values.yaml snippets, validates a section. Use for Gateway API HTTP routing (`gateway.networking.k8s.io/v1`) — for legacy Ingress, see the Ingress sibling. Triggers on: httproute, gateway-api route, gateway api."
---

# drunk-lib · HTTPRoute

You are an expert on the `drunk-lib` Helm library chart's `HTTPRoute` partial (`drunk-lib/templates/_httproute.tpl`). Help developers configure, generate, and validate the `httpRoute` section of `values.yaml`.

## What it renders

The partial emits a single `gateway.networking.k8s.io/v1` `HTTPRoute` named `{{ include "app.fullname" . }}` when `.Values.httpRoute.enabled` is `true`. The gate is **opt-in**. `parentRefs` defaults to a single Gateway with the same name as the workload (`app.fullname`) when `.Values.httpRoute.parentRefs` is unset; supplying the list lets you target one or more Gateways with optional `namespace`, `sectionName`, and `port`. `hostnames` are rendered when provided. `rules` is rich: each rule supports `matches[]` (path, method, headers, queryParams), `filters[]` (`RequestRedirect`, `RequestHeaderModifier`, `URLRewrite`, `RequestMirror`, `ExtensionRef`), and `backendRefs[]` (name defaults to `app.fullname`; port defaults to `drunk.utils.ingressPort`). When `rules` is omitted entirely, the partial emits a single default rule that matches `PathPrefix /` and routes to `app.fullname` on the resolved ingress port. Several inner fields use Helm's `required` function, so missing them halts rendering with an explicit error (header `name`/`value`, queryParam `name`/`value`, filter `type`).

## Include usage

```yaml
{{- include "drunk-lib.httpRoute" . -}}
```

Note the camelCase `httpRoute` in the include name. The partial takes the root context `.` only.

## Values schema

Keys actually consumed by `_httproute.tpl`. Anything under `httpRoute:` not listed here is **silently ignored** (except for the `required` cases noted).

| Key | Type | Default | Required? | Notes |
|-----|------|---------|-----------|-------|
| `.Values.httpRoute.enabled` | bool | `false` | yes | Gate. The partial is a no-op unless truthy. |
| `.Values.httpRoute.annotations` | map | — | no | Rendered into `metadata.annotations` via `toYaml`. |
| `.Values.httpRoute.parentRefs` | list[object] | one Gateway named `app.fullname` | no | Each entry: `name` (defaults to `app.fullname`), optional `namespace`, `sectionName`, `port`. `kind` is hard-coded to `Gateway`; you cannot reference a different parent kind. |
| `.Values.httpRoute.hostnames` | list[string] | — | no | Each is quoted into `spec.hostnames`. |
| `.Values.httpRoute.rules` | list[object] | one default rule (`PathPrefix /` → `app.fullname`) | no | When empty/unset, the default rule is emitted instead. |
| `.Values.httpRoute.rules[].matches` | list[object] | one default match (`PathPrefix /`) | no | When unset, default match is rendered. |
| `.Values.httpRoute.rules[].matches[].path.type` | string | `PathPrefix` | no | `Exact`, `PathPrefix`, or `RegularExpression`. |
| `.Values.httpRoute.rules[].matches[].path.value` | string | `/` | no | URL path. |
| `.Values.httpRoute.rules[].matches[].method` | string | — | no | HTTP method match. |
| `.Values.httpRoute.rules[].matches[].headers[]` | list[object] | — | no | Each entry: `type` (default `Exact`), `name` (**required**), `value` (**required**). |
| `.Values.httpRoute.rules[].matches[].queryParams[]` | list[object] | — | no | Each entry: `type` (default `Exact`), `name` (**required**), `value` (**required**). |
| `.Values.httpRoute.rules[].filters[]` | list[object] | — | no | Each entry has a **required** `type`. Supported `type`s: `RequestRedirect`, `RequestHeaderModifier`, `URLRewrite`, `RequestMirror`, `ExtensionRef`. Any other `type` renders an empty filter body. |
| `.Values.httpRoute.rules[].filters[].requestRedirect.{scheme,hostname,path,port,statusCode}` | mixed | — | no | All optional. `path` is rendered via `toYaml` (pass the full `{ type, value }` object). |
| `.Values.httpRoute.rules[].filters[].requestHeaderModifier.{set,add,remove}` | maps/list | — | no | `set` and `add` rendered via `toYaml`; `remove` is a list of header names. |
| `.Values.httpRoute.rules[].filters[].urlRewrite.{hostname,path}` | mixed | — | no | `path` rendered via `toYaml`. |
| `.Values.httpRoute.rules[].filters[].requestMirror.backendRef` | object | — | no | Rendered verbatim via `toYaml`. |
| `.Values.httpRoute.rules[].filters[].extensionRef` | object | — | no | Note: read from the **filter entry**, not from a nested `extensionRef:` under the filter; the partial uses `.extensionRef`, which means you place `extensionRef:` at the filter level alongside `type: ExtensionRef`. |
| `.Values.httpRoute.rules[].backendRefs[]` | list[object] | one entry pointing to `app.fullname` | no | Each entry: `name` (defaults to `app.fullname`), optional `namespace`, `port` (defaults to `drunk.utils.ingressPort`), optional `weight`, optional `filters` (rendered via `toYaml`). |

### Keys related to BackendTLSPolicy (read by a sibling partial, but live under `httpRoute:`)

- `.Values.httpRoute.tlsValidation` — consumed by `drunk-lib.backendTlsPolicy` (not this partial). When set, a `BackendTLSPolicy` is rendered alongside the route.
- `.Values.httpRoute.namespace` — also consumed only by `drunk-lib.backendTlsPolicy`. The HTTPRoute itself does not use a `metadata.namespace` field here.

### Keys that LOOK supported but are NOT read

- `.Values.httpRoute.rules[].timeouts` / `.retries` — Gateway API supports these but the partial does not render them.
- `backendRefs[].group` / `.kind` — not rendered; targets are always implicit Services.
- A `parentRefs[].group` / `.kind` override — `kind` is hard-coded to `Gateway`; you cannot point at a Mesh or custom parent.

## Generate mode

When the developer says "give me a values.yaml for HTTPRoute doing X":

**Minimal (defaults to attaching to a Gateway named `app.fullname`):**
```yaml
deployment:
  enabled: true
  ports:
    http: 8080

service:
  enabled: true

httpRoute:
  enabled: true
  hostnames:
    - api.example.com
```

**Typical (custom parent Gateway, path + header match, redirect + rewrite):**
```yaml
httpRoute:
  enabled: true
  annotations:
    custom-annotation: "value"
  parentRefs:
    - name: shared-gateway
      namespace: gateway-system
      sectionName: https
  hostnames:
    - api.example.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /v1
          method: GET
          headers:
            - type: Exact
              name: X-API-Version
              value: "1"
      filters:
        - type: RequestHeaderModifier
          requestHeaderModifier:
            set:
              - name: X-Forwarded-Prefix
                value: /v1
            remove:
              - X-Internal-Debug
      backendRefs:
        - name: my-app
          port: 8080
          weight: 100

    - matches:
        - path:
            type: Exact
            value: /old
      filters:
        - type: RequestRedirect
          requestRedirect:
            scheme: https
            hostname: api.example.com
            path:
              type: ReplaceFullPath
              replaceFullPath: /v2
            statusCode: 301
      backendRefs:
        - name: my-app
```

**Traffic split (canary):**
```yaml
httpRoute:
  enabled: true
  hostnames:
    - api.example.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: my-app-stable
          port: 8080
          weight: 90
        - name: my-app-canary
          port: 8080
          weight: 10
```

## Validate checklist

When the developer pastes a values.yaml section, check each of these and report any miss:

- [ ] **`parentRefs` referring to a Gateway not in cluster** — the partial does not look up Gateways. If the referenced Gateway does not exist (or is in another namespace and lacks a matching `ReferenceGrant`), the HTTPRoute is `Accepted: False` and serves no traffic. Verify with `kubectl get gateway -n <ns>` and the route's `status.parents[*].conditions`.
- [ ] **`backendRefs[].name` not matching a Service** — the default backend is `app.fullname`, which lines up with the chart's Service. Custom names must match an existing `v1/Service` in the same namespace (or the namespace given in `backendRefs[].namespace`, with a `ReferenceGrant`).
- [ ] **Mixing path-prefix + exact-path rules with same precedence (ambiguous routing)** — Gateway API resolves ties by route specificity, but rules within a single HTTPRoute have unspecified ordering when their match specificity is equal. Use distinct `Exact` paths or distinct `PathPrefix` lengths to avoid surprise routing.
- [ ] **`filters[].type` missing** — the partial calls `required "filter type is required"`. Helm halts with an explicit error.
- [ ] **`headers[].name` / `value` or `queryParams[].name` / `value` missing** — same: `required` calls halt rendering. All four fields are mandatory per matcher.
- [ ] **`extensionRef` placed under `filters[].extensionRef.extensionRef`** — the partial reads `.extensionRef` from the filter entry, not from a nested object. Place `extensionRef:` at the filter level alongside `type: ExtensionRef`.
- [ ] **Unknown `filter.type`** (e.g. typo `URlRewrite`) — silently renders just `type: <typo>` with no body. Validate against the five supported types: `RequestRedirect`, `RequestHeaderModifier`, `URLRewrite`, `RequestMirror`, `ExtensionRef`.
- [ ] **`requestRedirect.path` or `urlRewrite.path` given as a string** — both are rendered via `toYaml` and expect an **object** (e.g. `{ type: ReplaceFullPath, replaceFullPath: /v2 }`). Strings produce malformed Gateway API objects.
- [ ] **`backendRefs[].weight` set on a single backend** — harmless but pointless; weights only matter with 2+ backends.
- [ ] **Cross-namespace `backendRefs` without `ReferenceGrant`** — Gateway API enforces explicit grants. Set `backendRefs[].namespace` AND create a `ReferenceGrant` in the target namespace.
- [ ] **`httpRoute.tlsValidation` set without backend TLS** — that key is consumed by `drunk-lib.backendTlsPolicy`, not this partial. See `drunk-lib-backend-tls-policy`.

## Cross-refs

- `drunk-lib-gateway` — the most common parent. Default `parentRefs` assumes a Gateway named `app.fullname` exists; usually you want the in-chart Gateway too, or override `parentRefs` to a shared Gateway.
- `drunk-lib-service` — backend target. `backendRefs[].name` resolves to a Service; default is `app.fullname`, on the port returned by `drunk.utils.ingressPort`.
- `drunk-lib-backend-tls-policy` — reads `.Values.httpRoute.tlsValidation` to attach a `BackendTLSPolicy` to this route's Service. Use when the backend speaks HTTPS and you need upstream cert verification.
- `drunk-lib-ingress` — legacy alternative. Use HTTPRoute on Gateway API-capable clusters for richer matching, header manipulation, and weighted routing.

## Last-reviewed-commit

`8701b23`
