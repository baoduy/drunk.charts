---
name: drunk-lib-job
description: "Use when configuring/validating the drunk-lib Job partial — answers questions, generates values.yaml snippets, validates a section. Use for **Job** workloads (one-shot, run-to-completion batch tasks) — for scheduled/recurring runs see the CronJob sibling, for long-running pods see Deployment/StatefulSet. Triggers on: job, one-shot job, batch job."
---

# drunk-lib · Job

You are an expert on the `drunk-lib` Helm library chart's `Job` partial (`drunk-lib/templates/_job.tpl`). Help developers configure, generate, and validate the `jobs` section of `values.yaml`.

## What it renders

The partial iterates `.Values.jobs` (a **list**, not a map) and emits one `batch/v1` `Job` per item. The resource name is `{{ include "app.name" $root }}-{{ .name }}-{{ randAlphaNum 5 | lower }}` — a random 5-char suffix is appended at template-render time so every `helm upgrade` produces a **new** Job (the previous Job is not patched, it is left behind to TTL-expire). An item is rendered unless `.enabled` is explicitly `false` — i.e. the gate is **opt-out**, not opt-in (the default is "enabled"). `backoffLimit` is **hard-coded to 4**, and `ttlSecondsAfterFinished` is **hard-coded to 604800 (7 days)**; the partial does not expose either. The partial composes per-Job labels via `app.labels` (using the root context). Image, env, configMap/secret refs, CSI `secretProvider`, volumes, service account, and security contexts are read from the **root** `.Values.*` keys — shared with sibling workloads — though each item may override `image`, `imagePullPolicy`, `command`, `args`, and `restartPolicy`. `automountServiceAccountToken` is hard-coded to `false`. Both `securityContext` (pod-level) and `securityContext` (container-level) are rendered **unconditionally** — if you don't set them, the partial emits the key followed by `null`/empty.

## Include usage

```yaml
{{- include "drunk-lib.jobs" . -}}
```

Note the plural `jobs` in the include name. The partial takes the root context `.` only and captures `$root := .` so the per-item `range` can still resolve `$.Values.*` and `app.secretProviderName`.

## Values schema

Keys actually consumed by `_job.tpl`. The partial intentionally omits many `JobSpec` knobs the upstream API supports — anything not listed here is **silently ignored**.

### Per-item keys (each entry in `.Values.jobs[]`)

| Key | Type | Default | Required? | Notes |
|-----|------|---------|-----------|-------|
| `.name` | string | — | **yes** | Used in resource name (`<app.name>-<name>-<random5>`) and container `name`. Must be a valid DNS-1123 label. |
| `.enabled` | bool | `true` (implicit) | no | **Opt-out gate.** The item renders unless `.enabled` is explicitly the literal `false` (the check is `ne (toString .enabled) "false"`). Omitting it, or setting `true`, both render. |
| `.restartPolicy` | string | `OnFailure` | no | Pod `restartPolicy`. Must be `OnFailure` or `Never` (Kubernetes rejects `Always` for Jobs). |
| `.image` | string | `{{ .Values.global.image }}:{{ .Values.global.tag \| default .Chart.AppVersion }}` | no | Per-item image override. When unset, falls back to global. |
| `.imagePullPolicy` | string | `.Values.global.imagePullPolicy` or `Always` | no | Per-item pull policy override. |
| `.command` | list[string] | — | no | Overrides container `command`. |
| `.args` | list[string] | — | no | Overrides container `args`. |

### Per-item keys that LOOK supported but are NOT read

These commonly appear on a Job but the partial does **not** read them. Setting them in `values.yaml` is silently ignored:

- `.parallelism` — not rendered. Each Job runs with the K8s default (`1`).
- `.completions` — not rendered. Always single-completion semantics.
- `.backoffLimit` — **hard-coded to 4**. To get a non-retrying job, you must fork the partial (or set `restartPolicy: Never` and ensure the container exits non-zero on terminal errors — the Job will still retry up to 4 times).
- `.activeDeadlineSeconds` — not rendered; jobs may run indefinitely.
- `.ttlSecondsAfterFinished` — **hard-coded to 604800** (7 days). Completed and failed Jobs are GC'd by the cluster controller a week after finishing.
- `.suspend` — not rendered.
- `.ports`, `.liveness`, `.readiness`, `.env`, `.resources` — there is no per-item override; all of these come from root `.Values.*` (and for ports/probes, are not rendered for Jobs at all).

### Root-level keys (shared with other workloads)

| Key | Type | Default | Required? | Notes |
|-----|------|---------|-----------|-------|
| `.Values.jobs` | list[object] | `[]` | no | Whole partial is a no-op when empty/unset. |
| `.Values.global.image` | string | — | **yes** (when item `.image` unset) | Container image repo. Composed as `image: "{{ .global.image }}:{{ .global.tag \| default .Chart.AppVersion }}"`. |
| `.Values.global.tag` | string | `.Chart.AppVersion` | no | Image tag. |
| `.Values.global.imagePullPolicy` | string | `Always` | no | Used when per-item `.imagePullPolicy` is unset. |
| `.Values.global.imagePullSecret` | string | — | no | Single secret name; rendered as a one-element `imagePullSecrets` list. |
| `.Values.serviceAccount.enabled` | bool | `false` | no | When true, sets `serviceAccountName` via `app.serviceAccountName`. The partial only reads `enabled`; `create` is ignored. |
| `.Values.podSecurityContext` | map | `null` (rendered as empty) | no | Always rendered, even when unset, because the partial emits `securityContext:` then `toYaml .Values.podSecurityContext`. |
| `.Values.securityContext` | map | `null` (rendered as empty) | no | Container-level. Same caveat: always rendered. |
| `.Values.resources` | map | `{}` | no | Container `resources` (limits/requests). |
| `.Values.env` | map[string→scalar] | — | no | Rendered as `name`/`value` pairs (always quoted). For `valueFrom` / `secretKeyRef`, use `configMap` / `secrets` / `*From` instead. |
| `.Values.configMap` | map | — | no | When set, mounts `configMapRef` named `<app.name>-config` via `envFrom`. |
| `.Values.configFrom` | list[string] | — | no | External ConfigMap names, each added as `envFrom.configMapRef`. |
| `.Values.secrets` | map | — | no | When set, mounts `secretRef` named `<app.name>-secret`. |
| `.Values.secretFrom` | list[string] | — | no | External Secret names, each added as `envFrom.secretRef`. |
| `.Values.secretProvider.enabled` | bool | `false` | no | When true, mounts the CSI secrets-store volume at `/mnt/secrets-store` (read-only) and adds a `secretRef` envFrom from the provider class. |
| `.Values.volumes` | map[name→spec] | — | no | Map of `name: { mountPath, readOnly, subPath, emptyDir }`. Non-`emptyDir` entries are wired to a PVC named `<app.name>-<key>`. |

### NOT read at the Job level

- `.Values.nodeSelector`, `.Values.affinity`, `.Values.tolerations` — the Deployment/StatefulSet partials read these, but `_job.tpl` does **not**. Job pods land wherever the default scheduler puts them.
- `.Values.global.initContainer` — init containers are a Deployment/StatefulSet feature in this chart, not available to Jobs.

## Generate mode

When the developer says "give me a values.yaml for Job doing X":

**Minimal:**
```yaml
global:
  image: ghcr.io/baoduy/my-migrator
  tag: "1.0.0"

jobs:
  - name: db-migrate
    command: ["/bin/sh", "-c"]
    args: ["./migrate.sh up"]

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
  image: ghcr.io/baoduy/my-migrator
  tag: "2.4.1"
  imagePullPolicy: IfNotPresent
  imagePullSecret: ghcr-pull-secret

jobs:
  - name: db-migrate
    restartPolicy: OnFailure
    command: ["/bin/sh", "-c"]
    args: ["./migrate.sh up --idempotent"]

  - name: seed-data
    restartPolicy: Never
    # Per-item image override for a one-off seeder packaged separately.
    image: ghcr.io/baoduy/seeder:1.2.0
    command: ["/seed"]
    args: ["--env=prod"]

  - name: paused-debug
    enabled: false   # opt-out: this item will NOT render

env:
  LOG_LEVEL: info

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
  name: migrator

volumes:
  tmp:
    mountPath: /tmp
    emptyDir: true
```

## Validate checklist

When the developer pastes a values.yaml section, check each of these and report any miss:

- [ ] **Missing or invalid `restartPolicy`** — must be `OnFailure` or `Never`. The partial defaults to `OnFailure` if unset, but if someone writes `restartPolicy: Always`, the K8s API rejects the Job.
- [ ] **`backoffLimit: 0` set in values, expecting "fail-fast"** — the partial **hard-codes `backoffLimit: 4`** and does not read this key. A non-idempotent container will be retried up to 4 times. Either make the container idempotent, or fork the partial to expose `backoffLimit`.
- [ ] **`ttlSecondsAfterFinished` set, expecting auto-cleanup at a different interval** — the partial **hard-codes 604800 (7 days)** and does not read this key. Completed Jobs pile up for one week regardless.
- [ ] **Random suffix in Job name surprises GitOps tooling** — the name includes `randAlphaNum 5 | lower`, so **every `helm upgrade` creates a new Job** (the previous one is left to TTL out). Tools like ArgoCD will report drift / orphaned resources. If you rely on Helm hooks (`pre-install` / `pre-upgrade`) for one-shot migrations, this partial is **not** the right fit — use a chart-local Helm hook Job instead.
- [ ] **`parallelism` / `completions` set on an item** — neither is read; every Job is single-completion, single-pod. If you need parallel workers, fork the partial.
- [ ] **`activeDeadlineSeconds` set on an item** — not read; Jobs may run indefinitely. Enforce timeouts inside the container.
- [ ] **`suspend: true` set on an item** — not read. Use `enabled: false` to skip an item from rendering, or `kubectl patch job ... -p '{"spec":{"suspend":true}}'` post-apply.
- [ ] **Per-item `ports` / `liveness` / `readiness` / `env` / `resources`** — none of these are read at the item level. Move env/resources to root `.Values.*`; probes/ports are not supported on Job pods by this partial.
- [ ] **`nodeSelector` / `affinity` / `tolerations` set** — read by Deployment/StatefulSet but **not** by `_job.tpl`. Job pods will not honor them.
- [ ] **`env` entry with `valueFrom.configMapKeyRef` / `secretKeyRef`** — `.Values.env` only renders scalar `name`/`value` pairs; `valueFrom` is silently dropped. Move keyed lookups into `configMap:` / `secrets:` or list external sources in `configFrom:` / `secretFrom:`.
- [ ] **`serviceAccount.create: true` instead of `serviceAccount.enabled: true`** — the partial only reads `enabled`; `create` is ignored and no SA gets attached.
- [ ] **`global.image` unset and item has no `.image`** — the image string renders as `":<tag>"` and the pod ImagePullBackOffs.
- [ ] **`global.imagePullSecret` set as a list** — it must be a single string (the partial wraps it in a one-element list). Lists render invalid YAML.
- [ ] **`.enabled: "false"` (quoted) vs `false`** — the partial uses `(toString .enabled) "false"`, so both `false` (bool) and `"false"` (string) skip the item, but `0`, `no`, `off` do **not** skip. Stick with the literal `false`.
- [ ] **`jobs` written as a map instead of a list** — the partial uses `range .Values.jobs` over a list. Map shape (`jobs: { migrate: {...} }`) silently renders nothing.

## Cross-refs

- `drunk-lib-cronjob` — sibling scheduled batch resource. Most root-level keys (`env`, `resources`, `volumes`, `securityContext`, `configMap`, `secrets`, `secretProvider`) are shared, so enabling both at once will produce pods sharing pod-level settings.
- `drunk-lib-configmap` — produces the `<app.name>-config` ConfigMap that `envFrom` consumes when `.Values.configMap` is set.
- `drunk-lib-secrets` — produces the `<app.name>-secret` Secret that `envFrom` consumes when `.Values.secrets` is set.
- `drunk-lib-serviceaccount` — provisions the SA referenced by `serviceAccountName` when `.Values.serviceAccount.enabled` is true; required if the Job needs to call the K8s API or assume a workload-identity binding.

## Last-reviewed-commit

`54b62f8`
