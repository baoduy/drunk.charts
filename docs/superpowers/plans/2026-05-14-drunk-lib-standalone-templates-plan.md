# drunk-lib Standalone Templates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every `drunk-lib` template partial independently usable without requiring values keys from other templates, while guaranteeing zero output change for all existing consumers.

**Architecture:** Add an `enabled` flag to CronJob/Job array entries, make the Service template read `service.ports` with fallback to `deployment.ports`, update `drunk.utils.ingressPort` to prefer `service.ports`, and parameterise the HPA's `scaleTargetRef` — all purely additive changes. Golden-file snapshots of `drunk-app` renders are committed before any template change and re-diffed by `verify.sh` after every change to enforce the non-breaking guarantee.

**Tech Stack:** Helm 3, Go templates, bash, `helm template`, `helm package`

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `drunk-lib/snapshot.sh` | Create | One-time script: renders every consumer chart and writes golden files |
| `drunk-lib/tests/golden/drunk-app-example.yaml` | Create | Golden snapshot for drunk-app with values.example.yaml |
| `drunk-lib/tests/golden/drunk-app-default.yaml` | Create | Golden snapshot for drunk-app with values.yaml (renders empty — proves no regression) |
| `drunk-lib/verify.sh` | Modify | Extend with golden-file diff step after existing package+copy step |
| `drunk-lib/templates/_service.tpl` | Modify | Read `service.ports` first, fallback to `deployment.ports`; honour `service.enabled: false` |
| `drunk-lib/templates/_helpers.tpl` | Modify | Update `drunk.utils.ingressPort`: prefer `service.ports` → `deployment.ports` → `8080` |
| `drunk-lib/templates/_hpa.tpl` | Modify | Use `autoscaling.targetKind` (default `Deployment`) and `autoscaling.targetApiVersion` (default `apps/v1`) |
| `drunk-lib/templates/_cronjob.tpl` | Modify | Skip entries where `.enabled` is explicitly `false` |
| `drunk-lib/templates/_job.tpl` | Modify | Skip entries where `.enabled` is explicitly `false` |
| `drunk-lib/values.yaml` | Modify | Add commented documentation for all six new optional keys |
| `drunk-lib/README.md` | Modify | Add standalone usage section and per-template values table |

---

## Task 1 (impl:be-capture-golden-snapshots): Capture Golden-File Baselines

**Purpose:** Lock in the current `helm template` output for every templateable consumer chart before any drunk-lib template changes. This is the regression baseline the diff step will protect.

**`estimated_minutes`:** 4
**`files`:**
- Create: `drunk-lib/snapshot.sh`
- Create: `drunk-lib/tests/golden/drunk-app-example.yaml`
- Create: `drunk-lib/tests/golden/drunk-app-default.yaml`

**`depends_on`:** none
**`tests`:** Golden files themselves are the artefact; verified by running `helm template` and confirming non-empty output for the example snapshot.

### Context for the implementer

All paths below are relative to the **worktree root** (`/Users/steven/orca/workspaces/drunk.charts/onboarding/.worktrees/feature/drunk-lib-standalone-templates` or wherever the worktree lives). All `helm template` invocations use the **local** drunk-lib via drunk-app's `file://../drunk-lib` dependency (already vendored in `drunk-app/charts/`).

There are two meaningful snapshots:
- `drunk-app` with `values.example.yaml` — produces real Kubernetes YAML (Deployment, Service, etc.)
- `drunk-app` with `values.yaml` — produces empty output (global.image not set); still golden-filed to prove the empty case is stable

- [ ] **Step 1: Create `drunk-lib/snapshot.sh`**

```bash
#!/usr/bin/env bash
# snapshot.sh — capture golden-file baselines for drunk-lib consumer charts
# Run from the worktree root: bash drunk-lib/snapshot.sh
# Requires: helm 3 in PATH
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GOLDEN_DIR="$SCRIPT_DIR/tests/golden"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

mkdir -p "$GOLDEN_DIR"

echo "==> Capturing drunk-app (values.example.yaml) ..."
helm template test-release "$REPO_ROOT/drunk-app" \
  --values "$REPO_ROOT/drunk-app/values.example.yaml" \
  2>/dev/null > "$GOLDEN_DIR/drunk-app-example.yaml"
echo "    Written: $GOLDEN_DIR/drunk-app-example.yaml ($(wc -l < "$GOLDEN_DIR/drunk-app-example.yaml") lines)"

echo "==> Capturing drunk-app (values.yaml) ..."
helm template test-release "$REPO_ROOT/drunk-app" \
  --values "$REPO_ROOT/drunk-app/values.yaml" \
  2>/dev/null > "$GOLDEN_DIR/drunk-app-default.yaml"
echo "    Written: $GOLDEN_DIR/drunk-app-default.yaml ($(wc -l < "$GOLDEN_DIR/drunk-app-default.yaml") lines)"

echo ""
echo "Golden files captured. Review them, then commit alongside your first template change."
```

- [ ] **Step 2: Make snapshot.sh executable and run it**

```bash
chmod +x drunk-lib/snapshot.sh
bash drunk-lib/snapshot.sh
```

Expected output:
```
==> Capturing drunk-app (values.example.yaml) ...
    Written: .../drunk-lib/tests/golden/drunk-app-example.yaml (NNNN lines)
==> Capturing drunk-app (values.yaml) ...
    Written: .../drunk-lib/tests/golden/drunk-app-default.yaml (1 lines)

Golden files captured. Review them, then commit alongside your first template change.
```

The example file must be more than 100 lines. The default file will be 1 line (Helm always emits a trailing newline). Abort if either command exits non-zero.

- [ ] **Step 3: Verify the example golden file contains expected Kubernetes resources**

```bash
grep "^kind:" drunk-lib/tests/golden/drunk-app-example.yaml | sort
```

Expected output includes at minimum: `kind: Deployment`, `kind: Service`. If those lines are absent, the values.example.yaml may not set `global.image` — inspect and fix before continuing.

- [ ] **Step 4: Commit the baseline snapshots**

```bash
git add drunk-lib/snapshot.sh drunk-lib/tests/golden/
git commit -m "test: capture golden-file baselines for drunk-lib non-breaking guarantee"
```

---

## Task 2 (impl:be-extend-verify-sh): Extend verify.sh with Golden-File Diff

**Purpose:** Make `bash drunk-lib/verify.sh` enforce the non-breaking guarantee automatically. After the existing package+copy steps, re-render each consumer chart and diff against the golden file; any difference causes a non-zero exit.

**`estimated_minutes`:** 3
**`files`:**
- Modify: `drunk-lib/verify.sh`

**`depends_on`:** [`impl:be-capture-golden-snapshots`]
**`tests`:** Running `bash drunk-lib/verify.sh` from inside `drunk-lib/` must exit 0 with no diff output. A deliberate template corruption (e.g. add stray text to `_service.tpl`) must cause a non-zero exit.

### Context for the implementer

`verify.sh` is run from **inside** `drunk-lib/` (i.e. CWD is `drunk-lib/` when it runs — that is the convention used by `CLAUDE.md`'s `test_command: bash drunk-lib/verify.sh`). The existing script does `helm package ./` which works because CWD is the chart directory. The golden diff must work relative to the same script location.

The current content of `drunk-lib/verify.sh`:

```bash
#helm template test ./ --values ./values.yaml --output-dir ../_output --debug

helm package ./
helm repo index ./

# Find the latest .tgz file in the current directory and copy it to drunk-app/charts, overwriting if exists
latest_tgz=$(ls -t ./*.tgz 2>/dev/null | head -n1)
if [ -z "$latest_tgz" ] || [ ! -f "$latest_tgz" ]; then
    echo "No .tgz files found"
    exit 1
fi
mkdir -p ../drunk-app/charts
cp -f "$latest_tgz" ../drunk-app/charts/
```

- [ ] **Step 1: Replace `drunk-lib/verify.sh` with the extended version**

Write the following content to `drunk-lib/verify.sh` (overwrite entirely):

```bash
#!/usr/bin/env bash
# verify.sh — package drunk-lib, copy to drunk-app, then verify golden-file regression
# Run from inside drunk-lib/: bash verify.sh   OR from repo root: bash drunk-lib/verify.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GOLDEN_DIR="$SCRIPT_DIR/tests/golden"

# ── Step 1: Package and index ──────────────────────────────────────────────
cd "$SCRIPT_DIR"
helm package ./
helm repo index ./

# ── Step 2: Copy latest .tgz to drunk-app/charts ──────────────────────────
latest_tgz=$(ls -t ./*.tgz 2>/dev/null | head -n1)
if [ -z "$latest_tgz" ] || [ ! -f "$latest_tgz" ]; then
    echo "No .tgz files found"
    exit 1
fi
mkdir -p "$REPO_ROOT/drunk-app/charts"
cp -f "$latest_tgz" "$REPO_ROOT/drunk-app/charts/"

# ── Step 3: Golden-file regression check ──────────────────────────────────
# Only run if golden directory exists (skip on first-time setup before Task 1)
if [ ! -d "$GOLDEN_DIR" ]; then
    echo "No golden directory found at $GOLDEN_DIR — skipping regression check."
    echo "Run bash drunk-lib/snapshot.sh to capture baselines."
    exit 0
fi

FAIL=0

run_diff() {
    local label="$1"
    local chart_dir="$2"
    local values_file="$3"
    local golden_file="$4"

    if [ ! -f "$golden_file" ]; then
        echo "[SKIP] $label — golden file not found: $golden_file"
        return
    fi

    local tmp
    tmp="$(mktemp)"
    helm template test-release "$chart_dir" --values "$values_file" 2>/dev/null > "$tmp"

    if ! diff -u "$golden_file" "$tmp"; then
        echo ""
        echo "[FAIL] $label — output differs from golden file"
        FAIL=1
    else
        echo "[OK]   $label"
    fi
    rm -f "$tmp"
}

echo ""
echo "==> Running golden-file regression checks ..."
run_diff "drunk-app (values.example.yaml)" \
    "$REPO_ROOT/drunk-app" \
    "$REPO_ROOT/drunk-app/values.example.yaml" \
    "$GOLDEN_DIR/drunk-app-example.yaml"

run_diff "drunk-app (values.yaml)" \
    "$REPO_ROOT/drunk-app" \
    "$REPO_ROOT/drunk-app/values.yaml" \
    "$GOLDEN_DIR/drunk-app-default.yaml"

if [ "$FAIL" -eq 1 ]; then
    echo ""
    echo "ERROR: Golden-file regression detected. See diff above."
    echo "If the change is intentional, update golden files: bash drunk-lib/snapshot.sh"
    exit 1
fi

echo ""
echo "All checks passed."
```

- [ ] **Step 2: Run verify.sh to confirm it passes on the current (unmodified) templates**

```bash
cd drunk-lib && bash verify.sh
```

Expected last line: `All checks passed.`

If any diff appears, the golden files were captured with a different version of drunk-lib than what is currently in the worktree. Investigate and re-run `bash drunk-lib/snapshot.sh` before proceeding.

- [ ] **Step 3: Commit**

```bash
git add drunk-lib/verify.sh
git commit -m "test: add golden-file diff regression check to verify.sh"
```

---

## Task 3 (impl:be-service-standalone): Make `drunk-lib.service` Standalone

**Purpose:** Allow a chart that only uses `drunk-lib.service` (without `drunk-lib.deployment`) to render a Service by reading `service.ports` as the primary port source. Also implement `service.enabled: false` suppression.

**`estimated_minutes`:** 5
**`files`:**
- Modify: `drunk-lib/templates/_service.tpl`

**`depends_on`:** [`impl:be-extend-verify-sh`]
**`tests`:** `bash drunk-lib/verify.sh` (golden diff); plus targeted `helm template` invocations documented in Step 3.

### Context for the implementer

Current render condition: `{{- if and .Values.deployment .Values.deployment.ports }}` — this blocks rendering when only `service.ports` is set.

New logic:
1. Determine the ports map: prefer `service.ports`, fall back to `deployment.ports`, else no Service.
2. Render condition: ports map is non-empty AND `service.enabled` is not explicitly `false`.
3. Port enumeration: same single-port (→ port 80) / multi-port logic, but operating on the resolved ports map.

The `service.type` resolution already guards against `service` being a non-map value; keep that guard.

- [ ] **Step 1: Write the new `drunk-lib/templates/_service.tpl`**

```
{{- /* Template: _service.tpl */ -}}
{{- /* Renders a Service. Port source: service.ports → deployment.ports → (no Service) */ -}}
{{- /* Set service.enabled: false to suppress the Service even when ports are defined. */ -}}
{{- define "drunk-lib.service" -}}
{{- $svc := .Values.service | default dict -}}
{{- $ports := "" -}}
{{- if and $svc (kindIs "map" $svc) $svc.ports -}}
  {{- $ports = $svc.ports -}}
{{- else if and .Values.deployment .Values.deployment.ports -}}
  {{- $ports = .Values.deployment.ports -}}
{{- end -}}
{{- $enabled := not (and (kindIs "map" $svc) (eq (toString (index $svc "enabled")) "false")) -}}
{{- if and $ports $enabled }}
---
# Service — exposes the application's ports inside the cluster.
# Port source resolution: service.ports → deployment.ports
# Set service.enabled: false to suppress this resource.
apiVersion: v1
kind: Service
metadata:
  name: {{ include "app.fullname" . }}
  labels: {{ include "app.labels" . | nindent 4 }}
spec:
  type: {{ (and (kindIs "map" $svc) $svc.type) | default "ClusterIP" }}
  ports:
{{- if eq (len $ports) 1 }}
    - port: 80
      targetPort: {{ keys $ports | first }}
      protocol: TCP
      name: {{ keys $ports | first }}
{{- else }}
{{- range $k, $v := $ports }}
    - port: {{ $v }}
      targetPort: {{ $k }}
      protocol: TCP
      name: {{ $k }}
{{- end }}
{{- end }}
  selector: {{ include "app.selectorLabels" . | nindent 4 }}
{{- end }}
{{- end }}
```

- [ ] **Step 2: Run `bash drunk-lib/verify.sh` — must pass (golden diff clean)**

```bash
cd drunk-lib && bash verify.sh
```

Expected: `All checks passed.`

This confirms existing consumers (`deployment.ports` path) are unaffected.

- [ ] **Step 3: Run targeted standalone and opt-out helm template checks**

**3a — Service from `service.ports` only (no deployment):**

Create a temporary values file `$TMPDIR/svc-only-values.yaml`:
```yaml
nameOverride: standalone-test
global:
  image: nginx
  tag: latest
service:
  ports:
    http: 8080
```

```bash
helm template test-release drunk-app \
  --values $TMPDIR/svc-only-values.yaml 2>/dev/null | grep -A 20 "^kind: Service"
```

Expected: A Service resource with `targetPort: http` and `port: 80` (single port maps to 80).

**3b — Service suppressed with `service.enabled: false`:**

Create `$TMPDIR/svc-disabled-values.yaml`:
```yaml
nameOverride: standalone-test
global:
  image: nginx
  tag: latest
deployment:
  enabled: true
  ports:
    http: 8080
service:
  enabled: false
```

```bash
helm template test-release drunk-app \
  --values $TMPDIR/svc-disabled-values.yaml 2>/dev/null | grep "kind: Service" | wc -l
```

Expected: `0` (no Service rendered).

- [ ] **Step 4: Commit**

```bash
git add drunk-lib/templates/_service.tpl
git commit -m "feat: make drunk-lib.service standalone — read service.ports with fallback to deployment.ports; honour service.enabled: false"
```

---

## Task 4 (impl:be-ingressport-helper): Update `drunk.utils.ingressPort` Port Resolution

**Purpose:** Update the internal helper so a standalone chart using `drunk-lib.ingress` with only `service.ports` set gets the correct port without needing `deployment.ports`.

**`estimated_minutes`:** 3
**`files`:**
- Modify: `drunk-lib/templates/_helpers.tpl`

**`depends_on`:** [`impl:be-service-standalone`]
**`tests`:** `bash drunk-lib/verify.sh` (golden diff); plus targeted `helm template` invocation.

### Context for the implementer

Current `drunk.utils.ingressPort` (lines 10–22 of `_helpers.tpl`):
```
{{- define "drunk.utils.ingressPort" -}}
{{- if and .Values.deployment .Values.deployment.ports -}}
    {{- $ports := .Values.deployment.ports -}}
    {{- if eq (len $ports) 1 -}}
        80
    {{- else -}}
        {{- $firstPort := (keys $ports | first) -}}
        {{- get $ports $firstPort -}}
    {{- end -}}
{{- else -}}
    8080
{{- end -}}
{{- end -}}
```

New preference order: `service.ports` → `deployment.ports` → `8080`.

Single-port logic (→ 80 for `service.ports`, same as deployment.ports) is kept consistent: when only one port is defined in the resolved map, return `80`; when multiple ports, return the value of the first key.

- [ ] **Step 1: Replace the `drunk.utils.ingressPort` define block in `drunk-lib/templates/_helpers.tpl`**

Replace lines 10–22 (the entire `drunk.utils.ingressPort` define) with:

```
{{- define "drunk.utils.ingressPort" -}}
{{- $svc := .Values.service | default dict -}}
{{- $ports := "" -}}
{{- if and (kindIs "map" $svc) $svc.ports -}}
  {{- $ports = $svc.ports -}}
{{- else if and .Values.deployment .Values.deployment.ports -}}
  {{- $ports = .Values.deployment.ports -}}
{{- end -}}
{{- if $ports -}}
  {{- if eq (len $ports) 1 -}}
80
  {{- else -}}
    {{- $firstPort := (keys $ports | first) -}}
    {{- get $ports $firstPort -}}
  {{- end -}}
{{- else -}}
8080
{{- end -}}
{{- end -}}
```

The rest of `_helpers.tpl` (from `# Expand the name of the chart.` onward) is left completely unchanged.

- [ ] **Step 2: Run `bash drunk-lib/verify.sh` — must pass (golden diff clean)**

```bash
cd drunk-lib && bash verify.sh
```

Expected: `All checks passed.`

- [ ] **Step 3: Targeted check — ingress port resolves from service.ports**

Create `$TMPDIR/ingress-svc-values.yaml`:
```yaml
nameOverride: ingress-test
global:
  image: nginx
  tag: latest
service:
  ports:
    http: 9090
ingress:
  enabled: true
  hosts:
    - host: myapp.example.com
      path: /
```

```bash
helm template test-release drunk-app \
  --values $TMPDIR/ingress-svc-values.yaml 2>/dev/null | grep "servicePort:"
```

Expected: `servicePort: 80` (single port → 80 mapping).

- [ ] **Step 4: Commit**

```bash
git add drunk-lib/templates/_helpers.tpl
git commit -m "feat: update drunk.utils.ingressPort to prefer service.ports before deployment.ports"
```

---

## Task 5 (impl:be-hpa-targetkind): Parameterise HPA `scaleTargetRef`

**Purpose:** Allow the HPA to target a StatefulSet (or any other workload kind) by reading `autoscaling.targetKind` and `autoscaling.targetApiVersion`. Both default to the current hardcoded values so existing consumers see identical output.

**`estimated_minutes`:** 3
**`files`:**
- Modify: `drunk-lib/templates/_hpa.tpl`

**`depends_on`:** [`impl:be-extend-verify-sh`]
**`tests`:** `bash drunk-lib/verify.sh` (golden diff); plus StatefulSet-targeted helm template invocation.

### Context for the implementer

Current hardcoded lines in `_hpa.tpl` (lines 24–27):
```
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "app.fullname" . }}
```

Replace with values-driven lines using `autoscaling.targetKind` (default `"Deployment"`) and `autoscaling.targetApiVersion` (default `"apps/v1"`). All other lines in the file are unchanged.

- [ ] **Step 1: Write the updated `drunk-lib/templates/_hpa.tpl`**

```
# Template: _hpa.tpl
# Author: Duy Bao (baoduy)
# Repository: https://github.com/baoduy/drunk.charts
# Description: Helm template library for drunk.charts
# Created: 2025-09-10

# Generate HorizontalPodAutoscaler resource for automatic scaling
# Creates an HPA when .Values.autoscaling.enabled is true
# Scales the deployment based on CPU and/or memory utilization
# Requires .Values.autoscaling.minReplicas, .Values.autoscaling.maxReplicas
# Optional: .Values.autoscaling.targetCPUUtilizationPercentage, .Values.autoscaling.targetMemoryUtilizationPercentage
# Optional: .Values.autoscaling.targetKind (default: Deployment), .Values.autoscaling.targetApiVersion (default: apps/v1)
{{- define "drunk-lib.hpa" -}}
{{- if .Values.autoscaling }}
{{- if .Values.autoscaling.enabled }}
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "app.fullname" . }}
  labels:
    {{- include "app.labels" . | nindent 4 }}
spec:
  # Target workload for scaling — configurable via autoscaling.targetKind and autoscaling.targetApiVersion
  scaleTargetRef:
    apiVersion: {{ .Values.autoscaling.targetApiVersion | default "apps/v1" }}
    kind: {{ .Values.autoscaling.targetKind | default "Deployment" }}
    name: {{ include "app.fullname" . }}
  # Scaling boundaries from values
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
    # CPU-based scaling - configure with .Values.autoscaling.targetCPUUtilizationPercentage
    {{- if .Values.autoscaling.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
    {{- end }}
    # Memory-based scaling - configure with .Values.autoscaling.targetMemoryUtilizationPercentage
    {{- if .Values.autoscaling.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetMemoryUtilizationPercentage }}
    {{- end }}
{{- end }}
{{- end }}
{{- end }}
```

- [ ] **Step 2: Run `bash drunk-lib/verify.sh` — must pass (golden diff clean)**

```bash
cd drunk-lib && bash verify.sh
```

Expected: `All checks passed.`

(The example values file does not enable autoscaling, so the HPA block doesn't appear in the golden file. The diff check still passes because no output changed.)

- [ ] **Step 3: Targeted check — HPA targets a StatefulSet**

Create `$TMPDIR/hpa-sts-values.yaml`:
```yaml
nameOverride: sts-hpa-test
global:
  image: nginx
  tag: latest
statefulset:
  enabled: true
  replicaCount: 3
  ports:
    http: 8080
autoscaling:
  enabled: true
  targetKind: StatefulSet
  targetApiVersion: apps/v1
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
```

```bash
helm template test-release drunk-app \
  --values $TMPDIR/hpa-sts-values.yaml 2>/dev/null | grep -A 5 "scaleTargetRef:"
```

Expected:
```yaml
  scaleTargetRef:
    apiVersion: apps/v1
    kind: StatefulSet
    name: test-release-drunk-app
```

- [ ] **Step 4: Commit**

```bash
git add drunk-lib/templates/_hpa.tpl
git commit -m "feat: parameterise HPA scaleTargetRef — add autoscaling.targetKind and autoscaling.targetApiVersion"
```

---

## Task 6 (impl:be-cronjob-enabled-flag): Add Per-Entry `enabled` Flag to CronJobs

**Purpose:** Allow a values file to include a CronJob entry with `enabled: false` so it is skipped without removing it from the array. Absent `enabled` (or `true`) preserves current behaviour.

**`estimated_minutes`:** 3
**`files`:**
- Modify: `drunk-lib/templates/_cronjob.tpl`

**`depends_on`:** [`impl:be-extend-verify-sh`]
**`tests`:** `bash drunk-lib/verify.sh` (golden diff); plus targeted helm template invocations.

### Context for the implementer

Current loop in `_cronjob.tpl` (line 19):
```
{{- range .Values.cronJobs }}
```

Add a guard immediately inside the range to skip entries where `.enabled` is explicitly `false`. Go templates evaluate `false` as falsy, but an absent key evaluates as `nil` which is also falsy — so `ne .enabled false` would skip when `enabled` is absent. Use `ne (toString .enabled) "false"` to distinguish absent (nil → `"<nil>"`) from explicit false (→ `"false"`.

- [ ] **Step 1: Replace the `{{- range .Values.cronJobs }}` loop opener in `drunk-lib/templates/_cronjob.tpl`**

Find lines 18–20 (the range and the first `---`):
```
{{- define "drunk-lib.cronJobs" -}}
{{- $root := . }}
{{- range .Values.cronJobs }}
---
```

Replace with:
```
{{- define "drunk-lib.cronJobs" -}}
{{- $root := . }}
{{- range .Values.cronJobs }}
{{- if ne (toString .enabled) "false" }}
---
```

Then find the closing `{{- end }}` pair at lines 160–162:
```
{{- end }}
{{- end }}
{{- end }}
```

Replace with (one extra `{{- end }}` for the new `if` block):
```
{{- end }}
{{- end }}
{{- end }}
{{- end }}
```

The full change is exactly two line insertions. All other content of `_cronjob.tpl` is unchanged.

- [ ] **Step 2: Run `bash drunk-lib/verify.sh` — must pass (golden diff clean)**

```bash
cd drunk-lib && bash verify.sh
```

Expected: `All checks passed.`

- [ ] **Step 3: Targeted checks**

**3a — CronJob with no `enabled` key renders normally:**

Create `$TMPDIR/cj-noflag-values.yaml`:
```yaml
nameOverride: cj-test
global:
  image: nginx
  tag: latest
cronJobs:
  - name: daily-job
    schedule: "0 2 * * *"
    command: ["/bin/sh", "-c", "echo hello"]
podSecurityContext: {}
securityContext: {}
resources: {}
```

```bash
helm template test-release drunk-app \
  --values $TMPDIR/cj-noflag-values.yaml 2>/dev/null | grep "kind: CronJob" | wc -l
```

Expected: `1`

**3b — CronJob with `enabled: false` is skipped:**

Create `$TMPDIR/cj-disabled-values.yaml`:
```yaml
nameOverride: cj-test
global:
  image: nginx
  tag: latest
cronJobs:
  - name: daily-job
    schedule: "0 2 * * *"
    command: ["/bin/sh", "-c", "echo hello"]
    enabled: false
  - name: weekly-job
    schedule: "0 2 * * 0"
    command: ["/bin/sh", "-c", "echo weekly"]
podSecurityContext: {}
securityContext: {}
resources: {}
```

```bash
helm template test-release drunk-app \
  --values $TMPDIR/cj-disabled-values.yaml 2>/dev/null | grep "name:.*cj-test" | grep -v "cj-test-weekly"
```

Expected: no output (daily-job is suppressed). The weekly-job must appear:
```bash
helm template test-release drunk-app \
  --values $TMPDIR/cj-disabled-values.yaml 2>/dev/null | grep "name:.*weekly"
```
Expected: `name: cj-test-weekly-job`

- [ ] **Step 4: Commit**

```bash
git add drunk-lib/templates/_cronjob.tpl
git commit -m "feat: add per-entry enabled flag to drunk-lib.cronJobs — false skips the entry"
```

---

## Task 7 (impl:be-job-enabled-flag): Add Per-Entry `enabled` Flag to Jobs

**Purpose:** Same as Task 6 but for `drunk-lib.jobs`. Allows skipping individual Job entries without restructuring the values array.

**`estimated_minutes`:** 3
**`files`:**
- Modify: `drunk-lib/templates/_job.tpl`

**`depends_on`:** [`impl:be-extend-verify-sh`]
**`tests`:** `bash drunk-lib/verify.sh` (golden diff); plus targeted helm template invocations.

### Context for the implementer

Same guard pattern as Task 6. Current loop opener in `_job.tpl` (lines 15–17):
```
{{- define "drunk-lib.jobs" -}}
{{- $root := . }}
{{- range .Values.jobs }}
```

Note: `drunk-lib.jobs` emits `---` on line 20, after the `spec:` of the outer range. The structure is:
```
{{- range .Values.jobs }}
---
apiVersion: batch/v1
kind: Job
...
{{- end }}
{{- end }}
```

- [ ] **Step 1: Replace the `{{- range .Values.jobs }}` loop opener in `drunk-lib/templates/_job.tpl`**

Find lines 15–18:
```
{{- define "drunk-lib.jobs" -}}
{{- $root := . }}
{{- range .Values.jobs }}
---
```

Replace with:
```
{{- define "drunk-lib.jobs" -}}
{{- $root := . }}
{{- range .Values.jobs }}
{{- if ne (toString .enabled) "false" }}
---
```

Then find the closing pair at lines 154–156:
```
      {{- end }}
{{- end }}
{{- end }}
```

Replace with:
```
      {{- end }}
{{- end }}
{{- end }}
{{- end }}
```

All other content of `_job.tpl` is unchanged.

- [ ] **Step 2: Run `bash drunk-lib/verify.sh` — must pass (golden diff clean)**

```bash
cd drunk-lib && bash verify.sh
```

Expected: `All checks passed.`

- [ ] **Step 3: Targeted checks**

**3a — Job with no `enabled` key renders normally:**

Create `$TMPDIR/job-noflag-values.yaml`:
```yaml
nameOverride: job-test
global:
  image: nginx
  tag: latest
jobs:
  - name: migrate
    command: ["/bin/sh", "-c", "echo migrate"]
podSecurityContext: {}
securityContext: {}
resources: {}
```

```bash
helm template test-release drunk-app \
  --values $TMPDIR/job-noflag-values.yaml 2>/dev/null | grep "kind: Job" | wc -l
```

Expected: `1`

**3b — Job with `enabled: false` is skipped:**

Create `$TMPDIR/job-disabled-values.yaml`:
```yaml
nameOverride: job-test
global:
  image: nginx
  tag: latest
jobs:
  - name: migrate
    command: ["/bin/sh", "-c", "echo migrate"]
    enabled: false
  - name: seed
    command: ["/bin/sh", "-c", "echo seed"]
podSecurityContext: {}
securityContext: {}
resources: {}
```

```bash
helm template test-release drunk-app \
  --values $TMPDIR/job-disabled-values.yaml 2>/dev/null | grep "kind: Job" | wc -l
```

Expected: `1` (only `seed` renders; `migrate` is suppressed)

```bash
helm template test-release drunk-app \
  --values $TMPDIR/job-disabled-values.yaml 2>/dev/null | grep "name: job-test-migrate"
```

Expected: no output (migrate job absent from render).

- [ ] **Step 4: Commit**

```bash
git add drunk-lib/templates/_job.tpl
git commit -m "feat: add per-entry enabled flag to drunk-lib.jobs — false skips the entry"
```

---

## Task 8 (impl:be-values-documentation): Document New Keys in values.yaml

**Purpose:** Add commented documentation for all six new optional keys so chart authors discover them via `helm show values drunk-lib`.

**`estimated_minutes`:** 2
**`files`:**
- Modify: `drunk-lib/values.yaml`

**`depends_on`:** [`impl:be-service-standalone`, `impl:be-hpa-targetkind`, `impl:be-cronjob-enabled-flag`, `impl:be-job-enabled-flag`]
**`tests`:** `bash drunk-lib/verify.sh` (golden diff — values.yaml does not affect template rendering unless consumed).

### Context for the implementer

Current `drunk-lib/values.yaml` content (entire file):

```yaml
configMap: []

# SecretProvider (Azure Key Vault CSI Driver)
secretProvider:
  enabled: false
  # name: my-spc # default: <app.name>-spc
  # tenantId: ""
  # vaultName: ""
  # usePodIdentity: false
  # useWorkloadIdentity: true
  objects: []
  # - objectName: my-secret
  #   objectType: secret # secret, key, cert
  #   objectVersion: ""   # optional
  # secretObjects:
  #   - type: Opaque
  #     data:
  #       - key: MY_ENV
  #         objectName: my-secret
```

- [ ] **Step 1: Replace `drunk-lib/values.yaml` with the extended version**

```yaml
configMap: []

# SecretProvider (Azure Key Vault CSI Driver)
secretProvider:
  enabled: false
  # name: my-spc # default: <app.name>-spc
  # tenantId: ""
  # vaultName: ""
  # usePodIdentity: false
  # useWorkloadIdentity: true
  objects: []
  # - objectName: my-secret
  #   objectType: secret # secret, key, cert
  #   objectVersion: ""   # optional
  # secretObjects:
  #   - type: Opaque
  #     data:
  #       - key: MY_ENV
  #         objectName: my-secret

# ── Standalone-template flexibility keys (all optional, all additive) ──────
#
# service.ports — primary port map for drunk-lib.service.
#   Same shape as deployment.ports: map of name → containerPort.
#   When absent, drunk-lib.service falls back to deployment.ports.
#   Example:
#     service:
#       ports:
#         http: 8080
#
# service.enabled — set to false to suppress the Service resource entirely.
#   Default: true (Service renders whenever ports are available).
#   Example:
#     service:
#       enabled: false
#
# autoscaling.targetKind — scaleTargetRef.kind in the HPA.
#   Default: "Deployment". Set to "StatefulSet" for StatefulSet workloads.
#   Example:
#     autoscaling:
#       targetKind: StatefulSet
#
# autoscaling.targetApiVersion — scaleTargetRef.apiVersion in the HPA.
#   Default: "apps/v1".
#   Example:
#     autoscaling:
#       targetApiVersion: apps/v1
#
# cronJobs[].enabled — per-entry flag. false skips that CronJob entry.
#   Default: true (absent key renders the entry).
#   Example:
#     cronJobs:
#       - name: nightly-report
#         schedule: "0 2 * * *"
#         enabled: false   # skip this entry
#
# jobs[].enabled — per-entry flag. false skips that Job entry.
#   Default: true (absent key renders the entry).
#   Example:
#     jobs:
#       - name: db-migrate
#         enabled: false   # skip this entry
```

- [ ] **Step 2: Run `bash drunk-lib/verify.sh` — must pass**

```bash
cd drunk-lib && bash verify.sh
```

Expected: `All checks passed.`

- [ ] **Step 3: Commit**

```bash
git add drunk-lib/values.yaml
git commit -m "docs: document new standalone-flexibility keys in drunk-lib values.yaml"
```

---

## Task 9 (impl:be-readme-update): Update README with Standalone Usage Guide

**Purpose:** Update `drunk-lib/README.md` to document: (a) standalone authoring pattern, (b) which keys each affected template reads, (c) the shared-keys-by-design list, and (d) the golden-file non-breaking guarantee process.

**`estimated_minutes`:** 4
**`files`:**
- Modify: `drunk-lib/README.md`

**`depends_on`:** [`impl:be-values-documentation`]
**`tests`:** `bash drunk-lib/verify.sh` (golden diff — README does not affect render output).

### Context for the implementer

Read the current `drunk-lib/README.md` first to understand existing structure. You will **append** a new top-level section called `## Standalone Template Usage` and **add** a `## Non-Breaking Guarantee` section. Do not restructure or remove existing content.

- [ ] **Step 1: Read `drunk-lib/README.md` to understand current structure**

```bash
wc -l drunk-lib/README.md
head -30 drunk-lib/README.md
```

- [ ] **Step 2: Append the Standalone Usage section to `drunk-lib/README.md`**

Add the following content at the **end** of the file (after the last existing line):

```markdown

---

## Standalone Template Usage

`drunk-lib` partials can be included individually — you are not required to use `drunk-lib.all`. A chart that only needs a ConfigMap and a Service can call exactly those two partials.

### Minimum values per template

| Template | Required keys | Optional keys |
|---|---|---|
| `drunk-lib.configMap` | `configMap` (map) | — |
| `drunk-lib.secrets` | `secrets` (map) | — |
| `drunk-lib.service` | `service.ports` OR `deployment.ports` | `service.enabled` (bool, default true), `service.type` (string, default ClusterIP) |
| `drunk-lib.ingress` | `ingress.enabled: true`, `ingress.hosts` | Uses `drunk.utils.ingressPort` which prefers `service.ports` → `deployment.ports` → 8080 |
| `drunk-lib.hpa` | `autoscaling.enabled: true`, `autoscaling.minReplicas`, `autoscaling.maxReplicas` | `autoscaling.targetKind` (default Deployment), `autoscaling.targetApiVersion` (default apps/v1) |
| `drunk-lib.cronJobs` | `cronJobs` array with `name` and `schedule` | `cronJobs[].enabled` (bool, default true — set false to skip entry) |
| `drunk-lib.jobs` | `jobs` array with `name` | `jobs[].enabled` (bool, default true — set false to skip entry) |
| `drunk-lib.deployment` | `deployment.enabled: true`, `global.image`, `global.tag` | all other deployment.* keys |
| `drunk-lib.statefulset` | `statefulset.enabled: true`, `global.image`, `global.tag` | all other statefulset.* keys |
| `drunk-lib.serviceAccount` | `serviceAccount.enabled: true` | `serviceAccount.name` |
| `drunk-lib.gateway` | `gateway.enabled: true` | all gateway.* keys |
| `drunk-lib.httpRoute` | `httpRoute.enabled: true` | all httpRoute.* keys |
| `drunk-lib.networkPolicies` | `networkPolicies` array | `networkPolicy` (legacy single-policy) |
| `drunk-lib.volumes` | `volumes` map | — |
| `drunk-lib.secretProvider` | `secretProvider.enabled: true` | all secretProvider.* keys |
| `drunk-lib.imagePullSecret` | `imageCredentials` map | — |
| `drunk-lib.tls` | `tlsSecrets` map | — |

### Shared keys (by design)

The following keys are shared across all workload templates (`deployment`, `statefulset`, `cronJobs`, `jobs`). A standalone chart that uses only one workload template simply populates only what that template reads — unused shared keys are absent and silently skipped:

- `env` — environment variables injected into all workload containers
- `volumes` — shared PVC / emptyDir mounts
- `resources` — container resource limits / requests
- `configMap` / `configFrom` — config sources mounted into all workload containers
- `secrets` / `secretFrom` — secret sources mounted into all workload containers
- `secretProvider` — CSI secret store
- `podSecurityContext` / `securityContext` — security contexts
- `serviceAccount` — service account used by all workloads
- `nodeSelector` / `affinity` / `tolerations` — scheduling constraints
- `global.*` — image, tag, imagePullPolicy, imagePullSecret, initContainer, storageClassName

### Example — ConfigMap + Ingress only (no Deployment)

```yaml
# values.yaml of the new chart
configMap:
  APP_ENV: production

service:
  ports:
    http: 8080

ingress:
  enabled: true
  hosts:
    - host: myapp.example.com
      path: /
```

```yaml
# templates/all.yaml
{{ include "drunk-lib.configMap" . }}
{{ include "drunk-lib.service" . }}
{{ include "drunk-lib.ingress" . }}
```

### Example — StatefulSet + HPA targeting StatefulSet

```yaml
global:
  image: myapp
  tag: "1.0.0"

statefulset:
  enabled: true
  replicaCount: 3
  ports:
    http: 8080

autoscaling:
  enabled: true
  targetKind: StatefulSet
  targetApiVersion: apps/v1
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
```

### Example — suppress Service in existing drunk-app consumer

```yaml
# Add to your existing values — no other changes needed
service:
  enabled: false
```

---

## Non-Breaking Guarantee

Every `drunk-lib` change is regression-tested via golden-file snapshots in `drunk-lib/tests/golden/`. `bash drunk-lib/verify.sh` automatically diffs every consumer render against its golden file after packaging.

If you intentionally change consumer output (e.g. a format fix), update the golden files:

```bash
bash drunk-lib/snapshot.sh   # re-captures all golden files
bash drunk-lib/verify.sh     # must then pass
git add drunk-lib/tests/golden/
git commit -m "test: update golden files for <reason>"
```
```

- [ ] **Step 3: Run `bash drunk-lib/verify.sh` — must pass**

```bash
cd drunk-lib && bash verify.sh
```

Expected: `All checks passed.`

- [ ] **Step 4: Commit**

```bash
git add drunk-lib/README.md
git commit -m "docs: add standalone usage guide and non-breaking guarantee section to drunk-lib README"
```

---

## Task Count Check

| Implementer | Tasks |
|---|---|
| backend-developer | 9 (`impl:be-*`) |

9 tasks ≤ 12 cap. Within limits.

---

## Task Dependency Graph

```
impl:be-capture-golden-snapshots
    └─► impl:be-extend-verify-sh
            ├─► impl:be-service-standalone
            │       └─► impl:be-ingressport-helper
            │               └─► impl:be-values-documentation
            │                       └─► impl:be-readme-update
            ├─► impl:be-hpa-targetkind
            │       └─► (feeds into impl:be-values-documentation)
            ├─► impl:be-cronjob-enabled-flag
            │       └─► (feeds into impl:be-values-documentation)
            └─► impl:be-job-enabled-flag
                    └─► (feeds into impl:be-values-documentation)
```

Tasks 5, 6, 7 (`hpa-targetkind`, `cronjob-enabled-flag`, `job-enabled-flag`) are independent of each other and can be executed in parallel after Task 2 completes. Task 8 (`values-documentation`) depends on all four template tasks completing first. Task 9 (`readme-update`) depends on Task 8.

---

## Self-Review Against Design Doc

**Spec §4.2 service** — covered by Task 3 (`impl:be-service-standalone`): `service.ports` primary, `deployment.ports` fallback, `service.enabled: false` suppression. ✓

**Spec §4.3 ingress** — covered by Task 4 (`impl:be-ingressport-helper`): `drunk.utils.ingressPort` now prefers `service.ports`. ✓

**Spec §4.5 hpa** — covered by Task 5 (`impl:be-hpa-targetkind`): `autoscaling.targetKind` and `autoscaling.targetApiVersion` with correct defaults. ✓

**Spec §4.1 cronJobs** — covered by Task 6 (`impl:be-cronjob-enabled-flag`): per-entry `enabled` flag. ✓

**Spec §4.1 jobs** — covered by Task 7 (`impl:be-job-enabled-flag`): per-entry `enabled` flag. ✓

**Spec §4.1 deployment / statefulset** — design says no structural change required (already gated on `enabled`). No task needed. ✓

**Spec §4.4, 4.6–4.12** — design says no changes required. No tasks added. ✓

**Spec §5.1–5.3 golden files** — covered by Tasks 1 and 2 (`capture-golden-snapshots`, `extend-verify-sh`). snapshot.sh created. ✓

**Spec §6.2 new values keys** — all six keys documented in Task 8 (`values-documentation`). ✓

**Spec §6.4 include convention** — README updated in Task 9 (`readme-update`). ✓

**Spec §7 out-of-scope** — no CI workflow changes, no new charts, no chart version bump, no consumer values migration. ✓

**No placeholders found.** All steps contain complete code or exact commands.
