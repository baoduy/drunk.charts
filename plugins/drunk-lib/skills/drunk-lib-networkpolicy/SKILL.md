---
name: drunk-lib-networkpolicy
description: "Use when configuring/validating the drunk-lib NetworkPolicy partial — answers questions, generates values.yaml snippets, validates a section. Triggers on: networkpolicy, netpol, ingress egress policy."
---

# drunk-lib · NetworkPolicy

You are an expert on the `drunk-lib` Helm library chart's `NetworkPolicy` partial (`drunk-lib/templates/_networkPolicy.tpl`). Help developers configure, generate, and validate the `networkPolicy` / `networkPolicies` section of `values.yaml`.

## What it renders

The partial defines `drunk-lib.networkPolicies` and supports **two configuration shapes**:

1. **Legacy single-policy** (`.Values.networkPolicy`, map) — emits one `networking.k8s.io/v1` `NetworkPolicy` named `{{ include "app.fullname" . }}{{ .Values.networkPolicy.nameSuffix | default "" }}`. This branch only runs when `.Values.networkPolicy` is set **and** `.Values.networkPolicies` is unset.
2. **Multi-policy** (`.Values.networkPolicies`, list) — emits one `NetworkPolicy` per list entry. Per-entry opt-out: an entry renders unless `enabled` is explicitly `false` (`if or (not (hasKey $policy "enabled")) $policy.enabled`). Each resource is named `{{ include "app.fullname" $root }}{{ $policy.nameSuffix | default (printf "-%s" $policy.name) }}` — so if `nameSuffix` is omitted, the policy `name` is used as a `-<name>` suffix.

In both shapes the `spec.podSelector.matchLabels` defaults to `app.selectorLabels` (i.e. the pods rendered by `drunk-lib.deployment` / `drunk-lib.statefulset`) when `podSelector` is omitted; otherwise the user-supplied map is rendered verbatim. `policyTypes`, `ingress`, and `egress` are passed through unchanged via `toYaml`. There is **no gate keyed `networkPolicy.enabled`** — presence of the map (or list entry) is the gate.

## Important deviation from the plan/spec

The plan listed a single shape with `networkPolicy.enabled`, `networkPolicy.policyTypes`, `networkPolicy.ingress[]`, `networkPolicy.egress[]`, `networkPolicy.podSelector`. **Truth:**

- The partial supports **two** top-level keys: `networkPolicy` (singular, legacy) and `networkPolicies` (plural, list).
- There is **no `.enabled` gate** on the legacy shape; presence of `.Values.networkPolicy` is sufficient. The plural shape has a per-entry `enabled` flag that defaults to `true` (opt-out).
- If both `networkPolicy` and `networkPolicies` are set, only `networkPolicies` renders — the legacy branch is short-circuited.
- The plural shape requires each entry to have a `name` field (used as the default suffix); the plan did not mention this.
- Ingress/egress are raw `toYaml` pass-throughs — the partial does not validate or normalize them.

## Include usage

```yaml
{{- include "drunk-lib.networkPolicies" . -}}
```

The partial takes the root context `.` only and captures `$root := .` so per-entry rendering still resolves `app.fullname` / `app.labels` / `app.selectorLabels`.

## Values schema

| Key | Type | Default | Required? | Notes |
|-----|------|---------|-----------|-------|
| `.Values.networkPolicy` | map | — | one of `networkPolicy`/`networkPolicies` | Legacy single-policy shape. Ignored when `networkPolicies` is also set. |
| `.Values.networkPolicy.nameSuffix` | string | `""` | no | Appended to `app.fullname` for the resource name. |
| `.Values.networkPolicy.podSelector` | map | `app.selectorLabels` | no | `matchLabels` value. Defaults to the library's selector labels (this chart's pods). |
| `.Values.networkPolicy.policyTypes` | list[string] | — | recommended | E.g. `[Ingress, Egress]`. Rendered verbatim via `toYaml`. |
| `.Values.networkPolicy.ingress` | list | — | no | Standard K8s ingress rules. Only rendered when truthy. |
| `.Values.networkPolicy.egress` | list | — | no | Standard K8s egress rules. Only rendered when truthy. |
| `.Values.networkPolicies` | list[map] | — | one of `networkPolicy`/`networkPolicies` | Multi-policy shape. Wins over `networkPolicy` if both set. |
| `.Values.networkPolicies[].name` | string | — | **yes** | Used as `-<name>` suffix on `app.fullname` when `nameSuffix` is unset. |
| `.Values.networkPolicies[].enabled` | bool | `true` (implicit when key omitted) | no | **Opt-out**. Set to `false` to skip an entry. |
| `.Values.networkPolicies[].nameSuffix` | string | `-<name>` | no | Overrides the default `-<name>` suffix. |
| `.Values.networkPolicies[].labels` | map | — | no | Extra labels merged into `metadata.labels` (after `app.labels`). |
| `.Values.networkPolicies[].podSelector` | map | `app.selectorLabels` | no | Same default rule as the legacy shape. |
| `.Values.networkPolicies[].policyTypes` | list[string] | — | recommended | E.g. `[Ingress, Egress]`. |
| `.Values.networkPolicies[].ingress` | list | — | no | Standard K8s ingress rules. |
| `.Values.networkPolicies[].egress` | list | — | no | Standard K8s egress rules. |

### Plan keys the partial does NOT read

- `.Values.networkPolicy.enabled` — not read; the legacy branch is gated on presence only.
- Any `from`/`to` shape coercion — `ingress` and `egress` are raw `toYaml` pass-throughs; you must write the full K8s rule shape.

### Hard-coded / helper-derived fields

- `metadata.labels` — `app.labels` (multi-policy also merges `labels`).
- `apiVersion: networking.k8s.io/v1`, `kind: NetworkPolicy`.
- Default `podSelector.matchLabels` — `app.selectorLabels`.

## Generate mode

When the developer says "give me a values.yaml for NetworkPolicy doing X":

**Minimal (default-deny ingress + allow DNS egress, legacy shape):**
```yaml
networkPolicy:
  policyTypes:
    - Ingress
    - Egress
  egress:
    # Allow DNS to kube-system — without this, every cluster lookup fails.
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

**Typical (multi-policy: allow ingress from gateway, allow egress to DB + DNS):**
```yaml
networkPolicies:
  - name: allow-gateway
    policyTypes: [Ingress]
    ingress:
      - from:
          - namespaceSelector:
              matchLabels:
                kubernetes.io/metadata.name: gateway-system
            podSelector:
              matchLabels:
                app.kubernetes.io/name: traefik
        ports:
          - protocol: TCP
            port: 8080

  - name: egress-dns
    policyTypes: [Egress]
    egress:
      - to:
          - namespaceSelector:
              matchLabels:
                kubernetes.io/metadata.name: kube-system
        ports:
          - protocol: UDP
            port: 53
          - protocol: TCP
            port: 53

  - name: egress-postgres
    policyTypes: [Egress]
    egress:
      - to:
          - podSelector:
              matchLabels:
                app.kubernetes.io/name: postgres
            namespaceSelector:
              matchLabels:
                kubernetes.io/metadata.name: data
        ports:
          - protocol: TCP
            port: 5432

  - name: legacy-decommissioned
    enabled: false           # opt-out: this entry does NOT render
    policyTypes: [Ingress]
```

## Validate checklist

When the developer pastes a values.yaml section, check each of these and report any miss:

- [ ] **`policyTypes: [Egress]` with no `egress` rules** — this locks down **all** egress, including DNS to kube-system. Pods can start but every outbound connection (DNS, API server, sidecars) fails. Add at least an explicit DNS egress rule (UDP/TCP port 53 to `kube-system`).
- [ ] **Default-deny without explicit DNS allow** — any policy that sets `policyTypes: [Egress]` (or `[Ingress, Egress]`) needs a UDP+TCP port-53 egress rule targeting the namespace labelled `kubernetes.io/metadata.name: kube-system`. Without it, all service resolution breaks even though the policy "looks correct".
- [ ] **Ingress rule allowing only a `namespaceSelector` that matches no namespaces** — e.g. `namespaceSelector.matchLabels.team: payments` when no namespace carries that label. Result: zero ingress reaches the pod, which looks identical to "deny all". Confirm the label exists with `kubectl get ns -l team=payments` before relying on it.
- [ ] **Both `networkPolicy` and `networkPolicies` set** — only the plural form renders. The singular `networkPolicy` block is silently ignored. Pick one shape.
- [ ] **Plural entry missing `name`** — the resource name becomes `{{ app.fullname }}-<empty>`, i.e. ends in a stray dash. Some clusters reject this as an invalid DNS label. Always set `name` per entry.
- [ ] **Custom `podSelector` that doesn't match the chart's actual pods** — when you override `podSelector`, you are responsible for matching the labels emitted by `drunk-lib.deployment` (`app.kubernetes.io/name`, `app.kubernetes.io/instance`). Common bug: typo'd `app.kubernetes.io/component` filter that excludes every pod.
- [ ] **`ingress`/`egress` written as a map instead of a list** — `toYaml` will happily render a map and produce a NetworkPolicy that fails `kubectl apply` with "expected array, got object". Both fields must be lists of rule objects.
- [ ] **CIDR-based egress to a public endpoint without `except` for cluster CIDRs** — egress `to: ipBlock.cidr: 0.0.0.0/0` plus no `except` is essentially "allow internet" and defeats the policy's purpose; intra-cluster traffic still needs explicit allow if you set `policyTypes: [Egress]`.
- [ ] **`policyTypes` omitted entirely** — `toYaml` of `nil` renders `policyTypes: null`, which K8s rejects. Always supply `policyTypes`.
- [ ] **Cluster CNI doesn't enforce NetworkPolicy** — Flannel-only clusters silently ignore everything you write here. Verify the CNI supports NetworkPolicy (Calico, Cilium, Azure CNI, AWS VPC CNI with policy, etc.) before treating these as security controls.

## Cross-refs

- `drunk-lib-deployment` — produces the pods these policies target via `app.selectorLabels` (the default `podSelector`).
- `drunk-lib-statefulset` — same selector-label contract; a policy with the default `podSelector` covers both Deployment and StatefulSet pods of this release.
- `drunk-lib-service` — Services are unaffected by NetworkPolicy directly, but ingress rules typically describe traffic that arrives **through** the Service. Port numbers in `ingress.ports` must match the container port, not the Service port.

## Last-reviewed-commit

`6daeb59`
