# Security review — drunk-lib-standalone-templates

**Stack signal:** backend=yaml/helm-library, frontend=none, data_at_rest=none
**Posture:** domain=internal-only, pii=no, public_endpoints=no

---

## Always-on

### Secret handling

✅ **Pass** — `git diff origin/main..HEAD` shows no new source files; the feature branch contains only docs/plan/spec files at review time. The plan introduces no hard-coded credentials, API keys, tokens, or connection strings. The new `autoscaling.targetKind`, `autoscaling.targetApiVersion`, `service.ports`, `service.enabled`, `cronJobs[].enabled`, and `jobs[].enabled` keys are all non-sensitive configuration values.

### Logging hygiene

✅ **Pass** — `domain=internal-only`, `pii=no`. This is a Helm library chart: it produces YAML manifests but performs no runtime logging. No log output paths exist in this codebase.

### Dependency CVEs

✅ **Pass** — No new dependencies are introduced. The plan modifies only existing `.tpl` files, `values.yaml`, `verify.sh`, and `snapshot.sh`. No new Helm chart dependencies, no new OCI image references, no new third-party tooling. The existing Helm `v3.17.3` pin is unchanged.

### AuthN / AuthZ

✅ **Pass** — This is a Helm library chart. It renders Kubernetes manifests; it has no runtime endpoints, authentication boundaries, or authorization checks of its own. The templates that produce Kubernetes RBAC or authentication-adjacent resources (`_serviceAccount.tpl`, `_secretprovider.tpl`) are unchanged by this feature.

---

## Feature-specific security questions

The task spec asked five security questions. Each is answered below.

---

### Q1: Could a per-template `enabled: false` flag accidentally suppress a security-related resource without warning?

**Scope of new `enabled` flags in this feature:**

- `service.enabled: false` — suppresses the Kubernetes Service (not a security resource).
- `cronJobs[].enabled: false` — suppresses individual CronJob entries (not a security resource).
- `jobs[].enabled: false` — suppresses individual Job entries (not a security resource).

**Security-adjacent resources reviewed for `enabled` flag coverage:**

| Resource | Template | Guard condition | Could new flags suppress it? |
|---|---|---|---|
| NetworkPolicy | `_networkPolicy.tpl` | `networkPolicies[].enabled` already exists via `hasKey` + truthy check (line 46); legacy `networkPolicy` only on key presence | No new flag; existing guards unchanged |
| podSecurityContext | `_deployment.tpl`, `_statefulset.tpl`, `_cronjob.tpl`, `_job.tpl` | Rendered as a sub-field of the workload, not a top-level enabled flag | Not affected |
| ServiceAccount | `_serviceAccount.tpl` | `serviceAccount.enabled: true` required (opt-in, not opt-out) | Not affected |
| SecretProvider (CSI) | `_secretprovider.tpl` | `secretProvider.enabled: true` required (opt-in) | Not affected |
| TLS Secrets | `_tls-secrets.tpl` | `tlsSecrets[key].enabled: true` or `nil` required — `false` suppresses; this is existing behaviour, not introduced by this feature | Not affected |
| ImagePull Secret | `_imagePull-secret.tpl` | `imageCredentials` key presence (opt-in) | Not affected |
| BackendTLSPolicy | `_backend-tls-policy.tpl` | `httpRoute.enabled` AND `httpRoute.tlsValidation` non-null | Not affected |

✅ **Pass** — None of the three new `enabled: false` flags in this feature touch security-related resources. Security-adjacent resources (`networkPolicy`, `serviceAccount`, `secretProvider`, `tlsSecrets`, `podSecurityContext`) retain their existing guard logic unchanged. Consumers setting `service.enabled: false`, `cronJobs[].enabled: false`, or `jobs[].enabled: false` cannot accidentally suppress any security resource.

One advisory observation: `_networkPolicy.tpl` line 46 uses `or (not (hasKey $policy "enabled")) $policy.enabled` — the logic is sound (renders when key absent OR when key is truthy), and is not modified by this feature. It is noted here as the security-relevant precedent for the opt-out pattern.

---

### Q2: Do the defaults on new keys preserve the current default security posture?

| New key | Default | Security impact |
|---|---|---|
| `service.enabled` | `true` (implicit — Service renders when ports present) | Matches current behaviour exactly. No change in default posture. |
| `service.ports` | absent | Service falls back to `deployment.ports`, same as today. No new default surface. |
| `autoscaling.targetKind` | `"Deployment"` | Matches current hardcoded value. HPA targets same resource as before. |
| `autoscaling.targetApiVersion` | `"apps/v1"` | Matches current hardcoded value. No change. |
| `cronJobs[].enabled` | `true` (absent key renders the entry) | Absent key means render — identical to pre-feature behaviour. |
| `jobs[].enabled` | `true` (absent key renders the entry) | Identical to pre-feature behaviour. |

✅ **Pass** — All six new key defaults are strictly equivalent to the current hardcoded or implicit behaviour. No default security posture regression.

---

### Q3: Golden-file regression gate — are security-sensitive non-default value combinations also protected?

The plan golden-files only the default-values render of `drunk-app`. Design doc §5.4 explicitly scopes golden files to default-values renders and defers edge-case combinations to "targeted `helm template` calls documented in the PR."

The following security-sensitive non-default combinations are NOT golden-filed and therefore not protected against silent regression by the automated `verify.sh` gate:

| Combination | Security-sensitive because |
|---|---|
| `secretProvider.enabled: true` with objects | CSI secret mount; a regression could silently drop vault-fetched secrets from pods |
| `tlsSecrets: {my-cert: {enabled: true, crt: ..., key: ...}}` | TLS secret creation; regression could silently omit TLS secrets needed by Gateway listeners |
| `networkPolicies` with non-empty ingress/egress rules | Network isolation; a regression could silently drop network policy rules |
| `service.enabled: false` (new flag) | Not currently golden-filed; a regression in the new flag logic would silently re-render the Service |
| `cronJobs[].enabled: false` (new flag) | Not currently golden-filed; a regression could silently re-render a disabled CronJob entry |

⚠️ **Risk acknowledged** — The design decision to limit golden files to default-values renders is a conscious trade-off (keeps snapshots small and maintainable). For an `internal-only` Helm library with no PII and no public endpoints, the risk is low-to-medium: a silent regression would affect only internal clusters and would be caught at deploy-time by Kubernetes admission validation rather than escaping to a production endpoint.

Recommended remediation (advisory, not a blocker): The plan's Task 1 (snapshot.sh) and Task 2 (verify.sh) should add at minimum two additional targeted snapshots in `tests/golden/`:
- `drunk-app-svc-disabled.yaml` (using `service.enabled: false` + `deployment.ports`) — exercises the new Service suppression flag.
- `drunk-app-secretprovider.yaml` (using `secretProvider.enabled: true`) — protects the CSI secret path.

These are Medium-severity advisory items. They do not block phase 4 but are strongly recommended as part of the PR.

---

### Q4: Helm template injection / sprig misuse — dynamic key construction or unconstrained values

**New value surfaces introduced by this feature:**

**`autoscaling.targetKind` (string, inserted directly into HPA YAML)**

Plan Task 5 `_hpa.tpl` line:
```
kind: {{ .Values.autoscaling.targetKind | default "Deployment" }}
```

This emits the raw string value of `autoscaling.targetKind` directly into the `scaleTargetRef.kind` field with no validation or quoting. In Helm, unquoted string fields in YAML are safe from YAML injection as long as the value is a simple identifier string — Kubernetes API server will reject any non-conforming `kind` value at admission time. However, there is no template-level guard restricting the value to a known set (`Deployment`, `StatefulSet`, `DaemonSet`, etc.).

Threat: A consumer chart value file could set `targetKind: "Deployment\n  extraField: injected"` which would produce malformed YAML. In practice, Helm's template engine quotes values only when using `| quote`; without `| quote`, a value containing YAML-significant characters (newline, colon+space, `#`) could break YAML structure.

Severity: **Low** for this codebase (`internal-only`). Helm renders to a string buffer; the consumer controls the values file; there is no untrusted input path. Kubernetes admission control rejects malformed manifests before they apply. However, the missing `| quote` on both `targetKind` and `targetApiVersion` is a latent defect.

⚠️ **Risk acknowledged** — Recommend adding `| quote` to both new HPA fields in `_hpa.tpl`:
```
kind: {{ .Values.autoscaling.targetKind | default "Deployment" | quote }}
apiVersion: {{ .Values.autoscaling.targetApiVersion | default "apps/v1" | quote }}
```
This is a Medium advisory, not a block, because the consumer context is fully trusted (`internal-only`).

**`cronJobs[].enabled` and `jobs[].enabled` — `toString` coercion**

Plan Tasks 6 and 7 use:
```
{{- if ne (toString .enabled) "false" }}
```

This pattern correctly distinguishes `nil` (absent key, coerces to `"<nil>"`) from explicit boolean `false` (coerces to `"false"`). It is safe — no injection surface. The Go template `toString` of a boolean is `"true"` or `"false"`, not a YAML-significant value.

✅ **Pass** — No injection risk from the `toString` coercion pattern.

**`service.enabled` — string comparison in _service.tpl plan snippet**

Plan Task 3 uses:
```
{{- $enabled := not (and (kindIs "map" $svc) (eq (toString (index $svc "enabled")) "false")) -}}
```

Same `toString` coercion pattern. Safe for the same reason. No injection risk.

✅ **Pass**

**`drunk.utils.ingressPort` — port value passed to HTTPRoute**

The updated helper emits a port number (integer) resolved from `service.ports` or `deployment.ports`. Port values in these maps are integers; `keys $ports | first` returns a string key (port name), and `get $ports $firstPort` returns the integer value. No injection surface.

✅ **Pass**

**Dynamic key construction review summary:**

No template in this feature performs dynamic key construction (e.g. `printf "rbac.verbs.%s" .Values.someKey`). All new values are used as leaf values (kind name, apiVersion string, boolean flag, port integer). No RBAC verb or label key is derived from raw user values in the new code.

✅ **Pass** — No injection or naming-rule violation vectors introduced.

---

### Q5: OCI publish flow — supply-chain integrity

✅ **Pass (confirmed)** — Design doc §7 explicitly lists "Changes to the OCI publish workflow (`.github/workflows/publish-oci.yml`)" as out of scope. The feature branch `git diff origin/main..HEAD` confirms no changes to `.github/workflows/publish-oci.yml`. The OCI publish flow, GHCR registry push, Helm version pin (`v3.17.3`), and chart provenance mechanisms are untouched by this feature. Supply-chain integrity is unaffected.

---

## Summary

| Severity | Count | Items |
|---|---|---|
| Critical | 0 | — |
| High | 0 | — |
| Medium (advisory) | 2 | Q3 — security-sensitive value combinations not golden-filed; Q4 — `targetKind`/`targetApiVersion` missing `| quote` |
| Low | 0 | — |
| Pass | 8 | Secret handling, logging hygiene, dependency CVEs, AuthN/AuthZ, Q1 enabled-flag safety, Q2 default posture, Q4 toString/ingressPort patterns, Q5 OCI supply chain |
| Risk acknowledged | 1 | Q3 — golden-file coverage gap on security-sensitive non-default paths |

**No Critical or High findings. Phase 4 is not blocked.**

### Advisory tasks for implementer (not blockers)

1. **`_hpa.tpl` — add `| quote` to new string fields.** In Task 5, change:
   ```
   apiVersion: {{ .Values.autoscaling.targetApiVersion | default "apps/v1" }}
   kind: {{ .Values.autoscaling.targetKind | default "Deployment" }}
   ```
   to:
   ```
   apiVersion: {{ .Values.autoscaling.targetApiVersion | default "apps/v1" | quote }}
   kind: {{ .Values.autoscaling.targetKind | default "Deployment" | quote }}
   ```

2. **`snapshot.sh` / `verify.sh` — add two security-path golden snapshots.** Extend Task 1 to also capture:
   - A render with `service.enabled: false` + deployment ports set — validates Service suppression.
   - A render with `secretProvider.enabled: true` — protects the CSI secret path against template regressions.
   These do not need to be committed as part of this feature if the PR documents targeted `helm template` validation results; but committing them is strongly preferred.
