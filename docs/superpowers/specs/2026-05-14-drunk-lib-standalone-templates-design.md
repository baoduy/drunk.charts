# Design: drunk-lib Standalone Templates

**Feature slug:** `drunk-lib-standalone-templates`
**Date:** 2026-05-14
**Status:** Owner-approved
**Stack shape:** be-only (Helm library chart authoring)

---

## 1. Problem Statement

`drunk-lib` is a Helm library chart that ships reusable named template partials consumed via `include`. Today, several partials carry implicit dependencies on values keys that belong to other templates. A developer who wants to use only `drunk-lib.ingress` must still populate `deployment.ports` (because `drunk.utils.ingressPort` reads that key). A developer who wants to use `drunk-lib.hpa` with a StatefulSet gets a broken resource because `scaleTargetRef.kind` is hardcoded to `Deployment`.

The owner's goal is twofold:

1. **Standalone authoring** — a brand-new chart can include only one or two `drunk-lib` partials without being forced to define values keys that belong to other partials.
2. **Fine-grained opt-out** — an existing consumer (e.g. `drunk-app`) can suppress individual resources using `enabled: false` (or equivalent) without restructuring its values file.

All changes must be non-breaking: every existing consumer renders bit-for-bit identical YAML when its values are unchanged.

---

## 2. Approaches Considered

### Approach A — Per-template `enabled` flag + dedicated input keys (Selected)

Add an `enabled` flag to every resource block that lacks one. Each template reads its own values namespace for required inputs, with well-defined fallback chains where cross-template coupling currently exists (e.g. `service.ports` → `deployment.ports`). No new template names are introduced. The `drunk-lib.all` aggregator continues to work unchanged.

Trade-off: Minimal surface change; all existing consumer values files remain valid with zero edits. Only purely additive new keys.

### Approach B — Separate "slim" template variants

Introduce parallel `drunk-lib.standalone.*` named templates accepting a self-contained context dict. Existing templates are untouched.

Trade-off: Doubles the template surface. Consumer charts must choose between old and new APIs. The non-breaking guarantee becomes harder to verify. Rejected as over-engineered for this goal.

### Approach C — Full per-template values namespace with compatibility shim

Move every input under a per-template namespace and provide a shim that reads legacy keys. Consumer charts work unmodified through the shim.

Trade-off: Cleanest long-term schema, but Go template shim logic is fragile and any shim bug silently produces wrong YAML. Rejected.

**Decision: Approach A.** Delivers both goals with the smallest changeset, zero consumer breakage, and the most straightforward golden-file verification.

---

## 3. Standalone Usage Model

In the standalone model a developer writes a new application chart, adds `drunk-lib` as a dependency, and calls only the partials they need. They are not forced to populate values keys that belong to other partials.

### Concrete example — ConfigMap + Ingress only

```yaml
# values.yaml of the new chart
configMap:
  APP_ENV: production

ingress:
  enabled: true
  hosts:
    - host: myapp.example.com
      path: /
```

```yaml
# templates/all.yaml
{{ include "drunk-lib.configMap" . }}
{{ include "drunk-lib.ingress" . }}
```

After the change, `drunk.utils.ingressPort` prefers `service.ports` then `deployment.ports` then `8080`. The chart above renders correctly without any `deployment.*` keys.

### Concrete example — StatefulSet + HPA

```yaml
statefulset:
  enabled: true
  replicaCount: 3
  ports:
    http: 8080

autoscaling:
  enabled: true
  targetKind: StatefulSet
  targetApiVersion: apps/v1
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
```

```yaml
{{ include "drunk-lib.statefulset" . }}
{{ include "drunk-lib.hpa" . }}
```

The HPA's `scaleTargetRef.kind` renders as `StatefulSet` because of the new `autoscaling.targetKind` field.

### Concrete example — per-resource opt-out in drunk-app

```yaml
# Suppress the Service without touching anything else
service:
  enabled: false

deployment:
  enabled: true
  ports:
    http: 8080
```

The Deployment renders. The Service is suppressed. All other resources (configMap, secrets, ingress, etc.) are unaffected.

---

## 4. Per-Template Flexibility Goals

### 4.1 Workload templates: deployment, statefulset, cronjob, job

**Current coupling:** All four read `global.image`, `global.tag`, `global.imagePullPolicy`, `global.imagePullSecret`, `global.initContainer`, and `global.storageClassName`. They also share top-level keys: `env`, `volumes`, `configMap`, `secrets`, `secretFrom`, `configFrom`, `secretProvider`, `resources`, `podSecurityContext`, `securityContext`, `nodeSelector`, `affinity`, `tolerations`, `serviceAccount`.

**Flexibility change:**
- `deployment` — already gated on `deployment.enabled`. No structural change.
- `statefulset` — already gated on `statefulset.enabled`. No structural change.
- `cronJobs` — currently renders one resource per array entry with no top-level guard and no per-entry guard. Add optional `enabled` boolean on each array entry (default: `true`). An entry with `enabled: false` is skipped.
- `jobs` — same: add optional `enabled` boolean on each array entry (default: `true`).

**Shared top-level keys remain shared by design.** A chart that runs both a Deployment and a CronJob naturally shares environment and resource config. A standalone chart that only uses `drunk-lib.cronJobs` simply populates only the keys those templates read — unused keys (e.g. `volumes`) are absent and silently skipped.

**Existing behavior preserved:** `deployment.enabled: true` continues to render. Absent `cronJobs` or `jobs` arrays continue to produce no output.

### 4.2 service

**Current coupling:** Renders only when `.Values.deployment.ports` is set. Blocks standalone use.

**Flexibility change:**
- `drunk-lib.service` reads `service.ports` first; if absent, falls back to `deployment.ports`.
- Render condition: (`service.ports` OR `deployment.ports` is set) AND `service.enabled` is not `false`.
- `service.enabled` defaults to `true` (implicit, no value needed from existing consumers).

**Existing behavior preserved:** Consumers who set `deployment.ports` and leave `service` unset continue to get a Service via the fallback.

### 4.3 ingress

**Current coupling:** `drunk.utils.ingressPort` reads `deployment.ports`, falling back to `8080`. Template is already gated on `ingress.enabled`.

**Flexibility change:** `drunk.utils.ingressPort` is updated to prefer `service.ports` → `deployment.ports` → `8080`. No other changes.

**Existing behavior preserved:** Any consumer that sets `deployment.ports` gets the same port resolution as before.

### 4.4 gateway, httproute, backendTlsPolicy

**Current coupling:** Self-contained. Already gated on their own `enabled` flags. No coupling to `deployment.*`.

**Flexibility change:** None required. Already standalone-ready.

### 4.5 hpa

**Current coupling:** `scaleTargetRef.kind` is hardcoded to `Deployment` and `scaleTargetRef.apiVersion` is hardcoded to `apps/v1`. Blocks use with StatefulSets or custom workload kinds.

**Flexibility change:**
- Add `autoscaling.targetKind` (default: `"Deployment"`).
- Add `autoscaling.targetApiVersion` (default: `"apps/v1"`).
- Both defaults match current hardcoded values — existing consumers see identical output.

### 4.6 networkPolicy / networkPolicies

**Current coupling:** None. Already self-contained with both legacy single-policy and multi-policy modes.

**Flexibility change:** None required.

### 4.7 configMap, secrets

**Current coupling:** None. Each reads only its own values key.

**Flexibility change:** None required.

### 4.8 serviceAccount

**Current coupling:** None. Already gated on `serviceAccount.enabled`.

**Flexibility change:** None required.

### 4.9 volumes (PVC)

**Current coupling:** PVC names are derived from `app.name`. No coupling to workload type.

**Flexibility change:** None required.

### 4.10 tls-secrets

**Current coupling:** None. Self-contained under `tlsSecrets`.

**Flexibility change:** None required.

### 4.11 secretprovider

**Current coupling:** None. Self-contained under `secretProvider.enabled`.

**Flexibility change:** None required.

### 4.12 imagePull-secret

**Current coupling:** None. Self-contained under `imageCredentials`.

**Flexibility change:** None required.

---

## 5. Non-Breaking Guarantee

### 5.1 Golden-file snapshot process

A new script `drunk-lib/snapshot.sh` runs `helm template` against every known consumer chart with its default values and writes the output to `drunk-lib/tests/golden/<chart-name>.yaml`. These files are committed to the repository.

Consumer charts captured:
- `drunk-app` (default values)
- `drunk-traefik-gateway` (default values)
- `drunk-nginx-gateway` (default values)
- `drunk-squid-basic-auth` (default values)
- `drunk-sample` (default values)
- `microsoft-hello-world-app` (default values)

Golden files are captured **before** any template changes and committed as the baseline.

### 5.2 Regression check in verify.sh

`drunk-lib/verify.sh` is extended with a diff step that re-renders each consumer and diffs against its golden file. Any diff causes a non-zero exit, blocking the verify step. The full diff is printed so the developer sees exactly what changed.

Logical flow added to `verify.sh`:

```
for each consumer chart:
  helm template <consumer> > /tmp/<consumer>-current.yaml
  diff drunk-lib/tests/golden/<consumer>.yaml /tmp/<consumer>-current.yaml
  if diff non-empty: exit 1
```

### 5.3 First-migration human review

When the feature branch is opened, the developer runs `helm template` on each consumer, visually confirms the diff is empty, then commits the initial golden files alongside the template changes. The PR description documents which golden files were captured.

### 5.4 Scope of golden files

Only default-values renders are golden-filed. Edge-case value combinations (e.g. `secretProvider.enabled: true`, `autoscaling.targetKind: StatefulSet`) are verified by targeted `helm template` calls documented in the PR — not committed snapshots. This keeps the snapshot set small and maintainable.

### 5.5 Ongoing policy

Any future change to `drunk-lib/` that intentionally changes consumer output must update the golden files in the same commit. `verify.sh` enforces this automatically.

---

## 6. Naming, Values-Shape, and Include Conventions

### 6.1 No new partial names

All existing `drunk-lib.*` include names are preserved exactly. No `drunk-lib.standalone.*` variants are introduced. The public include API is unchanged.

### 6.2 New values keys (all additive)

| Key | Type | Default | Notes |
|---|---|---|---|
| `service.ports` | `map[string]int` | absent | Port map, same shape as `deployment.ports`. Falls back to `deployment.ports` when absent. |
| `service.enabled` | `bool` | `true` | Set to `false` to suppress the Service even when ports are defined. |
| `autoscaling.targetKind` | `string` | `"Deployment"` | `scaleTargetRef.kind` in the HPA. |
| `autoscaling.targetApiVersion` | `string` | `"apps/v1"` | `scaleTargetRef.apiVersion` in the HPA. |
| `cronJobs[].enabled` | `bool` | `true` | Per-entry flag. `false` skips that CronJob entry. |
| `jobs[].enabled` | `bool` | `true` | Per-entry flag. `false` skips that Job entry. |

No existing key is renamed, removed, or given a new default.

### 6.3 `drunk-lib.all` aggregator

Unchanged in signature. Continues to call every sub-template in the same order. Sub-templates that find no relevant values silently render nothing — same as today.

### 6.4 `drunk.utils.ingressPort` helper

Updated in-place. No rename. New preference order: `service.ports` → `deployment.ports` → `8080`. This is an internal helper (not listed in the public include table in README), so the update is not a breaking API change.

### 6.5 Include convention for standalone authors

A standalone chart calls any subset of `drunk-lib.*` includes directly. The only contract: populate the values keys that the included template reads. After this change, no template silently depends on keys from another template's namespace, except the following documented shared keys which are shared by design for multi-workload charts:

- `env` — environment variables injected into all workload containers
- `volumes` — shared PVC/emptyDir mounts across all workloads
- `resources` — container resource limits/requests
- `configMap` / `configFrom` — config sources mounted into all workload containers
- `secrets` / `secretFrom` — secret sources mounted into all workload containers
- `secretProvider` — CSI secret store mounted into all workload containers
- `podSecurityContext` / `securityContext` — security contexts applied to all workloads
- `serviceAccount` — service account used by all workloads
- `nodeSelector` / `affinity` / `tolerations` — scheduling constraints for all workloads
- `global.*` — image, tag, imagePullPolicy, imagePullSecret, initContainer, storageClassName

The README will be updated to document, per template, which keys are required vs. optional, and which shared keys it reads.

---

## 7. Out of Scope

The following are explicitly out of scope for this design and must not be introduced during implementation:

- Chart-version bump strategy or release numbering decisions.
- Changes to the OCI publish workflow (`.github/workflows/publish-oci.yml`).
- Any new Helm chart added to the repository.
- Migrations of consumer chart values files (consumers work unmodified; no migration is required or planned).
- Adding new template partials beyond the six values-key additions listed in §6.2.
- Changes to the `app.*` naming helpers or the `quoteStrings` helper.

---

## 8. Summary of Changes by File

| File | Change type | Description |
|---|---|---|
| `drunk-lib/templates/_service.tpl` | Modify | Read `service.ports` first, fall back to `deployment.ports`. Honor `service.enabled: false`. |
| `drunk-lib/templates/_hpa.tpl` | Modify | Use `autoscaling.targetKind` and `autoscaling.targetApiVersion` with defaults. |
| `drunk-lib/templates/_helpers.tpl` | Modify | Update `drunk.utils.ingressPort` to prefer `service.ports` → `deployment.ports` → `8080`. |
| `drunk-lib/templates/_cronjob.tpl` | Modify | Skip entries where `entry.enabled` is `false`. |
| `drunk-lib/templates/_job.tpl` | Modify | Skip entries where `entry.enabled` is `false`. |
| `drunk-lib/values.yaml` | Modify | Document new optional keys with comments. |
| `drunk-lib/README.md` | Modify | Update per-template values table; add standalone usage examples; document shared keys. |
| `drunk-lib/verify.sh` | Modify | Add golden-file diff step for all known consumer charts. |
| `drunk-lib/snapshot.sh` | New | Script to capture initial golden files from all consumer charts. |
| `drunk-lib/tests/golden/*.yaml` | New | One golden file per consumer chart, committed at feature branch open. |
