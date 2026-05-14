---
name: drunk-lib-imagepull-secret
description: "Use when configuring/validating the drunk-lib imagePullSecret partial — answers questions, generates values.yaml snippets, validates a section. Triggers on: imagepullsecret, dockerconfigjson, registry secret."
---

# drunk-lib · Image Pull Secret (`kubernetes.io/dockerconfigjson`)

You are an expert on the `drunk-lib` Helm library chart's `imagePullSecret` partial (`drunk-lib/templates/_imagePull-secret.tpl`). Help developers configure, generate, and validate the `imageCredentials` section of `values.yaml`.

## What it renders

The partial emits a single `v1` `Secret` of type `kubernetes.io/dockerconfigjson` when `.Values.imageCredentials` is truthy (any non-nil/non-empty value). The Secret name comes from the helper `drunk.utils.imagePullSecretName` — `.Values.imageCredentials.name` if set, else `<app.name>-dcr-secret`. The `.dockerconfigjson` payload is built by `drunk.utils.imagePullSecret`, which formats `{"auths":{"<registry>":{"auth":"<b64(username:password)>"}}}` and base64-encodes the whole JSON. There is **no `enabled` gate** — mere presence of `imageCredentials` is the trigger. There is no labels block, no annotations, no email field, and no pre-built `dockerConfigJson` pass-through.

## Important deviation from the plan/spec

The plan called for `imagePullSecret.{enabled,name,registry,username,password,email,dockerConfigJson}`. **Truth:**

- The root key is `.Values.imageCredentials`, not `imagePullSecret`.
- There is **no `enabled` gate** — gate is `if .Values.imageCredentials`. To suppress, omit the whole key.
- `email` is **not read**. Only `name`, `registry`, `username`, `password` are consumed.
- There is **no pre-built `dockerConfigJson` pass-through** — you must supply `registry` / `username` / `password` and let the partial assemble the JSON.
- The default Secret name uses the `-dcr-secret` suffix (`<app.name>-dcr-secret`), not the more common `-regcred`.

## Include usage

```yaml
{{- include "drunk-lib.imagePullSecret" . -}}
```

The partial takes the root context `.` only.

## Values schema

| Key | Type | Default | Required? | Notes |
|-----|------|---------|-----------|-------|
| `.Values.imageCredentials` | map | — | yes (presence) | No-op when absent. There is no `enabled` field. |
| `.Values.imageCredentials.name` | string | `<app.name>-dcr-secret` | no | Resource name. |
| `.Values.imageCredentials.registry` | string | — | **yes** | Registry hostname (e.g. `ghcr.io`, `myregistry.azurecr.io`, `registry.gitlab.com`). Goes into the `auths` map key. No scheme; bare hostname. |
| `.Values.imageCredentials.username` | string | — | **yes** | Registry username. Concatenated with password and base64-encoded. |
| `.Values.imageCredentials.password` | string | — | **yes** | Registry password / PAT. Stored base64-encoded inside the dockerconfigjson, which is itself base64-encoded — but this is **not encryption**; anyone with `get secrets` RBAC can decode it. Prefer sourcing from `.Values.secretProvider`. |

### Plan keys the partial does NOT read

- `imagePullSecret.enabled` — no gate; presence of `imageCredentials` is the only switch.
- `imagePullSecret.email` — not in the rendered JSON; modern registries ignore email anyway.
- `imagePullSecret.dockerConfigJson` — there is no pre-built pass-through. The partial always builds the JSON itself from `registry`/`username`/`password`. To inject a pre-built dockerconfigjson, hand-write a Secret in your consumer chart and skip this partial.

### Hard-coded fields

- `apiVersion: v1`, `kind: Secret`
- `type: kubernetes.io/dockerconfigjson`
- Data key: `.dockerconfigjson` (the leading dot is required by K8s)
- No `metadata.labels` / `annotations`

## Generate mode

When the developer says "give me a values.yaml for image pull secret doing X":

**Minimal (GHCR):**
```yaml
imageCredentials:
  registry: ghcr.io
  username: my-ci-bot
  password: "{{ .Values.global.ghcrPat }}"   # injected at install time
```

Renders Secret `<app.name>-dcr-secret`. Reference it from the workload via `.Values.global.imagePullSecret: <app.name>-dcr-secret` (note: the Deployment/CronJob partials read a **single string** under `global.imagePullSecret`, not a list).

**Typical (Azure Container Registry, custom name):**
```yaml
imageCredentials:
  name: acr-pull
  registry: myregistry.azurecr.io
  username: <sp-app-id>
  password: "{{ .Values.global.acrPat }}"

global:
  imagePullSecret: acr-pull        # singular string; the partials wrap into the K8s imagePullSecrets list
  image: myregistry.azurecr.io/my-app
  tag: "1.0.0"
```

**Preferred — source the password from Key Vault via SecretProviderClass:**
```yaml
# Skip imageCredentials entirely. Hand-write a Secret in your consumer chart that is
# populated by the CSI secret-store sync, then reference it via global.imagePullSecret.
# Or use AKS pull-through with workload identity.
```

## Validate checklist

When the developer pastes a values.yaml section, check each of these and report any miss:

- [ ] **Plaintext `password` in values.yaml** — same problem as `.Values.secrets`: it lands in git and in the release object. Strongly prefer Workload Identity / IRSA + a pull-through cache, or source via `.Values.secretProvider`, or generate the Secret at install time with `--set imageCredentials.password=...` from a CI vault.
- [ ] **Default name `<app.name>-dcr-secret` not referenced by `global.imagePullSecrets`** — the workload partials read `.Values.global.imagePullSecret` (singular). If you accept the default name, set `global.imagePullSecret: <app.name>-dcr-secret` explicitly. The chart does **not** auto-wire the produced Secret into the Deployment.
- [ ] **`global.imagePullSecret` set as a list** — the partials wrap it in a one-element `imagePullSecrets` list; passing a list yields invalid YAML. For multiple pull secrets, hand-write a `imagePullSecrets` block in a custom partial.
- [ ] **`imageCredentials: {}` empty map** — counts as truthy in Helm; the partial renders a Secret with an empty registry, username, and password. The K8s API accepts the Secret but the dockerconfigjson is unusable. Either omit the whole key or supply all three fields.
- [ ] **Registry hostname with scheme (`https://...`)** — the partial concatenates it literally into the `auths` JSON map key. Most container runtimes match registry by bare hostname; a scheme prefix breaks the match silently and pulls fall back to anonymous. Use `ghcr.io`, not `https://ghcr.io`.
- [ ] **Wrong type field** — not possible through this partial (`type` is hard-coded). If a sibling chart needs a `kubernetes.io/basic-auth` Secret for `auth-tls-secret` ingress annotations, use `drunk-lib.secrets` or hand-write the Secret.
- [ ] **`email` field set** — silently ignored. Drop it.
- [ ] **`dockerConfigJson` (pre-built) provided** — silently ignored. Either supply `registry`/`username`/`password` or hand-write the Secret outside this partial.
- [ ] **Multiple registries needed in one release** — not supported; this partial emits a single Secret with a single `auths` entry. For multi-registry, hand-write a Secret with multiple `auths` keys or use the registry's pull-through proxy.
- [ ] **Password contains a `:` (colon)** — the partial does `printf "%s:%s" username password | b64enc`. Colons in the password decode ambiguously on some clients. Avoid `:` in registry passwords/PATs (most PAT generators won't produce one).
- [ ] **Registry URL has a trailing slash or a path** (e.g. `ghcr.io/`, `registry.gitlab.com/group`) — kubelet matches by bare hostname; extra path components cause anonymous fallback. Use the hostname only.

## Cross-refs

- `drunk-lib-secrets` — sibling for Opaque secrets; cannot produce `kubernetes.io/dockerconfigjson` (wrong type) but is the right home for arbitrary registry-related config not exposed here.
- `drunk-lib-secretprovider` — preferred production source for the PAT. Sync the PAT from Key Vault into an Opaque Secret, then hand-write or fork to produce the dockerconfigjson Secret (this partial doesn't have a "read from another Secret" path).
- `drunk-lib-serviceaccount` — the SA's `imagePullSecrets` could reference the produced Secret instead of (or in addition to) the pod-level `global.imagePullSecret`. This partial does not auto-wire either path; you must set the consuming field yourself.

## Last-reviewed-commit

`1908a5a`
