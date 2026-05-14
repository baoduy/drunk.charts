# Architecture Review: drunk-lib-standalone-templates

**Date:** 2026-05-14 (Round 2 — plan-revision re-review)
**Reviewer:** software-architect
**Feature slug:** `drunk-lib-standalone-templates`
**Branch:** `feature/drunk-lib-standalone-templates`
**Design doc:** `docs/superpowers/specs/2026-05-14-drunk-lib-standalone-templates-design.md`
**Plan:** `docs/superpowers/plans/2026-05-14-drunk-lib-standalone-templates-plan.md`
**Verdict:** ARCH_PASSED

---

## Round 2 Finding Dispositions

### CRITICAL-1 — RESOLVED

**Original finding:** `$ports := ""` initialiser causes `len`/`range` panics on non-map.

**Plan revision:** Tasks 3 and 4 now initialise `{{- $ports := dict -}}` throughout. Both tasks also add a bold "Critical type note" block so the implementer cannot substitute the wrong initialiser. The render condition is updated to `gt (len $ports) 0`, which is correct for a map type. The fix is sound.

---

### HIGH-1 — RESOLVED

**Original finding:** Plan snapshot scope (drunk-app only) silently diverged from design §5.1 (six charts) with no documented rationale.

**Plan revision:** Task 1 now contains an explicit six-row scope table with a per-consumer reason for inclusion or exclusion. The reasons are accurate: gateway charts have no drunk-lib dependency in their Chart.yaml; `drunk-squid-basic-auth` vendors a released tarball not local source; `drunk-sample` and `microsoft-hello-world-app` have no Chart.yaml. The justification is also reproduced as a comment block at the top of `snapshot.sh`. The plan-versus-design discrepancy is fully explained and requires no design amendment.

---

### MEDIUM-3 — RESOLVED

**Original finding:** `_job.tpl` uses `randAlphaNum 5` in Job names; the example golden file would always differ on re-render, making `verify.sh` structurally non-functional.

**Plan revision:** The example render (`drunk-app-example.yaml`) is captured by `snapshot.sh` for human PR review but is explicitly excluded from the machine-diff list in `verify.sh`. A comment inside `verify.sh` names the exact cause. Three stable renders replace the previous two-render set: `drunk-app-default`, `drunk-app-svc-disabled`, `drunk-app-secretprovider`. All three were confirmed empty or deterministic via live `helm template` execution against the current templates.

**Stability verification (performed during this review):**
- `drunk-app` default values: 0 bytes output (exit 0). Stable. The `volumes` array-vs-map mismatch and the malformed leading-space `global:` key in `values.yaml` both cause silent suppression of the Deployment under current templates — pre-existing behavior, unaffected by this feature.
- `drunk-app` + `--set service.enabled=false`: 0 bytes under current template (which ignores `service.enabled`). Golden captured as empty. After Task 3 the new template also produces empty for this render (no ports in default values → no Service regardless of `service.enabled`). Diff passes in both pre- and post-change states.
- `drunk-app` + `secretProvider.enabled=true`: renders only `kind: SecretProviderClass`. Stable and deterministic. Confirmed via live render.

---

### SEC MEDIUM-A — CORRECTLY HANDLED

The plan adds two new machine-diffable golden renders: `drunk-app-svc-disabled.yaml` (tests the `service.enabled: false` suppression path) and `drunk-app-secretprovider.yaml` (tests the CSI secret provider path). Both are stable. These provide meaningful regression coverage for the two paths most likely to be affected by template edits in this feature. Coverage is adequate.

---

### SEC MEDIUM-B — CORRECTLY HANDLED

Task 5 emits `autoscaling.targetKind` and `autoscaling.targetApiVersion` with `| quote`. The quoted output (`kind: "Deployment"`, `apiVersion: "apps/v1"`) is valid YAML. The plan correctly notes that no golden update is needed after this change because none of the three stable renders enable autoscaling (confirmed: `#autoscaling:` is commented out in `drunk-app/values.yaml`). The Task 5 "Important" note instructs the implementer to verify this before proceeding, which is the right gate.

One advisory on the `| quote` choice: any existing consumer who has a committed golden file that exercises the HPA path would now see `"Deployment"` instead of `Deployment` in the diff. Since no stable golden file in this feature exercises that path, the regression gate does not catch it. The targeted `helm template` check in Task 5 Step 3 validates the new behavior manually. This is acceptable — the change is cosmetically different but semantically equivalent YAML, and design §4.5 explicitly adds these as new optional fields with defined defaults.

---

## Remaining Advisories (non-blocking, carry forward)

**MEDIUM-1 (single-port Service maps to port 80):** Still advisory. The README standalone usage table entry for `drunk-lib.service` covers the port-resolution behavior implicitly. Implementer should add an inline comment to `_service.tpl` during Task 3 as a courtesy to future authors.

**MEDIUM-2 (boolean-only `enabled` flag):** Still advisory. The `toString` guard is correct for YAML boolean inputs. The values.yaml documentation block in Task 8 specifies `bool` type for `cronJobs[].enabled` and `jobs[].enabled`, which is sufficient documentation of the constraint.

**LOW-1 (.helmignore coverage):** Not addressed in the plan revision. Implementer should verify `drunk-lib/.helmignore` excludes `*.sh` and `tests/` before the Task 1 commit. If those patterns are absent, add them as part of Task 1. Does not block implementation.

---

## Backward Compatibility Confirmation

All three backward-compatibility paths verified correct in the updated plan:

- **Service fallback chain:** `service: {type: ClusterIP}` in default `values.yaml` (no `service.ports`, no `service.enabled`) → `$svc` is a map with no `ports` key → falls through to `deployment.ports` → correct existing behavior preserved.
- **HPA defaults:** `targetKind` defaults to `"Deployment"`, `targetApiVersion` defaults to `"apps/v1"` — matches current hardcoded values exactly (modulo quoting, which is semantically equivalent YAML).
- **CronJob/Job `enabled` flag:** Absent key → `toString nil` → `"<nil>"` → `ne "false"` is true → entry renders. Existing consumers unaffected.

---

## Library-Chart Constraint Check

No task in the revised plan introduces a non-`_*.tpl` file under `drunk-lib/templates/`. All new files (`snapshot.sh`, `tests/golden/*.yaml`, extended `verify.sh`) are outside the `templates/` directory. Constraint is not violated.

---

## Task Ordering Check

Golden capture (Task 1) precedes verify.sh extension (Task 2) precedes all template changes (Tasks 3–7). Each template task requires `bash drunk-lib/verify.sh` to pass before commit. The dependency graph is correctly expressed and enforced by the task step structure.
