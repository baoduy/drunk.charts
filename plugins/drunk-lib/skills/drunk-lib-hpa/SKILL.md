---
name: drunk-lib-hpa
description: "Use when configuring/validating the drunk-lib HorizontalPodAutoscaler partial — answers questions, generates values.yaml snippets, validates a section. Triggers on: hpa, horizontal pod autoscaler, autoscaling, scale."
---

# drunk-lib · HorizontalPodAutoscaler

You are an expert on the `drunk-lib` Helm library chart's `HorizontalPodAutoscaler` partial (`drunk-lib/templates/_hpa.tpl`). Help developers configure, generate, and validate the `autoscaling` section of `values.yaml`.

## What it renders

The partial emits a single `autoscaling/v2` `HorizontalPodAutoscaler` named `{{ include "app.fullname" . }}` when **both** `.Values.autoscaling` is set (non-nil) and `.Values.autoscaling.enabled` is truthy. Labels come from `app.labels`. The `scaleTargetRef` points at a workload that **shares the same `app.fullname`** as the HPA — typically the Deployment rendered by `drunk-lib.deployment` — with `kind` defaulting to `Deployment` and `apiVersion` defaulting to `apps/v1`. Only CPU and memory `Resource`-type metrics are supported, expressed as `Utilization` percentages; the partial does not surface custom/external metrics or the v2 `behavior` block. There is no per-metric value type other than `Utilization` (no `AverageValue`, no `Pods`, no `Object`).

## Important deviation from the plan/spec

The plan called this section `hpa.*` with fields `hpa.scaleTargetRef`, `hpa.minReplicas`, `hpa.maxReplicas`, `hpa.metrics[]`, `hpa.behavior`. **The partial does not read any of those.** The real key is `.Values.autoscaling.*` and the metric API is reduced to two scalar percentages. Truth wins: document what `_hpa.tpl` actually reads.

## Include usage

```yaml
{{- include "drunk-lib.hpa" . -}}
```

The partial takes the root context `.` only.

## Values schema

Keys actually consumed by `_hpa.tpl`. Anything under `autoscaling:` not listed here is silently ignored, and anything under a top-level `hpa:` block is silently ignored entirely.

| Key | Type | Default | Required? | Notes |
|-----|------|---------|-----------|-------|
| `.Values.autoscaling` | map | — | yes (presence) | If the whole `autoscaling:` key is absent, the partial is a no-op even if you set `enabled: true` deeper. The outer `if .Values.autoscaling` is a presence check. |
| `.Values.autoscaling.enabled` | bool | `false` | yes | Gate. The HPA renders only when truthy. |
| `.Values.autoscaling.minReplicas` | int | — | **yes** | Rendered without quoting or defaulting; if omitted, the field renders empty and the K8s API rejects the HPA. |
| `.Values.autoscaling.maxReplicas` | int | — | **yes** | Same as above — no default, no validation. |
| `.Values.autoscaling.targetCPUUtilizationPercentage` | int | — | no | When set, adds a CPU `Resource` metric with `target.type: Utilization`. Omit to skip CPU scaling. |
| `.Values.autoscaling.targetMemoryUtilizationPercentage` | int | — | no | When set, adds a memory `Resource` metric. Omit to skip memory scaling. |
| `.Values.autoscaling.targetKind` | string | `Deployment` | no | Quoted in output. Set to `StatefulSet` (or another workload kind) when not scaling a Deployment. |
| `.Values.autoscaling.targetApiVersion` | string | `apps/v1` | no | Quoted in output. |

### Plan keys the partial does NOT read

- `autoscaling.scaleTargetRef` (object) — the partial builds `scaleTargetRef` itself from `targetKind` / `targetApiVersion` / `app.fullname`. You cannot override `name`.
- `autoscaling.metrics[]` (free-form list) — only the two `target*UtilizationPercentage` scalars are honored.
- `autoscaling.behavior` — scale-up/scale-down policies are not rendered. The HPA uses the K8s controller defaults.
- Pods, Object, External, custom metrics — unsupported by this partial.
- Per-metric `averageValue` / `value` (absolute, not %) — unsupported.

## Generate mode

When the developer says "give me a values.yaml for HPA doing X":

**Minimal (CPU only):**
```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 6
  targetCPUUtilizationPercentage: 70
```

**Typical (CPU + memory, StatefulSet target):**
```yaml
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 12
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
  targetKind: StatefulSet
  targetApiVersion: apps/v1
```

## Validate checklist

When the developer pastes a values.yaml section, check each of these and report any miss:

- [ ] **`autoscaling.enabled: true` while `deployment.replicaCount` is also set** — the values fight: at apply time the HPA will immediately scale the Deployment to `minReplicas`, overriding the static `replicaCount`. On the next `helm upgrade`, the Deployment manifest will re-set `replicaCount`, then the HPA scales it back. Use `replicaCount` as a one-time seed (≥ `minReplicas`) or remove it once HPA owns scaling.
- [ ] **`minReplicas` > `maxReplicas`** — the partial passes both through unchanged; K8s API rejects the HPA at apply time. Verify `minReplicas <= maxReplicas`.
- [ ] **CPU or memory metric set but no `resources.requests`** — `Utilization` percentages are computed against the container's resource **requests**. With no `requests.cpu` / `requests.memory` on the Deployment (root-level `.Values.resources`), the metric is `<unknown>` and the HPA cannot scale. Always pair `targetCPUUtilizationPercentage` with `resources.requests.cpu`, and likewise for memory.
- [ ] **ScaleTargetRef points at a workload that isn't declared** — the HPA's `scaleTargetRef.name` is hard-coded to `app.fullname`. If neither `deployment.enabled` nor `statefulSet.enabled` is true, the HPA targets a non-existent workload and reports `FailedGetScale`. Either enable the matching workload partial in the same release or skip the HPA.
- [ ] **Both `targetCPUUtilizationPercentage` and `targetMemoryUtilizationPercentage` unset** — the rendered `metrics:` list is empty and the K8s API rejects the HPA (`spec.metrics: Required value`). At least one must be set.
- [ ] **`autoscaling.metrics[]` / `autoscaling.behavior` / `autoscaling.scaleTargetRef` set in values** — silently ignored. Fork the partial if you need v2 custom metrics or scale policies.
- [ ] **`minReplicas: 0`** — K8s requires `minReplicas >= 1` unless the `HPAScaleToZero` feature gate is enabled cluster-wide. The partial does not warn.
- [ ] **`targetKind: StatefulSet` without `statefulSet.enabled: true`** — same trap as above: the named workload must exist.

## Cross-refs

- `drunk-lib-deployment` — default scale target. The HPA's `scaleTargetRef.name` is `app.fullname`, matching the Deployment's name. `deployment.replicaCount` should be `>= autoscaling.minReplicas` (or omitted) to avoid initial scale-down.
- `drunk-lib-statefulset` — alternate scale target when `autoscaling.targetKind: StatefulSet`. Same `app.fullname` contract.

## Last-reviewed-commit

`fa807f8`
