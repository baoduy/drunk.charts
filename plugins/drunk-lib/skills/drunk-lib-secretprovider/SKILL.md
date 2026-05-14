---
name: drunk-lib-secretprovider
description: "Use when configuring/validating the drunk-lib SecretProviderClass partial — answers questions, generates values.yaml snippets, validates a section. Triggers on: secretproviderclass, csi secret, azure key vault, vault csi."
---

# drunk-lib · SecretProviderClass

You are an expert on the `drunk-lib` Helm library chart's `SecretProviderClass` partial (`drunk-lib/templates/_secretprovider.tpl`). Help developers configure, generate, and validate the `secretProvider` section of `values.yaml`.

## What it renders

The partial emits a single `secrets-store.csi.x-k8s.io/v1` `SecretProviderClass` when both `.Values.secretProvider` is set and `.Values.secretProvider.enabled` is truthy. The resource is named via the helper `app.secretProviderClassName` (which composes to `<spName>-cls` where `<spName>` is `.Values.secretProvider.name` or default `<app.name>-spc`). Provider type defaults to `azure` (`.Values.secretProvider.provider.name`); the partial **always renders the Azure-specific identity parameters** (`usePodIdentity`, `useWorkloadIdentity`, `useVMManagedIdentity`, `userAssignedIdentityID`, `tenantId`, `keyvaultName`) regardless of the provider value — so AWS/GCP providers will see meaningless Azure params in the manifest (CSI controllers usually ignore unknown params, but it's untidy). The `objects` block is a YAML-in-a-string and supports two item shapes: plain strings (interpreted as `objectName`, `objectType: secret`) or full maps (`objectName`, `objectType`, `objectAlias`, `objectVersion`, `objectFormat`, `objectEncoding`). When `.Values.secretProvider.secretObjects` is not set, the partial **auto-generates** a `secretObjects` block from `objects` (one mapping per object, key == objectName), producing a single synced K8s Secret of `type: Opaque` named `<spName>` (i.e. `app.secretProviderName`).

## Important deviation from the plan/spec

The plan listed `secretProviderClass.provider`, `secretProviderClass.parameters`, `secretProviderClass.secretObjects[]`. **Truth:**

- The root key is `.Values.secretProvider`, not `secretProviderClass`.
- `provider` is a map with a `.name` sub-field (and identity sub-fields), not a string.
- There is no free-form `parameters` map you can pass through — the partial hard-codes the parameter keys (Azure-shaped).
- `secretObjects` is optional and **auto-generated** from `objects` when omitted.
- A `secretObjects[].secretName` cannot be set per-object; auto-generated `secretName` is fixed at `app.secretProviderName`.

## Include usage

```yaml
{{- include "drunk-lib.secretProvider" . -}}
```

The partial takes the root context `.` only.

## Values schema

| Key | Type | Default | Required? | Notes |
|-----|------|---------|-----------|-------|
| `.Values.secretProvider` | map | — | yes (presence) | No-op when unset. |
| `.Values.secretProvider.enabled` | bool | `false` | yes | Gate. |
| `.Values.secretProvider.name` | string | `<app.name>-spc` | no | Base name. The SecretProviderClass resource is `<name>-cls`; the synced K8s Secret is `<name>`. |
| `.Values.secretProvider.provider.name` | string | `azure` | no | Goes into `spec.provider`. Allowed by CSI: `azure`, `aws`, `gcp`, `vault`. The partial does not switch parameter shape — Azure params are always emitted. |
| `.Values.secretProvider.provider.usePodIdentity` | bool | `false` | no | Quoted in output (`"false"`/`"true"`). |
| `.Values.secretProvider.provider.useWorkloadIdentity` | bool | `false` | no | Quoted in output. Set `true` for AKS workload identity. |
| `.Values.secretProvider.provider.useVMManagedIdentity` | bool | `true` | no | Quoted in output. Note the default is **true** — flip to `false` when using workload identity. |
| `.Values.secretProvider.provider.userAssignedIdentityID` | string | — | yes for Azure when not using `usePodIdentity` | Client ID of the managed identity bound to the pod. Always quoted. |
| `.Values.secretProvider.provider.tenantId` | string | — | yes for Azure | AAD tenant. Always quoted. |
| `.Values.secretProvider.provider.vaultName` | string | — | yes for Azure | Becomes `keyvaultName` parameter. Always quoted. |
| `.Values.secretProvider.objects` | list | — | recommended | List of objects to pull. Each item is either a bare string (objectName, defaults to `objectType: secret`) or a map (see below). |
| `.Values.secretProvider.objects[].objectName` | string | — | yes (map form) | Vault object name. |
| `.Values.secretProvider.objects[].objectType` | string | `secret` | no | `secret` / `key` / `cert`. |
| `.Values.secretProvider.objects[].objectAlias` | string | `""` | no | Mounted-file/key alias. |
| `.Values.secretProvider.objects[].objectVersion` | string | `""` | no | Pin a version; empty = latest. |
| `.Values.secretProvider.objects[].objectFormat` | string | `""` | no | `pem`/`pfx` for certs. |
| `.Values.secretProvider.objects[].objectEncoding` | string | `""` | no | `utf-8`/`base64`/`hex`. |
| `.Values.secretProvider.secretObjects` | list | auto-generated from `objects` | no | When set, replaces the auto-mapping. Each item needs `key` and `objectName`. The partial wraps them in a single `secretObjects[0]` entry with `secretName: <app.secretProviderName>` and `type: Opaque`. |

### Plan keys the partial does NOT read

- `secretProviderClass.*` keys (any) — the root is `secretProvider`.
- `secretProviderClass.parameters` free-form map — the parameter keys are hard-coded; non-Azure providers can't supply their own (e.g. AWS `region`, GCP `auth`).
- Per-`secretObjects[].secretName` — auto-generated `secretName` is fixed to `app.secretProviderName`. Multiple synced K8s Secrets per SPC are not supported.
- Per-`secretObjects[].type` — fixed to `Opaque`. Cannot produce `kubernetes.io/tls` via this path; use `drunk-lib.tls`.

### Hard-coded / helper-derived fields

- `metadata.name`: `{{ include "app.secretProviderClassName" . }}` → `<spName>-cls`
- Synced Secret `secretName`: `{{ include "app.secretProviderName" . }}` → `<spName>`
- Synced Secret `type`: `Opaque`
- `metadata.labels`: from `app.labels`

## Generate mode

When the developer says "give me a values.yaml for SecretProviderClass doing X":

**Minimal (Azure Key Vault, workload identity):**
```yaml
secretProvider:
  enabled: true
  provider:
    name: azure
    useVMManagedIdentity: false
    useWorkloadIdentity: true
    userAssignedIdentityID: "00000000-0000-0000-0000-000000000000"
    tenantId: "11111111-1111-1111-1111-111111111111"
    vaultName: my-keyvault
  objects:
    - DB_PASSWORD
    - API_KEY
```

Renders SecretProviderClass `<app.name>-spc-cls` and (auto) syncs a K8s Secret named `<app.name>-spc` with keys `DB_PASSWORD` and `API_KEY`.

**Typical (custom object types, explicit secretObjects):**
```yaml
secretProvider:
  enabled: true
  name: payments
  provider:
    name: azure
    useVMManagedIdentity: false
    useWorkloadIdentity: true
    userAssignedIdentityID: "<client-id>"
    tenantId: "<tenant>"
    vaultName: payments-kv
  objects:
    - objectName: stripe-api-key
      objectType: secret
      objectAlias: STRIPE_API_KEY
    - objectName: signing-cert
      objectType: cert
      objectFormat: pem
  secretObjects:
    - key: STRIPE_API_KEY
      objectName: stripe-api-key
    - key: SIGNING_CERT
      objectName: signing-cert
# Synced K8s Secret name will be "payments"; SPC resource name "payments-cls".
```

## Validate checklist

When the developer pastes a values.yaml section, check each of these and report any miss:

- [ ] **`provider.name: azure` but missing `vaultName` / `tenantId` / `userAssignedIdentityID`** — all three are always rendered, but as empty `""` strings if unset. The Azure CSI driver then errors at pod mount (`keyvaultName is required`). Set all three for Azure.
- [ ] **`useVMManagedIdentity: true` (the default!) on an AKS workload-identity cluster** — these are mutually exclusive. Explicitly set `useVMManagedIdentity: false` and `useWorkloadIdentity: true` for workload identity. Leaving the default silently uses VM MSI (the node's identity), which usually has no Key Vault access.
- [ ] **`secretObjects[].secretName` collision with `.Values.secrets`** — the partial auto-syncs to a K8s Secret named `app.secretProviderName` (default `<app.name>-spc`). The `drunk-lib.secrets` partial produces `<app.name>-secret`. Those names don't collide by default — but if you set `.Values.secretProvider.name` to `<app.name>-secret`, both partials write to the same Secret and the last-applied wins. Pick distinct names.
- [ ] **Mount path expected but no CSI `volumeMounts` entry** — the `drunk-lib.deployment` / `drunk-lib.cronJobs` partials auto-mount the CSI volume at `/mnt/secrets-store` (read-only) only when `.Values.secretProvider.enabled` is true. If you reference the mount in a custom command (e.g. `--cert=/etc/certs/tls.crt`), either remap the path in your app or accept `/mnt/secrets-store/...`. The partial does **not** expose an `objectAlias`-as-subPath option here; the mount is the whole tree.
- [ ] **`provider.name: aws`/`gcp`/`vault`** — the partial still emits Azure parameters (`keyvaultName`, `tenantId`, etc.). Most CSI providers ignore unknown params, but you cannot supply AWS-specific params (`region`, `objects` in AWS shape) through values; you must fork.
- [ ] **`objects` not declared while `secretObjects` is also empty** — the partial renders `objects: |` with an empty `array:` body and skips the synced Secret entirely. The SPC exists but mounts nothing. Add at least one object.
- [ ] **Bare-string `objects` mixed with map `objects`** — supported; both forms iterate cleanly. But auto-generated `secretObjects` keys use the string verbatim for bare entries (`key == objectName`) and the map's `objectName` for map entries. Watch out for vault objects with dashes / dots that aren't valid env var names — set `objectAlias` and an explicit `secretObjects[]` mapping.
- [ ] **`enabled: true` but consumer Deployment doesn't set `serviceAccount.enabled: true`** — Azure workload identity requires a SA annotated with `azure.workload.identity/client-id`. Without it, the CSI driver fails to acquire a token. Pair with `serviceAccount.enabled: true` and add the annotation in `serviceAccount.annotations`.
- [ ] **`useWorkloadIdentity: true` but no `userAssignedIdentityID`** — workload identity flows still need the client ID to scope the token request. The partial does not warn.
- [ ] **`provider` is a string** — the partial does `provider.name | default "azure"`, so `provider: "azure"` (string) breaks rendering (`can't evaluate field name in type string`). Use a map: `provider: { name: azure }`.

## Cross-refs

- `drunk-lib-secrets` — companion for in-cluster plaintext-source secrets; prefer the SecretProviderClass for production.
- `drunk-lib-volumes` — the consuming Deployment auto-mounts `/mnt/secrets-store` when this partial is enabled; no extra volume declaration needed.
- `drunk-lib-deployment` — also auto-adds an `envFrom.secretRef` pointing at the synced K8s Secret (name == `app.secretProviderName`), exposing the synced keys as env vars.
- `drunk-lib-serviceaccount` — required when using workload identity; provides the SA the CSI driver authenticates as. Annotate with `azure.workload.identity/client-id`.

## Last-reviewed-commit

`b964e97`
