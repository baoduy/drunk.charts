# Architecture Review: drunk-lib-standalone-templates

**Date:** 2026-05-14
**Reviewer:** software-architect
**Feature slug:** `drunk-lib-standalone-templates`
**Branch:** `feature/drunk-lib-standalone-templates`
**Design doc:** `docs/superpowers/specs/2026-05-14-drunk-lib-standalone-templates-design.md`
**Plan:** `docs/superpowers/plans/2026-05-14-drunk-lib-standalone-templates-plan.md`
**Verdict:** ARCH_BLOCKED

---

## Summary

The design intent is sound and the approach (Approach A — additive keys with fallback chains) is the right choice. Five of the six planned code changes are straightforward and low-risk. Two issues rise to Critical/High and must be resolved before implementation begins.

---

## Findings

### CRITICAL-1: `$ports` initialised to empty string breaks `kindIs` and `len` calls in _service.tpl and _helpers.tpl

**Location:** Plan Task 3, Step 1 (`_service.tpl` replacement); Plan Task 4, Step 1 (`drunk.utils.ingressPort` replacement).

**Problem:** Both proposed template blocks open with:

```
{{- $ports := "" -}}
```

Then later branch on `{{- if $ports -}}` or `{{- if and $ports $enabled }}`. In Go templates the empty string `""` is falsy, which is the desired default — but the block also calls `{{- if eq (len $ports) 1 -}}` and `{{- range $k, $v := $ports -}}`. When `$ports` holds the string `""` rather than a map, both calls produce a template execution error at render time: `len` of a string returns byte-length (not map-length), and `range` over a string iterates byte values, not key-value pairs.

The correct idiom is `{{- $ports := dict -}}` (an empty map) or the two-step approach used by the existing `_service.tpl`: the `$ports` variable is only assigned if the relevant `.Values` key is non-nil, and the outer `if $ports` guard is only entered when it holds a real map.

The existing service template avoids this because it does not use an intermediate variable — it reads `.Values.deployment.ports` directly inside the render block. The new multi-source fallback logic requires a variable, but that variable must start as a map (or `nil`), not as the string `""`.

**Risk:** Any consumer whose `service` key is absent (the majority: `drunk-app` with `values.yaml`, all gateway charts) will trigger a render-time panic as soon as the implementer applies the Task 3 code exactly as written. The golden-file check in verify.sh will catch this, but only after a confusing template-execution error rather than a clean diff failure.

**Remediation:** Replace `{{- $ports := "" -}}` with `{{- $ports := dict -}}` (or omit the initialiser and use `{{- $ports := .Values.service.ports | default dict -}}` with a nil guard). The conditional `{{- if $ports -}}` remains correct because an empty dict is falsy. The same fix applies to `drunk.utils.ingressPort`.

---

### HIGH-1: Golden-file scope in plan covers only drunk-app; design doc §5.1 specifies six consumer charts

**Location:** Plan Task 1 (snapshot.sh), Plan Task 2 (verify.sh diff step); Design §5.1.

**Problem:** The design names six consumer charts for golden-file capture:

1. `drunk-app` (default values)
2. `drunk-traefik-gateway` (default values)
3. `drunk-nginx-gateway` (default values)
4. `drunk-squid-basic-auth` (default values)
5. `drunk-sample` (default values)
6. `microsoft-hello-world-app` (default values)

The plan's `snapshot.sh` and `verify.sh` diff step capture only two snapshots: `drunk-app` with `values.example.yaml` and `drunk-app` with `values.yaml`. The other four named charts are absent from both scripts.

Inspection of the repository confirms the situation is more nuanced than the design assumes: `drunk-traefik-gateway` and `drunk-nginx-gateway` depend on `cert-manager` and `traefik`/`nginx-gateway-fabric`, not on `drunk-lib` (their `Chart.yaml` has no `drunk-lib` dependency). `drunk-squid-basic-auth` depends on `drunk-app` (an application chart), not on `drunk-lib` directly. `drunk-sample` has no `Chart.yaml` at all (it is a deploy-script directory, not a Helm chart). `microsoft-hello-world-app` similarly has no `Chart.yaml`.

This means the design's §5.1 consumer list is partially incorrect: only `drunk-app` is a direct drunk-lib consumer that can be `helm template`-rendered locally. The plan correctly narrows scope to `drunk-app`, but it does so silently — there is no documentation in the plan or snapshot.sh explaining why the other five charts are excluded. This creates a plan-versus-design discrepancy that will confuse any reviewer comparing the two documents.

**Risk:** The regression gate is weaker than the design implies. If a future chart becomes a direct drunk-lib consumer, there is no established process to add it. More immediately, a reviewer or QA agent will flag the plan as non-conformant to the design.

**Remediation (choose one):**

A. Update `snapshot.sh` and `verify.sh` to add a comment block explaining that only direct drunk-lib consumers renderable without external chart dependencies are included, and explicitly list why each of the five excluded charts is excluded. The planner adds this justification to the plan's Task 1 context section. No design amendment needed because this is a clarification, not a scope change.

B. Update design §5.1 to narrow the consumer list to `drunk-app` only, with a note that the other charts do not directly depend on `drunk-lib`. Owner re-approves the design delta.

Recommendation: Option A — the plan can carry the justification inline without reopening the design, and the exclusion rationale belongs in the scripts as operational documentation.

---

### MEDIUM-1: Single-port Service port-mapping inconsistency between old and new _service.tpl

**Location:** Plan Task 3, Step 1 (_service.tpl replacement); existing `_service.tpl` lines 25–29.

**Problem:** The existing template, when `deployment.ports` has exactly one entry, emits:

```yaml
- port: 80
  targetPort: <port-name>
```

The proposed new template preserves this. However, the new multi-port branch (when `$ports` has more than one entry) emits:

```yaml
- port: {{ $v }}
  targetPort: {{ $k }}
```

This is identical to the existing behavior for the multi-port case. The issue is that when a consumer sets `service.ports` with a single entry, they get `port: 80` (same as deployment.ports single-port path). This is correct and consistent — but it is not documented. A standalone author setting `service.ports: { http: 8080 }` expecting `port: 8080` will be surprised to get `port: 80`. This is a documentation gap, not a behavioral regression.

**Remediation:** Add a comment in `_service.tpl` and in the README standalone usage table noting that single-port services always expose on port 80 (consistent with existing behavior).

---

### MEDIUM-2: CronJob `enabled` flag guard uses `toString` on `.enabled` — fragile for boolean YAML values

**Location:** Plan Task 6, Step 1; Plan Task 7, Step 1.

**Problem:** The proposed guard is:

```
{{- if ne (toString .enabled) "false" }}
```

The plan's own rationale states this is to distinguish `nil` (absent key → `"<nil>"`) from explicit `false` (→ `"false"`). This works for YAML `enabled: false` (parsed as boolean false) because Go template's `toString` on a boolean `false` produces `"false"`. However:

- YAML `enabled: "false"` (string) also produces `"false"` and is correctly suppressed — this is the expected case.
- YAML `enabled: 0` would produce `"0"`, which would NOT be suppressed (0 is a common falsy value in some YAML authoring styles, though non-standard here).
- The design doc (§4.1) specifies the default as boolean `true` (absent key renders entry). The `toString` trick correctly handles boolean false vs. nil, but the logic inverts readability: the positive guard (`if ne ... "false"`) is harder to audit than `if not (eq (toString .enabled) "false")`.

This is not a behavioral regression for existing consumers (none use `enabled` on CronJob/Job entries today), but it is a subtle gotcha for future standalone authors who write `enabled: 0` or other non-boolean falsy values.

**Remediation:** Document in the plan and in values.yaml that `enabled` must be a YAML boolean (`true`/`false`), not a string or integer. The implementation is acceptable as-is for boolean-only inputs.

---

### MEDIUM-3: Jobs template uses `randAlphaNum` — golden-file diff will always fail for Job resources

**Location:** `drunk-lib/templates/_job.tpl` line 23; Plan Task 2 (verify.sh); Plan Task 7.

**Problem:** The existing `_job.tpl` generates job names with a random suffix:

```
name: {{ include "app.name" $root }}-{{ .name }}-{{ randAlphaNum 5 | lower }}
```

Every `helm template` invocation produces a different name. The golden-file for `drunk-app-example.yaml` (which includes Jobs from `values.example.yaml`) will therefore never match a re-render. The verify.sh diff step will always emit a non-empty diff for the Job name field, causing a spurious `[FAIL]` on every run.

The plan's snapshot.sh captures the golden file once, but every subsequent `helm template` call produces a different Job name, so the diff will never be clean. This is not introduced by this feature (it is pre-existing behavior), but the plan creates a regression gate that structurally cannot pass for `drunk-app-example.yaml` if that snapshot contains any Job resources.

Inspection of `values.example.yaml` confirms it does include a `jobs` array (lines 125–133), so the example golden file will contain two Job resources with random suffixes.

**Remediation:** The verify.sh diff for `drunk-app-example.yaml` must either:

A. Pipe the rendered output through a sed/awk filter that normalises Job names before diffing (e.g., replace `name: <prefix>-[a-z0-9]{5}` with a stable placeholder).

B. Exclude the example golden file from the diff step and only diff `drunk-app-default.yaml` (which renders empty and therefore has no Jobs).

C. Add `--set` overrides in the verify.sh helm template call that clear the `jobs` array for the example render.

Option B is the simplest and safest: the default-values render produces empty output (verified stable), and the example render is captured as a human-review artifact (not a machine-enforced diff). The plan should be updated to reflect this. If option A is chosen, the normalisation regex must be documented in verify.sh.

---

### LOW-1: snapshot.sh and verify.sh are not library-chart OCI artifacts — no `_*.tpl` constraint risk, but snapshot.sh location should be noted

**Location:** Plan Task 1 (snapshot.sh created at `drunk-lib/snapshot.sh`).

**Problem:** `snapshot.sh` is placed at `drunk-lib/snapshot.sh`, not under `drunk-lib/templates/`. The library-chart constraint (only `_*.tpl` partials under `templates/`) is not violated. This is advisory: confirm that `.helmignore` in `drunk-lib/` excludes `*.sh` and `tests/` from the packaged `.tgz`, otherwise the OCI image grows unnecessarily.

**Remediation:** Verify `drunk-lib/.helmignore` already excludes shell scripts and the `tests/` directory, or add exclusions before packaging.

---

### LOW-2: Task ordering is correct — golden capture before any template change

**Location:** Plan dependency graph.

**Observation (no action required):** The plan correctly sequences Task 1 (capture baselines) → Task 2 (extend verify.sh) → Tasks 3–7 (template changes), with each template task requiring verify.sh to pass before commit. This satisfies the design's §5.3 requirement that golden files are committed before any template change.

---

### LOW-3: No non-`_*.tpl` files introduced under `drunk-lib/templates/`

**Location:** Plan File Map.

**Observation (no action required):** All new files (`snapshot.sh`, `tests/golden/*.yaml`, extended `verify.sh`) are outside `drunk-lib/templates/`. No task introduces a non-partial file under the templates directory. Library-chart OCI packaging constraint is not violated.

---

## Backward Compatibility Assessment

**service template fallback chain:** Existing consumers set `deployment.ports` and leave `service` absent. The new code reads `service.ports` first (absent → empty dict → falsy), then falls back to `deployment.ports`. Provided the `$ports := ""` initialiser bug (CRITICAL-1) is fixed, the fallback path is semantically identical to the current render path. Existing consumers are unaffected.

**autoscaling.targetKind/targetApiVersion defaults:** Both default to the current hardcoded values (`"Deployment"`, `"apps/v1"`). Existing consumers that enable autoscaling get identical output. Confirmed safe.

**cronJobs/jobs `enabled` flag:** The guard `ne (toString .enabled) "false"` evaluates to `true` for all existing entries (which have no `enabled` key, so `.enabled` is nil, and `toString nil` is `"<nil>"`). Existing consumers are unaffected.

**drunk.utils.ingressPort preference order:** Existing consumers set `deployment.ports` and leave `service` absent. The helper checks `service.ports` first (absent → dict → falsy), then checks `deployment.ports`. Result is identical to current behavior. Safe, once CRITICAL-1 is fixed.

---

## Critical and High Findings Summary (blocking Phase 4)

| ID | Severity | One-line summary |
|---|---|---|
| CRITICAL-1 | Critical | `$ports := ""` initialiser causes `len`/`range` panics on non-map; must be `dict` |
| HIGH-1 | High | Plan's snapshot/verify scope (drunk-app only) silently diverges from design §5.1 (six charts); requires inline justification or design amendment |

**Phase 4 (implementation) is blocked until both findings are resolved.**

MEDIUM-3 (Job random suffix breaks golden-file diff) should be treated as near-High by the planner: without fixing it, verify.sh will structurally never pass for the example snapshot, making the regression gate non-functional for the primary consumer. The planner should address MEDIUM-3 alongside the two blocking findings in the plan revision.
