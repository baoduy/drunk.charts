---
name: drunk-lib-volumes
description: "Use when configuring/validating the drunk-lib Volumes / PVC partial — answers questions, generates values.yaml snippets, validates a section. Triggers on: volume, volumes, pvc, persistentvolumeclaim, emptydir, tmp volume, storage."
---

# drunk-lib · Volumes / PVC

You are an expert on the `drunk-lib` Helm library chart's `Volumes` partial (`drunk-lib/templates/_volumes.tpl`). Help developers configure, generate, and validate the `volumes` section of `values.yaml`.

## What it renders

The partial iterates `.Values.volumes` (a **map**) and emits one `v1` `PersistentVolumeClaim` per entry whose `emptyDir` is not `true`. Each PVC is named `<app.name>-<volume-key>`. Defaults: `storage: 2Gi`, `accessModes: [ReadWriteOnce]`, `volumeMode: Filesystem`. `storageClassName` falls back through `.Values.volumes.<key>.storageClassName` → `.Values.global.storageClassName` → omitted (cluster default applies). Labels come from `app.labels`.

**Critical scope note:** this partial only emits **PVCs**. It does **not** render the pod `volumes:` or container `volumeMounts:` blocks. Those are wired up by `_deployment.tpl` (and `_cronJobs.tpl`) which read the same `.Values.volumes` map. So `emptyDir`, `mountPath`, `subPath`, and `readOnly` are consumed by the **Deployment** partial, not here — they appear in `values.yaml` under the same `volumes.<key>` entry, but this skill only validates the PVC-side fields. ConfigMap/Secret/CSI volume types are **not supported** at all by either partial; the only two volume sources wired up are `emptyDir` and PVC.

## Important deviation from the plan/spec

The plan listed `volumes[]` (a list) with `name`, `type` (`pvc`/`emptyDir`/`configMap`/`secret`/`csi`), `mountPath`, `subPath`, `readOnly`, plus type-specific keys (`pvc.size`, `pvc.storageClass`, `pvc.accessModes`, `emptyDir.medium`, `emptyDir.sizeLimit`). **Truth:**

- `.Values.volumes` is a **map**, not a list. The map key is the volume name; PVC name composes to `<app.name>-<key>`.
- There is no `type` field. Volume kind is inferred from `emptyDir: true` (boolean) vs anything else (PVC). `configMap` / `secret` / `csi` volume sources are **not supported** by this partial or its sibling Deployment partial — only emptyDir and PVC. (CSI is mounted separately by the SecretProvider partial.)
- The field is **`size`** (not `pvc.size`), **`accessMode`** singular string (not `accessModes` list — the partial wraps the single value into a list), and **`storageClassName`** (not `storageClass` or `pvc.storageClass`).
- There is no `emptyDir.medium` / `emptyDir.sizeLimit` support. `emptyDir: true` is a bare boolean; rich emptyDir options aren't plumbed.
- `mountPath` / `subPath` / `readOnly` are real keys but consumed by `_deployment.tpl`, not this partial. They go in the same values block.
- `accessMode` is a **single string**, then wrapped as a one-element list. Multi-mode PVCs (`[ReadWriteOnce, ReadOnlyMany]`) are not supported.

## Include usage

```yaml
{{- include "drunk-lib.volumes" . -}}
```

The partial takes the root context `.` only and captures `$root` for the helper calls inside the range.

## Values schema

| Key | Type | Default | Required? | Notes |
|-----|------|---------|-----------|-------|
| `.Values.volumes` | map[name→spec] | — | yes (presence) | No-op when unset/empty. Each map key becomes the volume name and the PVC suffix: `<app.name>-<key>`. |
| `.Values.volumes.<key>.emptyDir` | bool | `false` | no | When `true`, **no PVC is rendered**; the Deployment partial wires up a pod-spec `emptyDir: {}` instead. Any other truthy value still skips PVC creation only when strictly `true`. |
| `.Values.volumes.<key>.size` | string (quantity) | `2Gi` | no | `spec.resources.requests.storage`. |
| `.Values.volumes.<key>.accessMode` | string | `ReadWriteOnce` | no | Singular. Becomes a one-element `accessModes` list. Allowed: `ReadWriteOnce`, `ReadOnlyMany`, `ReadWriteMany`, `ReadWriteOncePod`. |
| `.Values.volumes.<key>.storageClassName` | string | (fallback) | no | Quoted in output. Per-volume override. |
| `.Values.global.storageClassName` | string | (cluster default) | no | Chart-wide fallback if per-volume not set. If both unset, the field is omitted and the cluster default storage class is used. |
| `.Values.volumes.<key>.mountPath` | string | — | yes (consumed by deployment) | **Read by `_deployment.tpl`, not here.** Path inside containers. |
| `.Values.volumes.<key>.subPath` | string | — | no (consumed by deployment) | **Read by `_deployment.tpl`.** Optional path within the volume. |
| `.Values.volumes.<key>.readOnly` | bool | `false` | no (consumed by deployment) | **Read by `_deployment.tpl`.** Mount as read-only. |

### Plan keys the partial does NOT read

- `volumes[]` list shape with `name` — unsupported; use a map.
- `volumes[].type` — no type field; PVC vs emptyDir is inferred from `emptyDir: true`.
- `volumes[].type: configMap` / `secret` / `csi` — **not supported** by either this partial or `_deployment.tpl`. Use `.Values.configMap` / `.Values.secrets` (for envFrom) or `.Values.secretProvider` (for CSI mounts) instead — none of those produce arbitrary mountPath bindings, however.
- `pvc.size` / `pvc.storageClass` / `pvc.accessModes` — flat keys at `volumes.<key>` level, no `pvc.` nesting. Field names are `size`, `storageClassName`, `accessMode`.
- `emptyDir.medium` / `emptyDir.sizeLimit` — bare boolean only; no rich emptyDir options.
- `metadata.annotations` on PVCs (e.g. `volume.beta.kubernetes.io/storage-class`) — not rendered.

### Hard-coded / helper-derived fields

- `apiVersion: v1`, `kind: PersistentVolumeClaim`
- `metadata.name`: `{{ include "app.name" $root }}-{{ $k }}`
- `metadata.labels`: from `app.labels`
- `spec.volumeMode`: `Filesystem` (cannot be `Block`)
- `spec.accessModes`: always a one-element list

## Generate mode

When the developer says "give me a values.yaml for Volumes doing X":

**Minimal (writable `/tmp` only — required by the chart's default `readOnlyRootFilesystem: true`):**
```yaml
volumes:
  tmp:
    emptyDir: true
    mountPath: /tmp
```

No PVC is rendered (emptyDir).

**Typical (mixed: ephemeral `/tmp` plus a persistent data volume):**
```yaml
global:
  storageClassName: managed-csi   # chart-wide fallback

volumes:
  tmp:
    emptyDir: true
    mountPath: /tmp

  data:
    size: 20Gi
    accessMode: ReadWriteOnce
    storageClassName: managed-premium   # per-volume override
    mountPath: /var/lib/app
    readOnly: false

  config:
    size: 1Gi
    accessMode: ReadOnlyMany
    mountPath: /etc/app/config
    subPath: shared
    readOnly: true
```

Renders two PVCs: `<app.name>-data` (20Gi, RWO, `managed-premium`) and `<app.name>-config` (1Gi, ROX, `managed-csi`). The Deployment partial then mounts all three in the main container.

## Validate checklist

When the developer pastes a values.yaml section, check each of these and report any miss:

- [ ] **`readOnlyRootFilesystem: true` (chart default) without a `tmp` emptyDir at `/tmp`** — most runtimes (.NET, Node, JVM tmpdir, Python tempfile) crash at startup with `EROFS: read-only file system` when writing to `/tmp`. Add `volumes.tmp: { emptyDir: true, mountPath: /tmp }`.
- [ ] **PVC without `storageClassName` on a cluster with no default StorageClass** — the PVC enters `Pending` forever with `no storage class is set`. Either set `.Values.global.storageClassName`, set per-volume `storageClassName`, or annotate one StorageClass as default in the cluster. Confirm with `kubectl get sc` and look for `(default)`.
- [ ] **`accessMode: ReadWriteMany` on a StorageClass that only supports RWO** — common with Azure Disk (`managed-csi`, `managed-premium`), AWS EBS (`gp3`), GCP PD. The PVC binds to a PV that fails to mount on the second pod (`MountVolume.MountDevice failed`). For RWM, use Azure Files / EFS / Filestore drivers.
- [ ] **`accessMode` given as a list `[ReadWriteOnce, ReadOnlyMany]`** — the partial does `accessMode | default "ReadWriteOnce"` and emits `- <value>`. A list renders as `- [ReadWriteOnce, ReadOnlyMany]`, which is invalid for `accessModes[]`. Only one mode per volume is supported.
- [ ] **ConfigMap / Secret / CSI volume requested** — not supported. The partial only renders PVCs, and `_deployment.tpl` only wires emptyDir + PVC volume sources. For env-vars from ConfigMap/Secret, use `.Values.configMap` / `.Values.secrets` / `configFrom[]` / `secretFrom[]` instead. For CSI vault mounts, use `.Values.secretProvider` (auto-mounted at `/mnt/secrets-store`). There is no path to mount a ConfigMap as a file tree at a custom `mountPath` through this chart.
- [ ] **`emptyDir: false` written explicitly** — the check is `if or (not $v.emptyDir) (not (eq $v.emptyDir true))`, so `false` (or any non-`true` value) **renders a PVC**. If you wanted "no emptyDir, no PVC either", omit the entry. Don't write `emptyDir: false` thinking it's a no-op.
- [ ] **`emptyDir.medium: Memory` / `emptyDir.sizeLimit`** — the partial only accepts a boolean. Map-shaped `emptyDir` triggers the PVC branch (because `emptyDir != true`), which is almost never intended. Use `emptyDir: true` and accept default semantics.
- [ ] **`size` given as an integer (e.g. `20`) instead of a quantity string (`20Gi`)** — Helm emits `storage: 20`, which K8s parses as 20 **bytes**. Always use a Kubernetes quantity (`Mi`/`Gi`/`Ti`).
- [ ] **Volume key with uppercase or non-DNS-label characters** — the PVC name `<app.name>-<key>` must be a DNS-1123 label (lowercase, alphanumeric, dashes). Keys like `Data` or `tmp_dir` produce invalid PVC names. Stick to `[a-z0-9-]`.
- [ ] **Two volumes whose names collide after PVC composition** — e.g. with `app.name: payments`, keys `db` and `db` (in the same chart, obviously dedup'd) — but be careful with charts that share `app.name` in the same namespace. The PVC `payments-db` becomes a contention point; use distinct app names per release.
- [ ] **PVC `mountPath` defined but `volumes.<key>.mountPath` missing** — this partial doesn't validate `mountPath`, but `_deployment.tpl` will skip mounting the volume in the pod, leaving the PVC `Bound` but unused. Always pair PVCs with `mountPath`.

## Cross-refs

- `drunk-lib-deployment` — actually mounts these volumes in the pod spec (reads `mountPath`, `subPath`, `readOnly`, `emptyDir` from the same `.Values.volumes` map). PVC name contract: `<app.name>-<key>`.
- `drunk-lib-statefulset` — same volume map; for StatefulSets, prefer `volumeClaimTemplates` (per-replica PVCs) over the single PVC this partial creates, since one PVC shared across replicas requires RWX.
- `drunk-lib-configmap` — produces a ConfigMap consumed by `envFrom`, **not** as a mounted file tree. If you need files from a ConfigMap, this chart does not currently support that.
- `drunk-lib-secrets` — same caveat: env-vars only via `envFrom`, not file mounts.
- `drunk-lib-secretprovider` — separate path for CSI-mounted vault secrets at `/mnt/secrets-store`. Does not flow through `.Values.volumes`.

## Last-reviewed-commit

`1908a5a`
