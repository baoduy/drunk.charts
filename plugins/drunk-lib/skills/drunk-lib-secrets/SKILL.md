---
name: drunk-lib-secrets
description: "Use when configuring/validating the drunk-lib Secret (Opaque) partial — answers questions, generates values.yaml snippets, validates a section. Triggers on: secret, opaque secret, env secret."
---

# drunk-lib · Secret (Opaque)

You are an expert on the `drunk-lib` Helm library chart's `Secret` partial (`drunk-lib/templates/_secrets.tpl`). Help developers configure, generate, and validate the `secrets` section of `values.yaml`.

## What it renders

The partial emits a single `v1` `Secret` named `{{ include "app.name" . }}-secret` when `.Values.secrets` is truthy. All values are written under `stringData` (so K8s base64-encodes them at apply time), produced by the shared `quoteStrings` helper. The Secret has **no explicit `type:` field** — by K8s convention this means `Opaque`. There is no `data:` (raw base64) path, no `type` override, no labels/annotations, and no per-item `enabled` gate. Shape is a single flat map keyed by env-var-style names.

## Important deviation from the plan/spec

The plan called for `secrets[]` (list) with `name`, `type` (default `Opaque`), `stringData`, `data`. **The partial supports none of that.** Truth:

- `.Values.secrets` is a single map (not a list).
- Resource name is fixed at `<app.name>-secret`.
- Only `stringData` is rendered; no `data:` (base64) path.
- No `type:` field — every Secret produced here is implicitly Opaque. For non-Opaque types (`kubernetes.io/tls`, `kubernetes.io/dockerconfigjson`), use the sibling partials `drunk-lib.tls` and `drunk-lib.imagePullSecret`.

## Include usage

```yaml
{{- include "drunk-lib.secrets" . -}}
```

The partial takes the root context `.` only.

## Values schema

| Key | Type | Default | Required? | Notes |
|-----|------|---------|-----------|-------|
| `.Values.secrets` | map[string→scalar] | — | yes (presence) | Whole partial is a no-op when unset/empty. Keys become Secret `stringData` keys. |
| `.Values.secrets.<key>` | scalar | — | no | Strings are quoted; numbers/bools render as bare literals. K8s coerces all to base64 at apply time. Nested maps/lists work via `quoteStrings` recursion but produce data K8s rejects (`stringData` values must be strings). |

### Plan keys the partial does NOT read

- `secrets[]` (list of named Secrets) — unsupported. The chart emits exactly one Secret.
- `secrets[].name` — fixed at `<app.name>-secret`.
- `secrets[].type` — not rendered. Implicit `Opaque`.
- `secrets[].data` (raw base64) — not supported; values must be plaintext under `stringData`.
- `metadata.labels` / `metadata.annotations` — not rendered.

### Hard-coded fields

- `metadata.name`: `{{ include "app.name" . }}-secret`
- `apiVersion: "v1"`, `kind: Secret`
- No `type:` → defaults to `Opaque` server-side.

## Generate mode

When the developer says "give me a values.yaml for Secret doing X":

**Minimal:**
```yaml
secrets:
  DB_PASSWORD: "REPLACE_AT_DEPLOY"
  API_KEY: "REPLACE_AT_DEPLOY"
```

**Typical (consumed by Deployment via envFrom):**
```yaml
secrets:
  DB_PASSWORD: "{{ .Values.global.dbPassword }}"   # injected at install time
  API_KEY: "{{ .Values.global.apiKey }}"

deployment:
  enabled: true
  # The Deployment partial auto-mounts <app.name>-secret via envFrom when secrets is set.
```

**Production preference — externalize via SecretProviderClass:**
```yaml
# Prefer this over .Values.secrets for production:
secretProvider:
  enabled: true
  provider:
    name: azure
    vaultName: my-keyvault
    tenantId: <tenant>
    userAssignedIdentityID: <id>
  objects:
    - DB_PASSWORD
    - API_KEY
```

## Validate checklist

When the developer pastes a values.yaml section, check each of these and report any miss:

- [ ] **Plaintext secrets committed in values.yaml** — `.Values.secrets` values land in git history and the rendered chart release object. Strongly recommend moving them to `.Values.secretProvider` (Azure Key Vault / AWS Secrets Manager / GCP via CSI) and pulling them at pod-mount time. Keep `.Values.secrets` only for sealed/encrypted placeholders or values injected by CI from a secret store.
- [ ] **Both `data` and `stringData` paths set for the same key** — not possible here: this partial only emits `stringData`. If someone tried to add a `data:` section by editing values, it would be silently ignored. If they expect base64-encoded `data:`, redirect them to a hand-written Secret or fork the partial.
- [ ] **Missing `type` when not Opaque** — also not possible here: the partial omits `type:` entirely, so every Secret is Opaque. For TLS, use `drunk-lib.tls` (`.Values.tlsSecrets`); for image pull, use `drunk-lib.imagePullSecret` (`.Values.imageCredentials`). For SSH/basic-auth/service-account-token types, fork the partial.
- [ ] **`secrets` shaped as a list (`- name: foo`)** — unsupported. The partial expects a flat map. A list renders broken YAML inside `stringData`.
- [ ] **Nested maps/lists under a key** — `stringData` values must be strings. `quoteStrings` will recurse, but the resulting YAML structure under a `stringData` key is rejected by K8s. Flatten to scalars (JSON-encode if you must carry structure, e.g. `CONFIG_JSON: '{"a":1}'`).
- [ ] **Same key in `secrets` and `configMap`** — both Secret and ConfigMap are auto-mounted as `envFrom`. K8s does not de-duplicate; the env var ordering is implementation-defined and the secret value may be shadowed by the configMap value (or vice-versa). Pick one source per key.
- [ ] **Multiple distinct Secrets needed in one release** — not supported. Name is fixed at `<app.name>-secret`. For additional Secrets, use `.Values.secretFrom` to reference externally-provisioned Secret names, or fork the partial.
- [ ] **Keys outside `[a-zA-Z0-9._-]`** — K8s rejects them; `quoteStrings` does not validate.

## Cross-refs

- `drunk-lib-secretprovider` — preferred path for real production secrets: pulls from Azure Key Vault / AWS / GCP via CSI driver. Set `.Values.secretProvider.enabled: true` and the Deployment auto-mounts both the CSI volume and a `secretRef` envFrom for the synced K8s Secret.
- `drunk-lib-tls-secrets` — sibling for `kubernetes.io/tls` Secrets (`.Values.tlsSecrets`); this partial cannot produce TLS-typed Secrets.
- `drunk-lib-imagepull-secret` — sibling for `kubernetes.io/dockerconfigjson` Secrets (`.Values.imageCredentials`); same reason.
- `drunk-lib-configmap` — non-sensitive sibling. Same single-map shape, same auto-mount pattern, name `<app.name>-config`.

## Last-reviewed-commit

`1908a5a`
