---
name: drunk-lib-tls-secrets
description: "Use when configuring/validating the drunk-lib TLS Secret partial — answers questions, generates values.yaml snippets, validates a section. Triggers on: tls secret, certificate secret, tls cert."
---

# drunk-lib · TLS Secret (`kubernetes.io/tls`)

You are an expert on the `drunk-lib` Helm library chart's `TLS Secret` partial (`drunk-lib/templates/_tls-secrets.tpl`). Help developers configure, generate, and validate the `tlsSecrets` section of `values.yaml`.

## What it renders

The partial iterates `.Values.tlsSecrets` (a **map**, not a list) and emits one `v1` `Secret` per entry, typed `kubernetes.io/tls` and named `tls-<key>` (where `<key>` is the map key from `tlsSecrets`). Per-entry gate: an entry renders unless `.enabled` is explicitly `false` — i.e. opt-out (the check is `or (eq $v.enabled true) (eq $v.enabled nil)`). The cert and key bodies are sourced from either an inline string field (`crt`/`key`) or a chart-files path (`crtFile`/`keyFile`, read via `$.Files.Get`); the partial base64-encodes (`b64enc`) whatever it reads and writes to `data.tls.crt` / `data.tls.key`. An optional CA chain may be supplied via `ca` (inline) or `caFile` (chart files) and is emitted as `data.ca.crt`. The partial **fails the render** (`fail`) if either `crt`/`crtFile` or `key`/`keyFile` is missing — it does not silently skip. There is no `metadata.labels` block.

## Important deviation from the plan/spec

The plan described `tlsSecrets[]` (a list) with `name`, `cert`/`key` (PEM) or `certData`/`keyData` (base64). **Truth:**

- `.Values.tlsSecrets` is a **map**, not a list. The resource name is `tls-<map-key>`; there is no `.name` field.
- Field names are `crt` / `key` / `ca` (inline PEM) and `crtFile` / `keyFile` / `caFile` (chart `files/` paths) — not `cert`/`certData`/`keyData`.
- **All input is treated as raw PEM** and base64-encoded by the partial. There is no "already-base64" path; supplying base64 yields double-encoded data K8s won't accept.

## Include usage

```yaml
{{- include "drunk-lib.tls" . -}}
```

The partial takes the root context `.` only and reads `.Files` for `*File` lookups.

## Values schema

| Key | Type | Default | Required? | Notes |
|-----|------|---------|-----------|-------|
| `.Values.tlsSecrets` | map[name→spec] | — | yes (presence) | No-op when unset/empty. Each map key becomes the Secret suffix: `tls-<key>`. |
| `.Values.tlsSecrets.<key>.enabled` | bool | `true` (implicit; rendered when `nil` or `true`) | no | **Opt-out**. Set to `false` to skip an entry; any other value (including omission) renders. |
| `.Values.tlsSecrets.<key>.crt` | string (PEM) | — | one of `crt`/`crtFile` is **required** | Inline PEM certificate (leaf + chain). Base64-encoded by the partial. |
| `.Values.tlsSecrets.<key>.crtFile` | string (path) | — | one of `crt`/`crtFile` is **required** | Path relative to the **consuming** chart's `files/` (because `$.Files` is the calling chart's `Files`, not `drunk-lib`'s). Takes precedence over `crt` when both are set. |
| `.Values.tlsSecrets.<key>.key` | string (PEM) | — | one of `key`/`keyFile` is **required** | Inline PEM private key. Base64-encoded by the partial. |
| `.Values.tlsSecrets.<key>.keyFile` | string (path) | — | one of `key`/`keyFile` is **required** | Path relative to the consuming chart's `files/`. Takes precedence over `key` when both set. |
| `.Values.tlsSecrets.<key>.ca` | string (PEM) | — | no | Optional CA chain. Rendered as `data.ca.crt`. |
| `.Values.tlsSecrets.<key>.caFile` | string (path) | — | no | Optional chart-files path for CA. |

### Plan keys the partial does NOT read

- `tlsSecrets[]` list shape with `name` — unsupported.
- `certData` / `keyData` (already-base64) — unsupported; supplying base64 results in double-encoding.
- `metadata.labels` / `metadata.annotations` — not rendered.

### Hard-coded fields

- `metadata.name`: `tls-<map-key>` (no `<app.name>` prefix, no namespace)
- `type: kubernetes.io/tls`
- Data keys: `tls.crt`, `tls.key`, and (optional) `ca.crt`

## Generate mode

When the developer says "give me a values.yaml for TLS Secret doing X":

**Minimal (inline PEM):**
```yaml
tlsSecrets:
  api-example-com:
    crt: |
      -----BEGIN CERTIFICATE-----
      MIIDazCCAlOgAwIBAgIUbX...
      -----END CERTIFICATE-----
    key: |
      -----BEGIN PRIVATE KEY-----
      MIIEvQIBADANBgkqhki...
      -----END PRIVATE KEY-----
```

Renders Secret `tls-api-example-com` of type `kubernetes.io/tls`.

**Typical (file-based, with CA chain, one entry disabled):**
```yaml
tlsSecrets:
  api-example-com:
    crtFile: files/certs/api.crt   # in the consumer chart's files/
    keyFile: files/certs/api.key
    caFile:  files/certs/internal-ca.crt

  legacy-example-com:
    enabled: false                 # opt-out: this entry does NOT render
    crt: |
      -----BEGIN CERTIFICATE-----
      ...

  admin-example-com:
    crt: |
      -----BEGIN CERTIFICATE-----
      ...
    key: |
      -----BEGIN PRIVATE KEY-----
      ...
```

## Validate checklist

When the developer pastes a values.yaml section, check each of these and report any miss:

- [ ] **`certData` / `keyData` (base64) provided instead of `crt` / `key` (PEM)** — the partial always `b64enc`s its input. Pre-base64'd data becomes double-encoded and K8s rejects it (`illegal base64 data`). Use the raw PEM block (with `-----BEGIN ...-----` lines) as `crt:` and `key:`.
- [ ] **PEM cert and key modulus mismatch** — the partial does not verify that the public key in `crt` corresponds to the private key in `key`. Mismatch surfaces only at TLS handshake (`tls: private key does not match public key`). If you can, run `openssl x509 -modulus -noout -in cert | openssl md5` vs `openssl rsa -modulus -noout -in key | openssl md5` before applying.
- [ ] **Certificate already expired** — not validated by the partial. Browsers/clients will hard-fail. Check `openssl x509 -enddate -noout -in cert.pem` before committing.
- [ ] **Wildcard SAN mismatch with the hostname your Ingress/Gateway terminates** — e.g. cert SAN is `*.api.example.com` but the Ingress host is `example.com` or `dev.api.example.com.cn` (extra label depth, different TLD). The partial does not parse SANs. Confirm with `openssl x509 -text -noout -in cert.pem | grep -A1 'Subject Alternative Name'`.
- [ ] **Missing one of `crt`/`crtFile` or `key`/`keyFile`** — the partial calls `fail` and aborts the whole `helm install`/`upgrade`. Both halves are mandatory.
- [ ] **`crtFile` / `keyFile` path resolved relative to `drunk-lib/` instead of the consuming chart** — `$.Files` is bound to the **consumer chart's** files (because library partials inherit the caller's Files). Place certs under your app chart's `files/`, not under `drunk-lib/`.
- [ ] **`ca.crt` supplied where a chain belongs in `tls.crt`** — most clients expect the leaf **plus** the intermediate(s) concatenated in `tls.crt`; `ca.crt` (the root) is optional and only consumed by a few controllers (e.g. `ingress-nginx` with auth-tls-secret). Concatenate intermediates into `crt:` if your ingress controller doesn't read `ca.crt`.
- [ ] **`tlsSecrets` shaped as a list** — the partial uses `range $k, $v := .Values.tlsSecrets`. A list (`- name: foo`) silently iterates with integer keys (`tls-0`, `tls-1`), which is almost never what's intended. Use a map.
- [ ] **PEM contains Windows line endings / extra whitespace** — `b64enc` preserves CRLFs; some TLS stacks reject them. Normalize to LF before pasting inline.
- [ ] **Two entries collide because their map keys differ only in case** — `tls-Api` and `tls-api` are different K8s names; downstream references (e.g. Ingress `tls.secretName`) often lowercase. Stick to all-lowercase keys.

## Cross-refs

- `drunk-lib-ingress` — typical consumer; reference the Secret as `ingress.tls[*].secretName: tls-<key>` (note the literal `tls-` prefix).
- `drunk-lib-gateway` — Gateway API `listeners[*].tls.certificateRefs[0]` should be `{ kind: Secret, name: tls-<key> }`.
- `drunk-lib-secretprovider` — alternate path: source the cert and key from an external vault via CSI and let `secretObjects` sync a TLS Secret. Preferred for production rotation.

## Last-reviewed-commit

`b964e97`
