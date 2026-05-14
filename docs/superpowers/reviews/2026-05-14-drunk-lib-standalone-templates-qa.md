# QA Report: drunk-lib-standalone-templates

**Date:** 2026-05-14
**Feature slug:** `drunk-lib-standalone-templates`
**Branch:** `feature/drunk-lib-standalone-templates`
**HEAD:** 7312b6c
**QA engineer:** qa-engineer (claude-sonnet-4-6)
**Verdict:** PASSED

---

## 1. Pre-conditions Check

All 9 `impl:be-*` tasks are confirmed complete via commit log:

| Commit | Task |
|---|---|
| `1aa6c90` | Task 1 — capture golden-file baselines |
| `84fef1c` | Task 2 — extend verify.sh with golden-file diff |
| `11f84f0` | Task 3 — make drunk-lib.service standalone |
| `f1f8289` | Task 4 — update drunk.utils.ingressPort |
| `fa807f8` | Task 5 — parameterise HPA scaleTargetRef |
| `215e23a` | Task 6 — per-entry enabled flag for CronJobs |
| `54b62f8` | Task 7 — per-entry enabled flag for Jobs |
| `9680d77` | Task 8 — document new keys in values.yaml |
| `7312b6c` | Task 9 — README standalone usage guide |

---

## 2. verify.sh End-to-End Run

Command: `bash drunk-lib/verify.sh` from the worktree root.

```
Successfully packaged chart and saved it to: .../drunk-lib/drunk-lib-1.2.3.tgz

==> Running golden-file regression checks (machine-diffable renders only) ...
[OK]   drunk-app (values.yaml)
[OK]   drunk-app (service.enabled: false)
[OK]   drunk-app (secretProvider.enabled: true)

All checks passed.
```

Exit code: 0. All three machine-diffable golden-file diffs report `[OK]`.

---

## 3. Acceptance Criteria Coverage Matrix

| # | Criterion (from design + plan) | Status | Evidence |
|---|---|---|---|
| AC-1 | `verify.sh` exits 0 and all three golden-file diffs are `[OK]` | PASS | verify.sh run above |
| AC-2 | `drunk-lib/snapshot.sh` exists, is executable, documents consumer scope | PASS | File present; header comment names all 6 design-doc consumers with rationale |
| AC-3 | 4 golden files committed under `drunk-lib/tests/golden/` | PASS | `drunk-app-default.yaml`, `drunk-app-svc-disabled.yaml`, `drunk-app-secretprovider.yaml`, `drunk-app-example.yaml` all present |
| AC-4 | `verify.sh` has inline comment explaining `values.example.yaml` exclusion | PASS | Line 11 and line 91 of verify.sh both reference `randAlphaNum 5` / non-deterministic output |
| AC-5 | `drunk-lib.service` reads `service.ports` first, falls back to `deployment.ports` | PASS | `_service.tpl` lines 7-11; targeted render confirmed |
| AC-6 | `_service.tpl` initialises `$ports` with `{{- $ports := dict -}}` (not `""`) | PASS | `_service.tpl` line 6 |
| AC-7 | `service.enabled: false` gate works | PASS | Targeted render: 0 Service resources with `service.enabled=false` and `deployment.ports` set |
| AC-8 | `drunk.utils.ingressPort` preference order: `service.ports` → `deployment.ports` → `8080` | PASS | `_helpers.tpl` lines 11-28; standalone ingress render resolved port 80 from `service.ports` |
| AC-9 | `drunk.utils.ingressPort` uses `dict` initialiser | PASS | `_helpers.tpl` line 12: `{{- $ports := dict -}}` |
| AC-10 | `_hpa.tpl` reads `autoscaling.targetKind` (default `"Deployment"`) with `| quote` | PASS | `_hpa.tpl` line 30: `{{ .Values.autoscaling.targetKind | default "Deployment" | quote }}` |
| AC-11 | `_hpa.tpl` reads `autoscaling.targetApiVersion` (default `"apps/v1"`) with `| quote` | PASS | `_hpa.tpl` line 29: `{{ .Values.autoscaling.targetApiVersion | default "apps/v1" | quote }}` |
| AC-12 | HPA StatefulSet render produces quoted `kind: "StatefulSet"` and `apiVersion: "apps/v1"` | PASS | Targeted render output confirmed |
| AC-13 | `_cronjob.tpl` honours per-entry `enabled: false` | PASS | `_cronjob.tpl` line 20: `{{- if ne (toString .enabled) "false" }}`; targeted render: 1 CronJob of 2 (disabled entry skipped) |
| AC-14 | `_job.tpl` honours per-entry `enabled: false` | PASS | `_job.tpl` line 18: `{{- if ne (toString .enabled) "false" }}`; targeted render: 1 Job of 2 (disabled entry skipped) |
| AC-15 | `drunk-lib/values.yaml` documents all 6 new keys | PASS | Keys present: `service.ports`, `service.enabled`, `autoscaling.targetKind`, `autoscaling.targetApiVersion`, `cronJobs[].enabled`, `jobs[].enabled` |
| AC-16 | `drunk-lib/README.md` has standalone-usage guide section | PASS | `## Standalone Template Usage` at line 165 with minimum-values table and examples |
| AC-17 | `drunk-lib/README.md` has non-breaking guarantee section | PASS | `## Non-Breaking Guarantee` at line 263 with golden-file table and update instructions |
| AC-18 | No template file under `drunk-lib/templates/` is missing the `_` underscore prefix | PASS | `ls drunk-lib/templates/ | grep -v '^_'` returns 0 files |
| AC-19 | File count of `drunk-lib/templates/_*.tpl` is 19 (unchanged) | PASS | 19 partials confirmed |
| AC-20 | Standalone render (configMap + service.ports + ingress, no deployment.*) exits 0 | PASS | `helm template` with standalone values file produces ConfigMap, Service, and Ingress without error |
| AC-21 | Backward compat: Service renders from `deployment.ports` when `service.ports` absent | PASS | Targeted render confirmed `kind: Service` |
| AC-22 | No new partial names introduced | PASS | Same 19 partials, no `drunk-lib.standalone.*` variants |

---

## 4. Regression Gaps

No regression gaps identified.

The three machine-diffable golden files cover:
- Default path (empty render — no global.image set)
- `service.enabled: false` suppression path
- `secretProvider.enabled: true` CSI path

The `drunk-app-example.yaml` golden file (excluded from machine diff per plan) covers the full human-review scenario including CronJobs, Jobs, Deployment, Service, and ServiceAccount — confirming the example render structure is unchanged.

---

## 5. Edge Cases

### Covered by implementation

| Edge case | How handled |
|---|---|
| `service.ports` absent AND `deployment.ports` absent | `$ports` stays empty `dict`; render condition `gt (len $ports) 0` is false; no Service emitted |
| `service.enabled` not set (absent) | `toString nil` != `"false"`, so `$enabled` is `true`; Service renders when ports available |
| `cronJobs[].enabled` absent | `toString nil` = `"<nil>"` != `"false"`; entry renders (correct default) |
| `cronJobs[].enabled: true` | `toString true` = `"true"` != `"false"`; entry renders |
| `jobs[].enabled` absent or `true` | Same guard pattern as CronJobs; same correct handling |
| HPA with `targetKind` not set | Falls back to `"Deployment"` default via `| default "Deployment" | quote`; identical to pre-feature hardcoded output |
| `service.ports` is set to non-map value | `kindIs "map" $svc.ports` guard prevents misuse; falls back to `deployment.ports` |

### Not covered (acceptable per design §5.4)

| Edge case | Disposition |
|---|---|
| HPA with `targetKind: StatefulSet` in a golden machine-diffed file | Out of scope per plan — stable renders don't enable autoscaling; targeted render validates this path |
| Multi-port `service.ports` port ordering | Go maps are unordered; same as existing `deployment.ports` multi-port handling; no regression introduced |
| `cronJobs[].enabled: "false"` (string vs bool) | `toString "false"` = `"false"`, so string `"false"` also skips the entry — consistent behaviour |

---

## 6. Findings Summary

No defects found. No `impl:qa-fix-` tasks filed.

---

## 7. Sign-off

All 22 acceptance criteria: PASS.
verify.sh exits 0. All three golden-file diffs: [OK].
0 template files without `_` prefix. 19 partials (unchanged count).
Standalone render (configMap + ingress, no deployment.*): exits 0, correct output.
