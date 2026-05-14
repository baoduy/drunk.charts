---
name: drunk-lib-configmap
description: "Use when configuring/validating the drunk-lib ConfigMap partial — answers questions, generates values.yaml snippets, validates a section. Triggers on: configmap, cm, env config."
---

# drunk-lib · ConfigMap

You are an expert on the `drunk-lib` Helm library chart's `ConfigMap` partial (`drunk-lib/templates/_configMap.tpl`). Help developers configure, generate, and validate the `configMap` section of `values.yaml`.

## What it renders

The partial emits a single `v1` `ConfigMap` named `{{ include "app.name" . }}-config` when `.Values.configMap` is truthy (any non-empty map). The `data` block is produced by the shared `quoteStrings` helper, which recursively walks the value tree and **quotes every string** (`%q`). The ConfigMap is not labeled (no `metadata.labels`) and has no `binaryData` block. There is no per-item `enabled` flag and no list shape — `.Values.configMap` is a single flat map of `key: value` pairs that becomes one ConfigMap.

## Important deviation from the plan/spec

The plan called for `configMap[]` (a list of objects with `name`, `data`, `binaryData`). **The partial does not support a list, and does not support `binaryData`.** Truth: `.Values.configMap` is a single map; the resulting name is fixed at `<app.name>-config`. Multiple ConfigMaps per release are not supported by this partial.

## Include usage

```yaml
{{- include "drunk-lib.configMap" . -}}
```

The partial takes the root context `.` only.

## Values schema

| Key | Type | Default | Required? | Notes |
|-----|------|---------|-----------|-------|
| `.Values.configMap` | map[string→any] | — | yes (presence) | Whole partial is a no-op when unset/empty. Keys become ConfigMap `data` keys; values are quoted via `quoteStrings`. |
| `.Values.configMap.<key>` | scalar / map / list | — | no | Strings are quoted. Numbers/bools render as bare YAML literals. Maps and lists render recursively (rare; usually a footgun — see checklist). |

### Plan keys the partial does NOT read

- `configMap[]` list shape with `name`/`data`/`binaryData` — unsupported. Only a single `configMap:` map is honored.
- `binaryData` — not emitted. Binary blobs cannot be carried in this partial.
- `metadata.labels` / `metadata.annotations` — not rendered.
- Per-item `enabled` — there is no gate beyond truthiness of `.Values.configMap` itself.

### Hard-coded fields

- `metadata.name`: `{{ include "app.name" . }}-config`
- `apiVersion: "v1"`, `kind: ConfigMap`

## Generate mode

When the developer says "give me a values.yaml for ConfigMap doing X":

**Minimal:**
```yaml
configMap:
  LOG_LEVEL: info
  APP_FEATURE_FLAGS: "alpha,beta"
```

Renders:
```yaml
apiVersion: "v1"
kind: ConfigMap
metadata:
  name: my-app-config
data:
  LOG_LEVEL: "info"
  APP_FEATURE_FLAGS: "alpha,beta"
```

**Typical (consumed by Deployment via envFrom):**
```yaml
configMap:
  LOG_LEVEL: info
  REGION: ap-southeast-1
  APP_FEATURE_FLAGS: "alpha,beta"
  HTTP_TIMEOUT_SECONDS: 30   # quoted as a number, NOT a string

deployment:
  enabled: true
  # The Deployment partial auto-mounts <app.name>-config via envFrom when configMap is set.
```

## Validate checklist

When the developer pastes a values.yaml section, check each of these and report any miss:

- [ ] **`configMap` shaped as a list (`- name: foo`) instead of a map** — the partial uses `quoteStrings` over a map. A list silently renders garbage YAML. Use a flat `key: value` map.
- [ ] **Non-string values that the app expects to read as strings** — `quoteStrings` only quotes strings; `LOG_LEVEL: info` becomes `"info"`, but `PORT: 8080` becomes `8080` (unquoted). Most apps tolerate this, but some env loaders (12-factor strict) require string-only. Force quoting by writing `PORT: "8080"` in values.
- [ ] **Nested maps/lists under a key** — `quoteStrings` will render them recursively, producing structured YAML inside a single ConfigMap data key. `envFrom.configMapRef` then sees a nested structure that can't be loaded as an env var. Flatten to scalars, or move structured config to a file mounted as a volume.
- [ ] **Name referenced by `envFrom.configMapRef` not declared** — the Deployment/CronJob partials auto-wire `<app.name>-config` only when `.Values.configMap` is set. If a sibling chart references `<app.name>-config` (or any other name) via `configFrom: [some-other-cm]`, that ConfigMap must be declared elsewhere — this partial does not produce it.
- [ ] **Binary blobs in `configMap.<key>`** — the partial has no `binaryData` support. Base64-encoded blobs become quoted strings in `data`, which K8s rejects if > 1 MiB total. Use a Secret with `data:` (which has the same 1 MiB cap) or mount from a chart `files/` directory in a fork.
- [ ] **Multiple ConfigMaps needed** — not possible. The name is hard-coded to `<app.name>-config`. Either fork the partial or use a sibling chart that emits raw resources.
- [ ] **Secret-shaped data in `configMap`** — credentials/tokens belong in `.Values.secrets` (Secret) or, better, `.Values.secretProvider` (SecretProviderClass / Key Vault). ConfigMap data is plaintext, readable by anyone with `get configmaps` RBAC.
- [ ] **Keys with characters outside `[a-zA-Z0-9._-]`** — K8s rejects them at apply time. ConfigMap data keys must match a config-key regex; quoteStrings does not validate.

## Cross-refs

- `drunk-lib-deployment` — auto-mounts `<app.name>-config` as `envFrom.configMapRef` when `.Values.configMap` is set; also includes a `checksum/configs` pod annotation via `app.checksums` so changes here trigger a rollout.
- `drunk-lib-statefulset` — same auto-mount behavior as Deployment.
- `drunk-lib-cronjob` — same auto-mount; note checksum annotations do **not** apply to CronJob pods.
- `drunk-lib-secrets` — sibling for secret-grade values; same single-map shape, name `<app.name>-secret`.

## Last-reviewed-commit

`1908a5a`
