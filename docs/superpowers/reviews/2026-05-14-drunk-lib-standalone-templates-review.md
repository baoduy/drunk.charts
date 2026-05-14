# Phase-6 Code Review: drunk-lib-standalone-templates

**Date:** 2026-05-14
**Reviewer:** reviewer (claude-sonnet-4-6)
**Feature slug:** `drunk-lib-standalone-templates`
**Branch:** `feature/drunk-lib-standalone-templates`
**HEAD:** 7312b6c
**Design doc:** `docs/superpowers/specs/2026-05-14-drunk-lib-standalone-templates-design.md`
**Verdict:** REVIEW_PASSED

---

## Summary

9 implementation commits reviewed. All template changes are surgically scoped to their task. The critical `dict` initialiser, `| quote` on HPA string fields, `kindIs "map"` guards, and the four-`end`-tag closing structure in `_cronjob.tpl` and `_job.tpl` are all correctly implemented. No unintended file changes were found. One minor finding (README example title mismatch) and two nits are noted below.

---

## Focus area results

### 1. Backward compatibility

**`_service.tpl`** — The old render condition was `{{- if and .Values.deployment .Values.deployment.ports }}`. The new condition is `$ports non-empty AND $enabled`. For an existing consumer that sets `deployment.ports` and no `service.*` key: `$svc` becomes an empty `dict`; `$ports` falls through to `deployment.ports`; `$enabled` is `not (and false ...)` which is `true`. The Service renders exactly as before. The single-port `→ port 80` mapping is unchanged. Multi-port enumeration is unchanged. The `service.type` expression changed from a verbose `if/else` to `(and (kindIs "map" $svc) $svc.type) | default "ClusterIP"` — for an existing consumer whose `values.yaml` has `service: {type: ClusterIP}` the new expression returns `ClusterIP` correctly; for consumers with no `service:` key, `$svc` is an empty `dict` so `$svc.type` is nil, and `nil | default "ClusterIP"` returns `ClusterIP`. Backward compat holds.

**`_helpers.tpl` (`drunk.utils.ingressPort`)** — Old: reads `deployment.ports` → returns `80` (single) or first port value (multi) or `8080`. New: same logic but prefers `service.ports` first. For any consumer that does not set `service.ports`, the fallback to `deployment.ports` is taken. Output is identical to pre-feature.

**`_hpa.tpl`** — Old: hardcoded `apiVersion: apps/v1` and `kind: Deployment`. New: `{{ .Values.autoscaling.targetApiVersion | default "apps/v1" | quote }}` and `{{ .Values.autoscaling.targetKind | default "Deployment" | quote }}`. For existing consumers that do not set `targetApiVersion` or `targetKind`, the rendered values are `"apps/v1"` and `"Deployment"` (with YAML quotes). The old values were unquoted. This is a cosmetic YAML difference — both forms are semantically equivalent in YAML (a quoted string and an unquoted string of the same value are the same scalar). Kubernetes API server accepts both. The golden-file gate correctly does not catch this change because no stable render enables autoscaling; the arch review PASSED this explicitly.

**`_cronjob.tpl`** — The new `{{- if ne (toString .enabled) "false" }}` guard wraps the `---` block. When `.enabled` is absent, `toString nil` returns `"<nil>"` which is not `"false"`, so the condition is true and the entry renders. Existing consumers with no `enabled` key are unaffected.

**`_job.tpl`** — Same guard pattern. Same backward compat analysis.

All five changed templates preserve existing consumer output under default values. Golden-file machine diff passed (`[OK]` on all three). Backward compat: confirmed.

---

### 2. Helm idiom

**`dict` vs `""` initialiser** — Both `_service.tpl` line 6 and `_helpers.tpl` line 12 initialise `$ports` as `{{- $ports := dict -}}`. Confirmed correct. `len $ports` returns map cardinality (0 for empty map), not byte length. `range $k, $v := $ports` iterates map entries, not bytes. No panic risk.

**`| quote` on HPA string fields** — `_hpa.tpl` lines 28-29 apply `| quote` to both `targetApiVersion` and `targetKind`. This was a SEC advisory that was adopted. Confirmed present.

**`kindIs "map"` guards** — `_service.tpl` and `_helpers.tpl` both guard `$svc.ports` access with `kindIs "map" $svc.ports` before testing it as a map. This prevents a panic if a consumer sets `service.ports` to a scalar by mistake. Correct idiom.

**`keys $ports | first` on single-port map** — returns the port name (e.g. `http`). Used as `targetPort` and `name`. The container port number `$v` is not emitted in the single-port case; instead `port: 80` is hard-coded. This matches the original `_service.tpl` behaviour exactly and is by design (the "single port maps to 80" convention). No regression.

**`toString .enabled` coercion** — `ne (toString .enabled) "false"` handles nil (renders), bool `true` (renders), bool `false` (skips), and string `"false"` (also skips, which is consistent). Correct.

---

### 3. `dict` vs `""` initialiser — confirmed

`_service.tpl` line 6: `{{- $ports := dict -}}` — correct.
`_helpers.tpl` line 12: `{{- $ports := dict -}}` — correct.

Both `len $ports` and `range $ports` semantics work correctly against an empty map. No issue.

---

### 4. Library-chart constraint

All 19 files under `drunk-lib/templates/` are underscore-prefixed (`_*.tpl`). No non-partial file was added. `snapshot.sh` lives under `drunk-lib/` (not `drunk-lib/templates/`) and is covered by `.helmignore` (`*.sh` pattern confirmed present). `drunk-lib/tests/` is covered by the `tests` pattern in `.helmignore`. No OCI packaging constraint violated.

---

### 5. README and values.yaml accuracy

**`values.yaml`** — The six new keys are documented accurately as comments. The `service.ports` fallback, `service.enabled: false` semantics, `autoscaling.targetKind`/`targetApiVersion` defaults (`"Deployment"` / `"apps/v1"`), and per-entry `cronJobs[].enabled` / `jobs[].enabled` behaviour all match the implementation. No drift found.

**`README.md` — Standalone Usage section** — The minimum-values table at lines 171-190 is accurate. `drunk-lib.service` correctly lists `service.ports OR deployment.ports` as required. The `drunk.utils.ingressPort` preference order (`service.ports` → `deployment.ports` → `8080`) matches the implementation. The `autoscaling.targetKind` and `targetApiVersion` defaults match the `| default` values in `_hpa.tpl`.

One minor discrepancy: the `### Example — ConfigMap + Ingress only` section heading says "ConfigMap + Ingress only (no Deployment)" but the example YAML includes `drunk-lib.service` as a third `include` call. The heading title does not match the example body. This is a documentation accuracy issue.

---

### 6. Commit hygiene

| Commit | Scope | Assessment |
|---|---|---|
| `1aa6c90` | `chore(drunk-lib)` | Adds `snapshot.sh` + 4 golden files. Scoped correctly. |
| `84fef1c` | `chore(drunk-lib)` | Extends `verify.sh` only. Scoped correctly. |
| `11f84f0` | `feat(drunk-lib)` | `_service.tpl` only. Scoped correctly. |
| `f1f8289` | `feat(drunk-lib)` | `_helpers.tpl` only. Scoped correctly. |
| `fa807f8` | `feat(drunk-lib)` | `_hpa.tpl` only. Scoped correctly. |
| `215e23a` | `feat(drunk-lib)` | `_cronjob.tpl` only. +2 lines. Scoped correctly. |
| `54b62f8` | `feat(drunk-lib)` | `_job.tpl` only. +2 lines. Scoped correctly. |
| `9680d77` | `docs(drunk-lib)` | `values.yaml` only. Scoped correctly. |
| `7312b6c` | `docs(drunk-lib)` | `README.md` only. Scoped correctly. |

All commits use conventional commit format with `(drunk-lib)` scope. All commit messages accurately describe the change. No unintended file changes in any commit. Dependency order is respected (golden capture precedes verify.sh extension which precedes all template changes). Hygiene: clean.

---

## Findings by Severity

### Critical

None.

---

### Major

None.

---

### Minor

**MINOR-1 — README example heading title mismatch**

Location: `drunk-lib/README.md`, line 206 (`### Example — ConfigMap + Ingress only (no Deployment)`).

The section title says "ConfigMap + Ingress only" but the example YAML body includes three `include` calls: `drunk-lib.configMap`, `drunk-lib.service`, and `drunk-lib.ingress`. The Service include is the essential third piece that makes the standalone ingress example work (it provides the port via `service.ports`). Calling it "ConfigMap + Ingress only" is misleading and could cause a standalone author to omit the Service include, producing an ingress with no reachable backend port.

Suggested title: `### Example — ConfigMap + Service + Ingress (no Deployment)`.

Not blocking — the example body is correct; only the title is misleading.

---

### Nit

**NIT-1 — `_hpa.tpl` missing `---` document separator**

The `_hpa.tpl` file renders an HPA resource starting at line 17 (`---`) when autoscaling is enabled. The separator exists and is correct. However, there is no separator when autoscaling is disabled (the template emits nothing), so this is not actually an issue. Noting it here only because the `---` is inside the double-`if` rather than outside as in other templates; this is consistent with the original implementation and is fine.

**NIT-2 — `verify.sh` uses `${TMPDIR:-/tmp}` prefix for the temp file**

`verify.sh` line 56: `tmp="${TMPDIR:-/tmp}/drunk-lib-verify-$$.yaml"`. The plan originally showed `tmp="$(mktemp)"`. The implementer substituted a manual temp path using `$$` (PID). This is functionally equivalent and avoids a `mktemp` call. The file is cleaned up with `rm -f "$tmp"` after the diff. The PID-based name is sufficiently unique for sequential `run_diff` calls. No issue, but `mktemp` is the safer pattern if parallel verify runs ever occur. Not a blocker.

---

## Scope confirmations

| Check | Result |
|---|---|
| All `drunk-lib/templates/` files are `_*.tpl` | 19 files, all underscore-prefixed. Pass. |
| `snapshot.sh` outside `templates/` | Lives at `drunk-lib/snapshot.sh`. Pass. |
| `.helmignore` covers `*.sh` and `tests` | Both patterns present. Pass. |
| No new `drunk-lib.*` partial names introduced | Same 19 partials as pre-feature. Pass. |
| `$ports := dict` in both changed templates | Confirmed at `_service.tpl:6` and `_helpers.tpl:12`. Pass. |
| `| quote` on HPA targetKind and targetApiVersion | Confirmed at `_hpa.tpl:28-29`. Pass. |
| CronJob/Job `if ne` guard adds exactly 1 `end` tag each | `_cronjob.tpl`: 25→26; `_job.tpl`: 25→26. Pass. |
| Golden files are deterministic for machine-diffed subset | `drunk-app-default.yaml` (1 byte/newline), `drunk-app-svc-disabled.yaml` (1 byte/newline), `drunk-app-secretprovider.yaml` (stable SecretProviderClass). Pass. |
| `drunk-app-example.yaml` excluded from machine diff | `verify.sh` comment at line 91 explains randAlphaNum exclusion. Pass. |
| No workflow or OCI publish changes | Confirmed — `.github/` untouched. Pass. |
