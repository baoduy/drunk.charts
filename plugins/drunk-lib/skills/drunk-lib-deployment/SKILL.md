---
name: drunk-lib-deployment
description: "Use when configuring/validating the drunk-lib Deployment partial — answers questions, generates values.yaml snippets, validates a section. Use for **Deployment** workloads (stateless, rolling updates) — for stateful workloads with stable identity and persistent storage, see the StatefulSet sibling instead. Triggers on: deployment, drunk-lib deployment, workload, pod spec, replicas."
---

# drunk-lib · Deployment

You are an expert on the `drunk-lib` Helm library chart's `Deployment` partial (`drunk-lib/templates/_deployment.tpl`). Help developers configure, generate, and validate the `deployment` section of `values.yaml`.

## What it renders

The partial emits a single `apps/v1` `Deployment` named `{{ include "app.fullname" . }}` when `.Values.deployment.enabled` is `true`. It composes pod metadata via `app.labels` / `app.selectorLabels`, attaches config/secret checksum annotations via `app.checksums` (so changes to `configMap` / `secrets` trigger pod rollouts), and wires in optional init containers from `.Values.global.initContainer`. The main container's image comes from `.Values.global.image:.Values.global.tag` (falling back to `.Chart.AppVersion`), and pulls env from any `configMap`, `secrets`, `configFrom[]`, `secretFrom[]`, and CSI `secretProvider` configured in the same values file. Pod scheduling (`nodeSelector`, `affinity`, `tolerations`), security contexts, resources, and volume definitions are read from the **root** `.Values.*` keys — not nested under `deployment:` — and so are shared with sibling resources (Jobs, CronJobs) rendered by `drunk-lib`. `automountServiceAccountToken` is hard-coded to `false`.

## Include usage

```yaml
{{- include "drunk-lib.deployment" . -}}
```

The partial takes the root context `.` only. It captures `$root := .` internally so nested `range` / `with` blocks can still resolve `app.secretProviderName` and friends.

## Values schema

Keys actually consumed by `_deployment.tpl`. Anything under `deployment:` not listed here is silently ignored.

| Key | Type | Default | Required? | Notes |
|-----|------|---------|-----------|-------|
| `.Values.deployment.enabled` | bool | `false` | yes | Gate. Whole partial is a no-op unless truthy. |
| `.Values.deployment.replicaCount` | int | `1` | no | Sets `spec.replicas`. |
| `.Values.deployment.strategy.type` | string | `RollingUpdate` | no | `RollingUpdate` or `Recreate`. If the whole `strategy` block is omitted, the partial still emits a default `RollingUpdate` block with `maxSurge:1`/`maxUnavailable:0`. |
| `.Values.deployment.strategy.maxSurge` | int/string | `1` | no | Only rendered when `type` is `RollingUpdate` (or unset). |
| `.Values.deployment.strategy.maxUnavailable` | int/string | `0` | no | Only rendered when `type` is `RollingUpdate` (or unset). |
| `.Values.deployment.podAnnotations` | map | — | no | Merged into `spec.template.metadata.annotations` alongside `app.checksums`. |
| `.Values.deployment.command` | list[string] | — | no | Overrides container `command`. |
| `.Values.deployment.args` | list[string] | — | no | Overrides container `args`. |
| `.Values.deployment.ports` | map[name→int] | — | no | Map of `name: containerPort`. Rendered as `containerPort` entries with `protocol: TCP`. The `http` name is required if you use the built-in probes (they hard-code `port: http`). |
| `.Values.deployment.liveness` | string (path) | — | no | HTTP path. Renders `livenessProbe.httpGet { path: <value>, port: http }` with fixed `initialDelaySeconds: 60`, `periodSeconds: 300`. Not a full probe object. |
| `.Values.deployment.readiness` | string (path) | — | no | HTTP path. Renders `readinessProbe.httpGet { path: <value>, port: http }` with K8s defaults for timings. |
| `.Values.global.image` | string | — | **yes** | Container image repo. Composed as `image: "{{ .global.image }}:{{ .global.tag | default .Chart.AppVersion }}"`. |
| `.Values.global.tag` | string | `.Chart.AppVersion` | no | Image tag. |
| `.Values.global.imagePullPolicy` | string | `Always` | no | Set on the main container. |
| `.Values.global.imagePullSecret` | string | — | no | Single secret name; rendered as a one-element `imagePullSecrets` list. (Singular, not the K8s-standard `imagePullSecrets` list.) |
| `.Values.global.initContainer.image` | string | — | no | If `global.initContainer` is set, an init container is rendered using this image with `imagePullPolicy: IfNotPresent`. |
| `.Values.global.initContainer.command` | list | — | no | Optional init-container command. |
| `.Values.global.initContainer.args` | list | — | no | Optional init-container args. |
| `.Values.serviceAccount.enabled` | bool | `false` | no | When true, sets `serviceAccountName` via `app.serviceAccountName`. Note: drunk-app sample uses `serviceAccount.create`, which this partial does NOT read. Use `enabled`. |
| `.Values.podSecurityContext` | map | — | no | Pod-level `securityContext`. |
| `.Values.securityContext` | map | — | no | Main-container and init-container `securityContext`. Project default sets `readOnlyRootFilesystem: true`. |
| `.Values.resources` | map | `{}` | no | Container `resources` (limits/requests). Applied to both init and main containers. |
| `.Values.env` | map[string→scalar] | — | no | Rendered as `name`/`value` pairs (always quoted). For `valueFrom` / `secretKeyRef`, use `configMap` / `secrets` / `*From` instead. |
| `.Values.configMap` | map | — | no | When set, the partial mounts a `configMapRef` named `<app.name>-config` via `envFrom`. The actual ConfigMap is rendered by `drunk-lib.configMap`. |
| `.Values.configFrom` | list[string] | — | no | External ConfigMap names, each added as `envFrom.configMapRef`. |
| `.Values.secrets` | map | — | no | When set, mounts `secretRef` named `<app.name>-secret`. The Secret is rendered by `drunk-lib.secrets`. |
| `.Values.secretFrom` | list[string] | — | no | External Secret names, each added as `envFrom.secretRef`. |
| `.Values.secretProvider.enabled` | bool | `false` | no | When true, mounts the CSI secrets-store volume at `/mnt/secrets-store` (read-only) and adds a `secretRef` envFrom from the provider class. |
| `.Values.volumes` | map[name→spec] | — | no | Map of `name: { mountPath, readOnly, subPath, emptyDir }`. Non-`emptyDir` entries are wired to a PVC named `<app.name>-<key>`. Mounted in both init and main containers. |
| `.Values.nodeSelector` | map | — | no | Pod `nodeSelector`. |
| `.Values.affinity` | map | — | no | Pod `affinity`. |
| `.Values.tolerations` | list | — | no | Pod `tolerations`. |

## Generate mode

When the developer says "give me a values.yaml for Deployment doing X":

**Minimal:**
```yaml
global:
  image: ghcr.io/baoduy/my-app
  tag: "1.0.0"

deployment:
  enabled: true
  replicaCount: 1
  ports:
    http: 8080
  readiness: /healthz/ready

# Required when securityContext.readOnlyRootFilesystem is true (chart default).
volumes:
  tmp:
    mountPath: /tmp
    emptyDir: true

securityContext:
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  allowPrivilegeEscalation: false
```

**Typical:**
```yaml
global:
  image: ghcr.io/baoduy/my-app
  tag: "2.4.1"
  imagePullPolicy: IfNotPresent
  imagePullSecret: ghcr-pull-secret

deployment:
  enabled: true
  replicaCount: 3
  strategy:
    type: RollingUpdate
    maxSurge: 1
    maxUnavailable: 0
  podAnnotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
  ports:
    http: 8080
    metrics: 9090
  liveness: /healthz
  readiness: /healthz/ready

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

volumes:
  tmp:
    mountPath: /tmp
    emptyDir: true

nodeSelector:
  workload: app
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          topologyKey: kubernetes.io/hostname
          labelSelector:
            matchLabels:
              app.kubernetes.io/name: my-app
```

## Validate checklist

When the developer pastes a values.yaml section, check each of these and report any miss:

- [ ] **Missing `tmp` emptyDir at `/tmp`** when `securityContext.readOnlyRootFilesystem: true` (the chart default) — without a writable `/tmp`, most runtimes (.NET, Node, JVM tmpdir) fail at startup. Add `volumes.tmp: { mountPath: /tmp, emptyDir: true }`.
- [ ] **`replicaCount: 1` with `strategy.type: RollingUpdate` and `maxUnavailable: 0`** (the partial's default) — rollouts cannot start because the lone existing pod cannot be taken down. Recommend `replicaCount: 2+` OR set `strategy.type: Recreate` OR `strategy.maxUnavailable: 1`.
- [ ] **Probes target a port not declared in `deployment.ports`** — `liveness`/`readiness` are hard-coded to `port: http`. If `deployment.ports` doesn't define a port named `http`, both probes will fail with "named port not found". Either add `http: <port>` to `deployment.ports` or remove the probe.
- [ ] **`env` entry with `valueFrom.configMapKeyRef` / `secretKeyRef`** — `.Values.env` only renders scalar `name`/`value` pairs; `valueFrom` is silently dropped. Move keyed lookups into `configMap:` / `secrets:` (creates `<app.name>-config` / `<app.name>-secret` and mounts them via `envFrom`), or list external sources in `configFrom:` / `secretFrom:`.
- [ ] **`serviceAccount.create: true` instead of `serviceAccount.enabled: true`** — the partial only reads `enabled`; `create` is ignored and no SA gets attached. (The drunk-app sample `values.yaml` has this exact bug — flag it on any copy of that snippet.)
- [ ] **`global.image` unset** — the image string renders as `":<tag>"` and the pod ImagePullBackOffs. This is the only truly required value.
- [ ] **`liveness` / `readiness` given as an object** (e.g. `httpGet:` / `tcpSocket:`) — the partial treats them as raw HTTP path strings. Anything else renders broken YAML. Use a string path like `/healthz`.
- [ ] **`global.imagePullSecret` set as a list** — it must be a single string (the partial wraps it in a one-element list). Lists render invalid YAML.

## Cross-refs

- `drunk-lib-service` — exposes the `deployment.ports` map as a Service; same port `name`s must appear in both, and probes use `port: http` so a `http` port is the de-facto contract.
- `drunk-lib-hpa` — scales this Deployment by `app.fullname`; HPA's `minReplicas` should be ≥ what you set in `deployment.replicaCount` to avoid initial scale-down.
- `drunk-lib-configmap` — produces the `<app.name>-config` ConfigMap that `envFrom` consumes when `.Values.configMap` is set.
- `drunk-lib-secrets` — produces the `<app.name>-secret` Secret that `envFrom` consumes when `.Values.secrets` is set.
- `drunk-lib-volumes` — renders PVCs named `<app.name>-<volumeKey>` matching the `claimName` the Deployment expects for non-`emptyDir` entries in `.Values.volumes`.
- `drunk-lib-networkpolicy` — applies ingress/egress to the pods this Deployment creates; matched via `app.selectorLabels`.
- `drunk-lib-serviceaccount` — provisions the SA referenced by `serviceAccountName` when `.Values.serviceAccount.enabled` is true.

## Last-reviewed-commit

`b964e97`
