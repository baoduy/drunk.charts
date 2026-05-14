---
name: drunk-lib-serviceaccount
description: "Use when configuring/validating the drunk-lib ServiceAccount partial — answers questions, generates values.yaml snippets, validates a section. Triggers on: serviceaccount, sa, workload identity."
---

# drunk-lib · ServiceAccount

You are an expert on the `drunk-lib` Helm library chart's `ServiceAccount` partial (`drunk-lib/templates/_serviceAccount.tpl`). Help developers configure, generate, and validate the `serviceAccount` section of `values.yaml`.

## What it renders

The partial emits a single `v1` `ServiceAccount` when **both** `.Values.serviceAccount` is set **and** `.Values.serviceAccount.enabled` is truthy. The resource name comes from the `app.serviceAccountName` helper, which returns `.Values.serviceAccount.name` when set, otherwise `app.name`. Labels are sourced from `app.labels`. An optional `annotations` map is rendered via `toYaml` when present — this is the hook used for AKS workload identity (`azure.workload.identity/client-id`), AWS IRSA (`eks.amazonaws.com/role-arn`), and GKE workload identity (`iam.gke.io/gcp-service-account`).

The partial does **not** render `automountServiceAccountToken`, `secrets[]`, or `imagePullSecrets[]` — those are handled separately (e.g. `drunk-lib.deployment` hard-codes `automountServiceAccountToken: false` on the pod spec; image-pull secrets are wired through `drunk-lib.imagePullSecret`).

## Important deviation from the plan/spec

The plan listed the gate as `serviceAccount.create` with sub-keys `serviceAccount.name`, `serviceAccount.annotations`, `serviceAccount.automountServiceAccountToken`. **Truth:**

- The gate is **`.Values.serviceAccount.enabled`**, not `.create`. `create: true` is silently ignored and the SA is never rendered. (The `drunk-app` sample `values.yaml` has this exact bug; the deployment skill flags it on the consumer side.)
- `automountServiceAccountToken` is **not read** at the SA level. The pod-level token mount is hard-coded to `false` inside `drunk-lib.deployment`. There is no values key to flip it back on.
- The same gate (`.Values.serviceAccount.enabled`) is reused by `drunk-lib.deployment` to decide whether to set `serviceAccountName` on the pod spec. The two partials always agree.

## Include usage

```yaml
{{- include "drunk-lib.serviceAccount" . -}}
```

The partial takes the root context `.` only.

## Values schema

| Key | Type | Default | Required? | Notes |
|-----|------|---------|-----------|-------|
| `.Values.serviceAccount` | map | — | yes (presence) | No-op when unset. |
| `.Values.serviceAccount.enabled` | bool | `false` | yes | Gate. **Not `create`.** |
| `.Values.serviceAccount.name` | string | `app.name` | no | Resolved via the `app.serviceAccountName` helper. When unset, the SA is named `{{ include "app.name" . }}`. |
| `.Values.serviceAccount.annotations` | map | — | no | Rendered into `metadata.annotations`. Common keys: `azure.workload.identity/client-id`, `eks.amazonaws.com/role-arn`, `iam.gke.io/gcp-service-account`. |

### Plan keys the partial does NOT read

- `.Values.serviceAccount.create` — ignored. Use `enabled`.
- `.Values.serviceAccount.automountServiceAccountToken` — ignored. The deployment hard-codes `automountServiceAccountToken: false` on the pod and there is no values knob to toggle it.
- Any `secrets[]` / `imagePullSecrets[]` directly on the SA — not rendered; manage image-pull via `.Values.global.imagePullSecret` / `drunk-lib.imagePullSecret`.

### Hard-coded / helper-derived fields

- `metadata.name` — `{{ include "app.serviceAccountName" . }}` (which defaults to `app.name` when `serviceAccount.name` is unset).
- `metadata.labels` — `app.labels`.
- `apiVersion: v1`, `kind: ServiceAccount`.

## Generate mode

When the developer says "give me a values.yaml for ServiceAccount doing X":

**Minimal (plain in-cluster SA, no cloud identity):**
```yaml
serviceAccount:
  enabled: true
```

Renders ServiceAccount named `{{ include "app.name" . }}` with no annotations.

**Typical (AKS workload identity, paired with secretProvider):**
```yaml
serviceAccount:
  enabled: true
  name: payments-wi
  annotations:
    azure.workload.identity/client-id: "00000000-0000-0000-0000-000000000000"
    # Optional: pin tenant if the default tenant on the cluster is wrong
    azure.workload.identity/tenant-id: "11111111-1111-1111-1111-111111111111"

# Pod label requirement: workload identity needs `azure.workload.identity/use: "true"`
# on the pod template. drunk-lib.deployment does NOT add this automatically — set it
# via `.Values.deployment.podAnnotations`/labels if your cluster requires it, or via
# a namespace-wide mutating webhook.
```

**AWS IRSA:**
```yaml
serviceAccount:
  enabled: true
  name: payments
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/payments-role
```

## Validate checklist

When the developer pastes a values.yaml section, check each of these and report any miss:

- [ ] **`create: false` (or `create: true`) instead of `enabled: true`** — the partial only reads `enabled`. `create` is silently ignored, so no ServiceAccount is rendered and the Deployment falls back to `default`. Rename to `enabled`.
- [ ] **`enabled: false` (or `serviceAccount` block absent) but `.Values.serviceAccount.name` references an SA that doesn't exist** — `drunk-lib.deployment` only sets `serviceAccountName` when `enabled: true`, so the pod actually uses `default`. If the intention was "use a pre-existing SA managed elsewhere", you must either create that SA out-of-band **and** also set `serviceAccount.enabled: true` (so the deployment wires `serviceAccountName`) **or** accept the `default` SA. There is no "reference-only" mode.
- [ ] **Workload identity annotation present but `automountServiceAccountToken: false`** — `drunk-lib.deployment` hard-codes `automountServiceAccountToken: false` on the pod spec. **For AKS workload identity this is actually correct** (WI uses a projected service-account token mounted by the webhook, not the legacy auto-mounted one). **For AWS IRSA / GKE WI it can also work** (both inject their own projected token). But for any flow that needs the in-cluster API token (e.g. `kubectl`-from-pod tooling, controllers that talk to the K8s API as themselves), the pod will have no token and API calls return 401. There is no values knob to re-enable it via this chart.
- [ ] **Missing `azure.workload.identity/client-id` annotation when `secretProvider` uses Azure workload identity** — the CSI driver authenticates as the SA, so the annotation is mandatory. Without it the SecretProviderClass mount fails with "no AAD token available". Set `serviceAccount.annotations["azure.workload.identity/client-id"]` to the same client ID you set in `secretProvider.provider.userAssignedIdentityID`.
- [ ] **`serviceAccount.name` collides with another release in the same namespace** — both Deployments would race to own the same SA. Either prefix with the release name, use the default (`app.name` is already release-scoped via chart name + release), or leave `name` unset.
- [ ] **AKS workload identity pod label missing** — beyond the SA annotation, AKS WI also requires `azure.workload.identity/use: "true"` **on the pod template** (not the SA). `drunk-lib.deployment` does not add this; either add it via a mutating webhook (the AKS WI add-on does this for labelled namespaces) or via `.Values.deployment.podAnnotations`/pod labels if you have a way to inject them.
- [ ] **`annotations` shaped as a list of `key: value` pairs instead of a map** — `toYaml` of a list under `annotations:` produces invalid K8s YAML. Use a map.
- [ ] **Cluster-scoped role bindings expected but not created** — this partial only emits the SA, not any `Role`/`ClusterRole`/`RoleBinding`/`ClusterRoleBinding`. If the workload needs RBAC permissions in-cluster (e.g. it watches `Pods`), you must author those bindings yourself.

## Cross-refs

- `drunk-lib-deployment` — reads the same `.Values.serviceAccount.enabled` gate; sets `serviceAccountName` on the pod when truthy. Hard-codes `automountServiceAccountToken: false`.
- `drunk-lib-secretprovider` — when using Azure workload identity, the synced K8s Secret and the CSI mount only work if this partial creates the SA with the `azure.workload.identity/client-id` annotation matching `secretProvider.provider.userAssignedIdentityID`.
- `drunk-lib-imagepull-secret` — image-pull secrets are attached at the pod spec, not on the SA, so you don't need to list them on `.Values.serviceAccount`. Use `.Values.global.imagePullSecret` or `.Values.imageCredentials`.

## Last-reviewed-commit

`1908a5a`
