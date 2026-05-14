---
name: drunk-lib-cronjob
description: "Use when configuring/validating the drunk-lib CronJob partial — answers questions, generates values.yaml snippets, validates a section. Use for **CronJob** workloads (scheduled, recurring batch tasks) — for one-shot run-to-completion tasks see the Job sibling, for long-running pods see Deployment/StatefulSet. Triggers on: cronjob, cron, scheduled job, schedule."
---

# drunk-lib · CronJob

You are an expert on the `drunk-lib` Helm library chart's `CronJob` partial (`drunk-lib/templates/_cronjob.tpl`). Help developers configure, generate, and validate the `cronJobs` section of `values.yaml`.

## What it renders

The partial iterates `.Values.cronJobs` (a **list**, not a map) and emits one `batch/v1` `CronJob` per item, named `{{ include "app.name" $root }}-{{ .name }}`. An item is rendered unless `.enabled` is explicitly set to `false` — i.e. the gate is **opt-out**, not opt-in (the default is "enabled"). `successfulJobsHistoryLimit` and `failedJobsHistoryLimit` are **hard-coded to 1**; the partial does not expose them. The partial composes per-CronJob labels via `app.labels` (using the root context). Image, env, configMap/secret refs, CSI `secretProvider`, volumes, service account, and security contexts are read from the **root** `.Values.*` keys — shared with sibling workloads — though each item may override `image`, `imagePullPolicy`, `command`, `args`, and `restartPolicy`. `automountServiceAccountToken` is hard-coded to `false`. Both `securityContext` (pod-level) and `securityContext` (container-level) are rendered **unconditionally** — if you don't set them, the partial emits `securityContext:` followed by `null`/empty, which kube-apiserver accepts but linters may flag.

## Include usage

```yaml
{{- include "drunk-lib.cronJobs" . -}}
```

Note the camelCase `cronJobs` in the include name. The partial takes the root context `.` only and captures `$root := .` so the per-item `range` can still resolve `$.Values.*` and `app.secretProviderName`.

## Values schema

Keys actually consumed by `_cronjob.tpl`. The partial intentionally omits many `CronJobSpec` knobs the upstream API supports — anything not listed here is **silently ignored**, even if you saw it in another chart.

### Per-item keys (each entry in `.Values.cronJobs[]`)

| Key | Type | Default | Required? | Notes |
|-----|------|---------|-----------|-------|
| `.name` | string | — | **yes** | Used in resource name (`<app.name>-<name>`) and container `name`. Must be a valid DNS-1123 label. |
| `.enabled` | bool | `true` (implicit) | no | **Opt-out gate.** The item renders unless `.enabled` is explicitly the literal `false` (the check is `ne (toString .enabled) "false"`). Omitting it, or setting `true`, both render. |
| `.schedule` | string (cron) | — | **yes** | Cron expression, e.g. `"0 2 * * *"`. Rendered as `spec.schedule: "<value>"` — always quoted. |
| `.concurrencyPolicy` | string | `Forbid` | no | One of `Forbid` / `Allow` / `Replace`. |
| `.restartPolicy` | string | `OnFailure` | no | Pod `restartPolicy`. Must be `OnFailure` or `Never` (Kubernetes rejects `Always` for Jobs/CronJobs). |
| `.image` | string | `{{ .Values.global.image }}:{{ .Values.global.tag \| default .Chart.AppVersion }}` | no | Per-item image override. When unset, falls back to global. |
| `.imagePullPolicy` | string | `.Values.global.imagePullPolicy` or `Always` | no | Per-item pull policy override. |
| `.command` | list[string] | — | no | Overrides container `command`. |
| `.args` | list[string] | — | no | Overrides container `args`. |

### Per-item keys that LOOK supported but are NOT read

These are commonly expected on a CronJob but the partial does **not** read them. Setting them in `values.yaml` is silently ignored:

- `.suspend` — no way to pause via values; you must `kubectl patch` or remove the item.
- `.startingDeadlineSeconds` — not rendered.
- `.timeZone` — not rendered. The cluster's `kube-controller-manager` time zone is used.
- `.successfulJobsHistoryLimit` / `.failedJobsHistoryLimit` — hard-coded to `1`.
- `.parallelism`, `.completions`, `.backoffLimit`, `.activeDeadlineSeconds`, `.ttlSecondsAfterFinished` — the `jobTemplate.spec` is rendered without these, so K8s defaults apply (`backoffLimit: 6`, no TTL).
- `.ports`, `.liveness`, `.readiness`, `.env`, `.resources` — there is no per-item override; all of these come from root `.Values.*`.

### Root-level keys (shared with other workloads)

| Key | Type | Default | Required? | Notes |
|-----|------|---------|-----------|-------|
| `.Values.cronJobs` | list[object] | `[]` | no | Whole partial is a no-op when empty/unset. |
| `.Values.global.image` | string | — | **yes** (when item `.image` unset) | Container image repo. Composed as `image: "{{ .global.image }}:{{ .global.tag \| default .Chart.AppVersion }}"`. |
| `.Values.global.tag` | string | `.Chart.AppVersion` | no | Image tag. |
| `.Values.global.imagePullPolicy` | string | `Always` | no | Used when per-item `.imagePullPolicy` is unset. |
| `.Values.global.imagePullSecret` | string | — | no | Single secret name; rendered as a one-element `imagePullSecrets` list. |
| `.Values.serviceAccount.enabled` | bool | `false` | no | When true, sets `serviceAccountName` via `app.serviceAccountName`. The partial only reads `enabled`; `create` is ignored. |
| `.Values.podSecurityContext` | map | `null` (rendered as empty) | no | Always rendered, even when unset, because the partial emits `securityContext:` then `toYaml .Values.podSecurityContext`. Supply a map or expect an empty key. |
| `.Values.securityContext` | map | `null` (rendered as empty) | no | Container-level. Same caveat: always rendered. |
| `.Values.resources` | map | `{}` | no | Container `resources` (limits/requests). |
| `.Values.env` | map[string→scalar] | — | no | Rendered as `name`/`value` pairs (always quoted). For `valueFrom` / `secretKeyRef`, use `configMap` / `secrets` / `*From` instead. |
| `.Values.configMap` | map | — | no | When set, mounts `configMapRef` named `<app.name>-config` via `envFrom`. |
| `.Values.configFrom` | list[string] | — | no | External ConfigMap names, each added as `envFrom.configMapRef`. |
| `.Values.secrets` | map | — | no | When set, mounts `secretRef` named `<app.name>-secret`. |
| `.Values.secretFrom` | list[string] | — | no | External Secret names, each added as `envFrom.secretRef`. |
| `.Values.secretProvider.enabled` | bool | `false` | no | When true, mounts the CSI secrets-store volume at `/mnt/secrets-store` (read-only) and adds a `secretRef` envFrom from the provider class. |
| `.Values.volumes` | map[name→spec] | — | no | Map of `name: { mountPath, readOnly, subPath, emptyDir }`. Non-`emptyDir` entries are wired to a PVC named `<app.name>-<key>`. Shared across all replicas of all jobs in the schedule. |

### NOT read at the CronJob level

- `.Values.nodeSelector`, `.Values.affinity`, `.Values.tolerations` — the Deployment/StatefulSet partials read these, but `_cronjob.tpl` does **not**. CronJob pods land wherever the default scheduler puts them.
- `.Values.global.initContainer` — init containers are a Deployment/StatefulSet feature in this chart, not available to CronJobs.

## Generate mode

When the developer says "give me a values.yaml for CronJob doing X":

**Minimal:**
```yaml
global:
  image: ghcr.io/baoduy/my-batch
  tag: "1.0.0"

cronJobs:
  - name: nightly-cleanup
    schedule: "0 2 * * *"
    command: ["/bin/sh", "-c"]
    args: ["./run-cleanup.sh"]

# Always supply these — the partial renders the keys even when empty.
podSecurityContext:
  runAsNonRoot: true
securityContext:
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
```

**Typical:**
```yaml
global:
  image: ghcr.io/baoduy/my-batch
  tag: "2.4.1"
  imagePullPolicy: IfNotPresent
  imagePullSecret: ghcr-pull-secret

cronJobs:
  - name: nightly-cleanup
    schedule: "0 2 * * *"
    concurrencyPolicy: Forbid
    restartPolicy: OnFailure
    command: ["/bin/sh", "-c"]
    args: ["./run-cleanup.sh --window=24h"]

  - name: hourly-sync
    schedule: "0 * * * *"
    concurrencyPolicy: Replace
    restartPolicy: OnFailure
    # Per-item image override for a sidecar tool packaged separately.
    image: ghcr.io/baoduy/sync-tool:1.2.0
    command: ["/sync"]
    args: ["--from=s3://upstream", "--to=/var/data"]

  - name: paused-debug
    enabled: false   # opt-out: this item will NOT render
    schedule: "*/5 * * * *"

# Shared by every CronJob above (no per-item override exists).
env:
  LOG_LEVEL: info
  REGION: ap-southeast-1

configMap:
  APP_FEATURE_FLAGS: "alpha,beta"

secrets:
  DB_PASSWORD: "REPLACE_AT_DEPLOY"

configFrom:
  - shared-runtime-config
secretFrom:
  - shared-runtime-secrets

resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi

podSecurityContext:
  fsGroup: 10000
  runAsUser: 10000
  runAsGroup: 10000
securityContext:
  capabilities:
    drop: [ALL]
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  runAsNonRoot: true

serviceAccount:
  enabled: true
  name: batch-runner

volumes:
  tmp:
    mountPath: /tmp
    emptyDir: true
```

## Validate checklist

When the developer pastes a values.yaml section, check each of these and report any miss:

- [ ] **Invalid cron syntax in `schedule`** — the partial does not validate the expression; an invalid `schedule` is accepted by Helm but rejected by the K8s API server at apply time. Verify five fields (`m h dom mon dow`) or a predefined string like `@daily`. Watch for "`L`" / "`#`" / 6-field quartz syntax — Kubernetes uses the POSIX/Vixie cron grammar only.
- [ ] **`concurrencyPolicy: Forbid` (the default) with a very frequent schedule + long jobs** — every run that starts before the previous finishes is suppressed, and you get a silent backlog. If job duration regularly exceeds the schedule interval, switch to `Replace` (kill-and-restart) or `Allow`, or lengthen the interval.
- [ ] **Missing or invalid `restartPolicy`** — must be `OnFailure` or `Never`. The partial defaults to `OnFailure` if unset, but if someone writes `restartPolicy: Always`, the K8s API rejects the CronJob.
- [ ] **No resource requests/limits** — `.Values.resources` is shared by all CronJobs. Without it, jobs land in the `BestEffort` QoS class and can be evicted under node pressure mid-run. Always set at least `requests.cpu` / `requests.memory`.
- [ ] **`successfulJobsHistoryLimit` / `failedJobsHistoryLimit` set in values** — the partial **hard-codes both to 1** and does not read these keys. Setting them gives a false sense of control. If you need more history, fork the partial.
- [ ] **`suspend: true` set on an item expecting it to pause the schedule** — the partial does not read `.suspend`. Use `enabled: false` to skip an item, or `kubectl patch cronjob ... -p '{"spec":{"suspend":true}}'` post-apply.
- [ ] **`timeZone` set on an item** — not rendered. Schedules run in the controller's time zone (usually UTC). Encode the offset in the cron expression itself if needed.
- [ ] **Per-item `ports` / `liveness` / `readiness` / `env` / `resources`** — none of these are read at the item level. Move env/resources to root `.Values.*`; probes/ports are not supported on CronJob pods by this partial at all.
- [ ] **`nodeSelector` / `affinity` / `tolerations` set** — read by Deployment/StatefulSet but **not** by `_cronjob.tpl`. CronJob pods will not honor them. If scheduling constraints matter, fork the partial.
- [ ] **`env` entry with `valueFrom.configMapKeyRef` / `secretKeyRef`** — `.Values.env` only renders scalar `name`/`value` pairs; `valueFrom` is silently dropped. Move keyed lookups into `configMap:` / `secrets:` or list external sources in `configFrom:` / `secretFrom:`.
- [ ] **`serviceAccount.create: true` instead of `serviceAccount.enabled: true`** — the partial only reads `enabled`; `create` is ignored and no SA gets attached.
- [ ] **`global.image` unset and item has no `.image`** — the image string renders as `":<tag>"` and the pod ImagePullBackOffs.
- [ ] **`global.imagePullSecret` set as a list** — it must be a single string (the partial wraps it in a one-element list). Lists render invalid YAML.
- [ ] **`.enabled: "false"` (quoted) vs `false`** — the partial uses `(toString .enabled) "false"`, so both `false` (bool) and `"false"` (string) skip the item, but `0`, `no`, `off` do **not** skip. Stick with the literal `false`.
- [ ] **`cronJobs` written as a map instead of a list** — the partial uses `range .Values.cronJobs` over a list. Map shape (`cronJobs: { nightly: {...} }`) silently renders nothing.

## Cross-refs

- `drunk-lib-job` — sibling one-shot batch resource. Most root-level keys (`env`, `resources`, `volumes`, `securityContext`, `configMap`, `secrets`, `secretProvider`) are shared, so enabling both at once will produce pods sharing pod-level settings.
- `drunk-lib-configmap` — produces the `<app.name>-config` ConfigMap that `envFrom` consumes when `.Values.configMap` is set.
- `drunk-lib-secrets` — produces the `<app.name>-secret` Secret that `envFrom` consumes when `.Values.secrets` is set.
- `drunk-lib-serviceaccount` — provisions the SA referenced by `serviceAccountName` when `.Values.serviceAccount.enabled` is true; required if the CronJob needs to call the K8s API or assume a workload-identity binding.

## Last-reviewed-commit

`215e23a`
