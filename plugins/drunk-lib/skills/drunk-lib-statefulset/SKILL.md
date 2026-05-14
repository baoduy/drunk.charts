---
name: drunk-lib-statefulset
description: "Use when configuring/validating the drunk-lib StatefulSet partial — answers questions, generates values.yaml snippets, validates a section. Use for **StatefulSet** workloads (sticky identity, stable storage) — for stateless workloads with rolling updates, see the Deployment sibling instead. Triggers on: statefulset, sts, stateful workload, persistent pod."
---

# drunk-lib · StatefulSet

You are an expert on the `drunk-lib` Helm library chart's `StatefulSet` partial (`drunk-lib/templates/_statefulset.tpl`). Help developers configure, generate, and validate the `statefulset` section of `values.yaml`.

## What it renders

The partial emits a single `apps/v1` `StatefulSet` named `{{ include "app.fullname" . }}` when `.Values.statefulset.enabled` is `true`. `spec.serviceName` is **hard-coded** to `app.fullname` — the partial does not read `.Values.statefulset.serviceName`; you must provide a headless Service of that exact name via `drunk-lib-service`. The partial composes pod metadata via `app.labels` / `app.selectorLabels`, attaches config/secret checksum annotations via `app.checksums`, and wires in optional init containers from `.Values.global.initContainer`. The main container's image comes from `.Values.global.image:.Values.global.tag` (falling back to `.Chart.AppVersion`). Env, configMap/secret refs, CSI `secretProvider`, scheduling (`nodeSelector`, `affinity`, `tolerations`), security contexts, resources, and the `volumes` map are read from the **root** `.Values.*` keys — shared with sibling workloads. `automountServiceAccountToken` is hard-coded to `false`. The partial additionally renders `spec.volumeClaimTemplates` from `.Values.statefulset.volumeClaimTemplates`, automatically provisioning a PVC per replica per template.

## Include usage

```yaml
{{- include "drunk-lib.statefulset" . -}}
```

The partial takes the root context `.` only. It captures `$root := .` internally so nested `range` / `with` blocks can still resolve `app.secretProviderName` and friends.

## Values schema

Keys actually consumed by `_statefulset.tpl`. Anything under `statefulset:` not listed here is silently ignored. In particular, `.Values.statefulset.serviceName` is **NOT** read — `spec.serviceName` is fixed to `app.fullname`.

| Key | Type | Default | Required? | Notes |
|-----|------|---------|-----------|-------|
| `.Values.statefulset.enabled` | bool | `false` | yes | Gate. Whole partial is a no-op unless truthy. |
| `.Values.statefulset.replicaCount` | int | `1` | no | Sets `spec.replicas`. |
| `.Values.statefulset.podManagementPolicy` | string | `OrderedReady` | no | `OrderedReady` or `Parallel`. Always rendered. |
| `.Values.statefulset.updateStrategy` | string | `RollingUpdate` | no | Scalar string, not a map. Rendered as `updateStrategy.type: <value>`. `RollingUpdate` or `OnDelete`. No `rollingUpdate.partition` support. |
| `.Values.statefulset.podAnnotations` | map | — | no | Merged into `spec.template.metadata.annotations` alongside `app.checksums`. |
| `.Values.statefulset.command` | list[string] | — | no | Overrides main container `command`. |
| `.Values.statefulset.args` | list[string] | — | no | Overrides main container `args`. |
| `.Values.statefulset.ports` | map[name→int] | — | no | Map of `name: containerPort`. Rendered as `containerPort` entries with `protocol: TCP`. The `http` name is required if you use the built-in probes (they hard-code `port: http`). |
| `.Values.statefulset.liveness` | string (path) | — | no | HTTP path. Renders `livenessProbe.httpGet { path: <value>, port: http }` with fixed `initialDelaySeconds: 60`, `periodSeconds: 300`. Not a full probe object. |
| `.Values.statefulset.readiness` | string (path) | — | no | HTTP path. Renders `readinessProbe.httpGet { path: <value>, port: http }` with K8s defaults for timings. |
| `.Values.statefulset.volumeClaimTemplates` | list[object] | — | no | Each item: `name` (required), `mountPath` (required — used to render container `volumeMounts`), `storage` (required — request size), `storageClassName` (rendered even when empty — supply explicitly), `accessModes` (default `[ReadWriteOnce]`). No `selector`, no `volumeMode`. |
| `.Values.global.image` | string | — | **yes** | Container image repo. Composed as `image: "{{ .global.image }}:{{ .global.tag | default .Chart.AppVersion }}"`. |
| `.Values.global.tag` | string | `.Chart.AppVersion` | no | Image tag. |
| `.Values.global.imagePullPolicy` | string | `Always` | no | Set on the main container. |
| `.Values.global.imagePullSecret` | string | — | no | Single secret name; rendered as a one-element `imagePullSecrets` list. (Singular, not the K8s-standard `imagePullSecrets` list.) |
| `.Values.global.initContainer.image` | string | — | no | If `global.initContainer` is set, an init container is rendered using this image with `imagePullPolicy: IfNotPresent`. |
| `.Values.global.initContainer.command` | list | — | no | Optional init-container command. |
| `.Values.global.initContainer.args` | list | — | no | Optional init-container args. |
| `.Values.serviceAccount.enabled` | bool | `false` | no | When true, sets `serviceAccountName` via `app.serviceAccountName`. The partial only reads `enabled`; `create` is ignored. |
| `.Values.podSecurityContext` | map | — | no | Pod-level `securityContext`. |
| `.Values.securityContext` | map | — | no | Main-container and init-container `securityContext`. |
| `.Values.resources` | map | `{}` | no | Container `resources` (limits/requests). Applied to both init and main containers. |
| `.Values.env` | map[string→scalar] | — | no | Rendered as `name`/`value` pairs (always quoted). For `valueFrom` / `secretKeyRef`, use `configMap` / `secrets` / `*From` instead. |
| `.Values.configMap` | map | — | no | When set, mounts `configMapRef` named `<app.name>-config` via `envFrom`. The actual ConfigMap is rendered by `drunk-lib.configMap`. |
| `.Values.configFrom` | list[string] | — | no | External ConfigMap names, each added as `envFrom.configMapRef`. |
| `.Values.secrets` | map | — | no | When set, mounts `secretRef` named `<app.name>-secret`. |
| `.Values.secretFrom` | list[string] | — | no | External Secret names, each added as `envFrom.secretRef`. |
| `.Values.secretProvider.enabled` | bool | `false` | no | When true, mounts the CSI secrets-store volume at `/mnt/secrets-store` (read-only) and adds a `secretRef` envFrom from the provider class. |
| `.Values.volumes` | map[name→spec] | — | no | Map of `name: { mountPath, readOnly, subPath, emptyDir }`. Non-`emptyDir` entries are wired to a PVC named `<app.name>-<key>` (NOT the per-replica VCT PVC — these are shared across all replicas). Mounted in both init and main containers. |
| `.Values.nodeSelector` | map | — | no | Pod `nodeSelector`. |
| `.Values.affinity` | map | — | no | Pod `affinity`. |
| `.Values.tolerations` | list | — | no | Pod `tolerations`. |

## Generate mode

When the developer says "give me a values.yaml for StatefulSet doing X":

**Minimal:**
```yaml
global:
  image: ghcr.io/baoduy/my-db
  tag: "1.0.0"

statefulset:
  enabled: true
  replicaCount: 1
  ports:
    http: 8080
  volumeClaimTemplates:
    - name: data
      mountPath: /var/lib/data
      storage: 10Gi
      storageClassName: standard

# Headless service required for StatefulSet network identity.
# The partial hard-codes spec.serviceName to <release>-<chart> (app.fullname).
service:
  enabled: true
  clusterIP: None
  ports:
    http: 8080

securityContext:
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  allowPrivilegeEscalation: false

volumes:
  tmp:
    mountPath: /tmp
    emptyDir: true
```

**Typical:**
```yaml
global:
  image: ghcr.io/baoduy/my-db
  tag: "2.4.1"
  imagePullPolicy: IfNotPresent
  imagePullSecret: ghcr-pull-secret

statefulset:
  enabled: true
  replicaCount: 3
  podManagementPolicy: Parallel
  updateStrategy: RollingUpdate
  podAnnotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "9090"
  ports:
    http: 8080
    peer: 7000
    metrics: 9090
  liveness: /healthz
  readiness: /healthz/ready
  volumeClaimTemplates:
    - name: data
      mountPath: /var/lib/data
      storage: 50Gi
      storageClassName: managed-premium
      accessModes: [ReadWriteOnce]
    - name: wal
      mountPath: /var/lib/wal
      storage: 10Gi
      storageClassName: managed-premium

# REQUIRED: a headless Service named <release>-<chart> (matches app.fullname).
service:
  enabled: true
  clusterIP: None
  ports:
    http: 8080
    peer: 7000

env:
  LOG_LEVEL: info

configMap:
  APP_FEATURE_FLAGS: "alpha,beta"

secrets:
  DB_PASSWORD: "REPLACE_AT_DEPLOY"

resources:
  requests:
    cpu: 250m
    memory: 512Mi
  limits:
    cpu: 1000m
    memory: 2Gi

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

affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - topologyKey: kubernetes.io/hostname
        labelSelector:
          matchLabels:
            app.kubernetes.io/name: my-db
```

## Validate checklist

When the developer pastes a values.yaml section, check each of these and report any miss:

- [ ] **No headless Service defined** — the partial hard-codes `spec.serviceName` to `app.fullname`. Without a matching `Service` (typically `clusterIP: None`) of that same name, DNS-based stable identities (`<pod>-0.<svc>...`) won't resolve and the StatefulSet controller will keep pods in `Pending`. Add a `service:` block via `drunk-lib-service`.
- [ ] **`statefulset.serviceName` set in values** — the partial does NOT read it; setting it has no effect and gives a false sense of control. Remove it and rely on `app.fullname`, or rename the chart/release to match the headless Service you want.
- [ ] **`volumeClaimTemplates` entry with no `mountPath`** — without `mountPath` the partial silently skips the container `volumeMounts` entry; the PVC is provisioned but never mounted. Add `mountPath`.
- [ ] **`volumeClaimTemplates` entry with no `storageClassName`** when the cluster has no default StorageClass — PVCs stay `Pending` forever. Set it explicitly (e.g. `managed-premium`, `gp3`, `standard`).
- [ ] **`volumeClaimTemplates` entry missing `storage`** — the partial renders `storage: ` (empty), which Kubernetes rejects. Always provide a size like `10Gi`.
- [ ] **Probes target a port not declared in `statefulset.ports`** — `liveness`/`readiness` are hard-coded to `port: http`. If `statefulset.ports` doesn't define a port named `http`, both probes fail with "named port not found". Either add `http: <port>` or remove the probe.
- [ ] **`liveness` / `readiness` given as an object** (e.g. `httpGet:` / `tcpSocket:`) — the partial treats them as raw HTTP path strings. Anything else renders broken YAML. Use a string path like `/healthz`.
- [ ] **`updateStrategy` given as a map** (e.g. `{ type: RollingUpdate, rollingUpdate: { partition: 0 } }`) — the partial expects a scalar string. Anything else either renders broken YAML or is silently truncated. Use `updateStrategy: RollingUpdate` or `updateStrategy: OnDelete`.
- [ ] **`replicaCount: 1` with `podManagementPolicy: OrderedReady`** plus slow init — recovery from a wedged pod is serialized and slow. Consider `Parallel` if pods are mutually independent.
- [ ] **`env` entry with `valueFrom.configMapKeyRef` / `secretKeyRef`** — `.Values.env` only renders scalar `name`/`value` pairs; `valueFrom` is silently dropped. Move keyed lookups into `configMap:` / `secrets:` or list external sources in `configFrom:` / `secretFrom:`.
- [ ] **`serviceAccount.create: true` instead of `serviceAccount.enabled: true`** — the partial only reads `enabled`; `create` is ignored and no SA gets attached.
- [ ] **`global.image` unset** — the image string renders as `":<tag>"` and the pod ImagePullBackOffs.
- [ ] **`global.imagePullSecret` set as a list** — it must be a single string (the partial wraps it in a one-element list). Lists render invalid YAML.
- [ ] **Using `.Values.volumes` PVC entry where a per-replica VCT was intended** — `volumes.<key>` (non-`emptyDir`) creates a **single shared** PVC named `<app.name>-<key>` mounted into all replicas. For per-replica persistent storage, use `statefulset.volumeClaimTemplates` instead.

## Cross-refs

- `drunk-lib-service` — REQUIRED companion. The StatefulSet hard-codes `spec.serviceName: <app.fullname>`, so a headless Service of that exact name (typically `clusterIP: None`) must exist for stable pod DNS.
- `drunk-lib-volumes` — renders shared PVCs named `<app.name>-<volumeKey>` matching the `claimName` the StatefulSet expects for non-`emptyDir` entries in `.Values.volumes`. Per-replica PVCs from `volumeClaimTemplates` are provisioned by the StatefulSet controller itself, not by this partial.
- `drunk-lib-configmap` — produces the `<app.name>-config` ConfigMap that `envFrom` consumes when `.Values.configMap` is set.
- `drunk-lib-secrets` — produces the `<app.name>-secret` Secret that `envFrom` consumes when `.Values.secrets` is set.
- `drunk-lib-deployment` — sibling stateless workload. Most root-level keys (`env`, `resources`, `volumes`, `securityContext`, `nodeSelector`, `affinity`, `tolerations`, `configMap`, `secrets`, `secretProvider`) are shared, so enabling both at once will produce two workloads sharing pod-level settings.

## Last-reviewed-commit

`b964e97`
