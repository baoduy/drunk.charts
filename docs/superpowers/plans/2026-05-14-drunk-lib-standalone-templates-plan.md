# drunk-lib Standalone Templates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every `drunk-lib` template partial independently usable without requiring values keys from other templates, while guaranteeing zero output change for all existing consumers.

**Architecture:** Add an `enabled` flag to CronJob/Job array entries, make the Service template read `service.ports` with fallback to `deployment.ports`, update `drunk.utils.ingressPort` to prefer `service.ports`, and parameterise the HPA's `scaleTargetRef` — all purely additive changes. Golden-file snapshots of `drunk-app` stable renders are committed before any template change and machine-diffed by `verify.sh` after every change to enforce the non-breaking guarantee. Renders that contain random suffixes (`randAlphaNum` in Job names) are captured for human review only, not machine-diffed.

**Tech Stack:** Helm 3, Go templates, bash, `helm template`, `helm package`

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `drunk-lib/snapshot.sh` | Create | One-time script: renders consumer charts and writes golden files |
| `drunk-lib/tests/golden/drunk-app-default.yaml` | Create | Machine-diffed golden: drunk-app default values (stable, empty render) |
| `drunk-lib/tests/golden/drunk-app-svc-disabled.yaml` | Create | Machine-diffed golden: drunk-app with service.enabled: false |
| `drunk-lib/tests/golden/drunk-app-secretprovider.yaml` | Create | Machine-diffed golden: drunk-app with secretProvider.enabled: true |
| `drunk-lib/tests/golden/drunk-app-example.yaml` | Create | Human-review only (contains randAlphaNum Job names — not machine-diffed) |
| `drunk-lib/verify.sh` | Modify | Extend with golden-file diff step (machine-diffable files only) |
| `drunk-lib/templates/_service.tpl` | Modify | Read `service.ports` first, fallback to `deployment.ports`; honour `service.enabled: false` |
| `drunk-lib/templates/_helpers.tpl` | Modify | Update `drunk.utils.ingressPort`: prefer `service.ports` → `deployment.ports` → `8080` |
| `drunk-lib/templates/_hpa.tpl` | Modify | Use `autoscaling.targetKind` and `autoscaling.targetApiVersion` with defaults |
| `drunk-lib/templates/_cronjob.tpl` | Modify | Skip entries where `.enabled` is explicitly `false` |
| `drunk-lib/templates/_job.tpl` | Modify | Skip entries where `.enabled` is explicitly `false` |
| `drunk-lib/values.yaml` | Modify | Add commented documentation for all six new optional keys |
| `drunk-lib/README.md` | Modify | Add standalone usage section and per-template values table |

---

## Task 1 (impl:be-capture-golden-snapshots): Capture Golden-File Baselines

**Purpose:** Lock in the current `helm template` output for every templateable consumer chart before any drunk-lib template changes. This is the regression baseline the diff step will protect.

**`estimated_minutes`:** 5
**`files`:**
- Create: `drunk-lib/snapshot.sh`
- Create: `drunk-lib/tests/golden/drunk-app-default.yaml`
- Create: `drunk-lib/tests/golden/drunk-app-svc-disabled.yaml`
- Create: `drunk-lib/tests/golden/drunk-app-secretprovider.yaml`
- Create: `drunk-lib/tests/golden/drunk-app-example.yaml`

**`depends_on`:** none
**`tests`:** Golden files are the artefact. The three machine-diffable files must be stable (no random content). The example file is for human review only.

### Context for the implementer — consumer chart scope decision

The design doc (§5.1) listed six consumer charts. Here is the explicit disposition of each one and why it is or is not captured in `snapshot.sh`:

| Consumer | Status | Reason |
|---|---|---|
| `drunk-app` | **Captured (3 renders)** | Directly depends on local `drunk-lib` via `file://../drunk-lib`. The only chart where `helm template` exercises drunk-lib templates locally. |
| `drunk-traefik-gateway` | **Not captured** | Does not depend on `drunk-lib`. Its `Chart.yaml` lists `cert-manager` and `traefik` as dependencies — no drunk-lib partials are called. A template change to drunk-lib cannot affect its output. |
| `drunk-nginx-gateway` | **Not captured** | Same reason as `drunk-traefik-gateway`: depends on `cert-manager` and `nginx-gateway-fabric`, not drunk-lib. |
| `drunk-squid-basic-auth` | **Not captured** | Vendored `drunk-app-1.0.4.tgz` (a released tarball, not the local drunk-lib). Changes to the local drunk-lib source do not affect its render. |
| `drunk-sample` | **Not captured** | Not a Helm chart (no `Chart.yaml`). It is a values overlay deployed via `drunk-app`. Its relevant scenarios are covered by the `drunk-app` renders. |
| `microsoft-hello-world-app` | **Not captured** | Not a Helm chart (no `Chart.yaml`). Same reason as `drunk-sample`. |

Three `drunk-app` renders are captured — default values (empty/stable), `service.enabled: false` (security regression for suppression path), and `secretProvider.enabled: true` (security regression for CSI path). The `values.example.yaml` render is also captured for human review but is **excluded from machine diff** because `_job.tpl` uses `randAlphaNum 5` in Job names, producing non-deterministic output on every render.

All paths below are relative to the **worktree root**.

- [ ] **Step 1: Create `drunk-lib/snapshot.sh`**

Write the following to `drunk-lib/snapshot.sh`:

```bash
#!/usr/bin/env bash
# snapshot.sh — capture golden-file baselines for drunk-lib consumer charts.
# Run from the worktree root: bash drunk-lib/snapshot.sh
#
# IMPORTANT — consumer scope:
#   Only "drunk-app" is captured because it is the sole chart that depends on the
#   local drunk-lib source (via file://../drunk-lib in Chart.yaml). Gateway charts
#   (drunk-traefik-gateway, drunk-nginx-gateway) have no drunk-lib dependency.
#   drunk-squid-basic-auth vendors a released drunk-app tarball, not local drunk-lib.
#   drunk-sample and microsoft-hello-world-app are values files, not Helm charts.
#
# Three renders are machine-diffable (stable, no random content):
#   drunk-app-default.yaml      — default values.yaml (renders empty; stable)
#   drunk-app-svc-disabled.yaml — service.enabled: false regression case
#   drunk-app-secretprovider.yaml — secretProvider.enabled: true regression case
#
# One render is human-review only (NOT machine-diffed in verify.sh):
#   drunk-app-example.yaml      — values.example.yaml; contains randAlphaNum Job names
#                                 that differ on every render
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GOLDEN_DIR="$SCRIPT_DIR/tests/golden"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

mkdir -p "$GOLDEN_DIR"

echo "==> Capturing drunk-app (values.yaml — machine-diffable) ..."
helm template test-release "$REPO_ROOT/drunk-app" \
  --values "$REPO_ROOT/drunk-app/values.yaml" \
  2>/dev/null > "$GOLDEN_DIR/drunk-app-default.yaml"
echo "    Written: $GOLDEN_DIR/drunk-app-default.yaml ($(wc -l < "$GOLDEN_DIR/drunk-app-default.yaml") lines)"

echo "==> Capturing drunk-app (service.enabled: false — machine-diffable) ..."
helm template test-release "$REPO_ROOT/drunk-app" \
  --values "$REPO_ROOT/drunk-app/values.yaml" \
  --set service.enabled=false \
  2>/dev/null > "$GOLDEN_DIR/drunk-app-svc-disabled.yaml"
echo "    Written: $GOLDEN_DIR/drunk-app-svc-disabled.yaml ($(wc -l < "$GOLDEN_DIR/drunk-app-svc-disabled.yaml") lines)"

echo "==> Capturing drunk-app (secretProvider.enabled: true — machine-diffable) ..."
helm template test-release "$REPO_ROOT/drunk-app" \
  --values "$REPO_ROOT/drunk-app/values.yaml" \
  --set secretProvider.enabled=true \
  --set secretProvider.tenantId=test-tenant \
  --set secretProvider.vaultName=test-vault \
  2>/dev/null > "$GOLDEN_DIR/drunk-app-secretprovider.yaml"
echo "    Written: $GOLDEN_DIR/drunk-app-secretprovider.yaml ($(wc -l < "$GOLDEN_DIR/drunk-app-secretprovider.yaml") lines)"

echo "==> Capturing drunk-app (values.example.yaml — HUMAN REVIEW ONLY, not machine-diffed) ..."
helm template test-release "$REPO_ROOT/drunk-app" \
  --values "$REPO_ROOT/drunk-app/values.example.yaml" \
  2>/dev/null > "$GOLDEN_DIR/drunk-app-example.yaml"
echo "    Written: $GOLDEN_DIR/drunk-app-example.yaml ($(wc -l < "$GOLDEN_DIR/drunk-app-example.yaml") lines)"
echo "    NOTE: This file is for human review only. Job names contain randAlphaNum suffixes"
echo "          that change on every render. Do not add it to the machine-diff list in verify.sh."

echo ""
echo "Golden files captured. Review them visually, then commit alongside your first template change."
```

- [ ] **Step 2: Make snapshot.sh executable and run it**

```bash
chmod +x drunk-lib/snapshot.sh
bash drunk-lib/snapshot.sh
```

Expected output (line counts will vary):
```
==> Capturing drunk-app (values.yaml — machine-diffable) ...
    Written: .../drunk-lib/tests/golden/drunk-app-default.yaml (1 lines)
==> Capturing drunk-app (service.enabled: false — machine-diffable) ...
    Written: .../drunk-lib/tests/golden/drunk-app-svc-disabled.yaml (1 lines)
==> Capturing drunk-app (secretProvider.enabled: true — machine-diffable) ...
    Written: .../drunk-lib/tests/golden/drunk-app-secretprovider.yaml (N lines)
==> Capturing drunk-app (values.example.yaml — HUMAN REVIEW ONLY, not machine-diffed) ...
    Written: .../drunk-lib/tests/golden/drunk-app-example.yaml (NNNN lines)
    NOTE: This file is for human review only. ...

Golden files captured. ...
```

The `drunk-app-default.yaml` and `drunk-app-svc-disabled.yaml` will be 1 line (Helm trailing newline) because `global.image` is not set in `values.yaml` so the Deployment does not render, and without `deployment.ports` the Service does not render either. The `secretprovider` render will produce a SecretProviderClass resource. The example render will be 1000+ lines.

Abort if any command exits non-zero.

- [ ] **Step 3: Verify the secretprovider golden file contains expected content**

```bash
grep "^kind:" drunk-lib/tests/golden/drunk-app-secretprovider.yaml
```

Expected: `kind: SecretProviderClass`

- [ ] **Step 4: Visually review the example golden file**

```bash
grep "^kind:" drunk-lib/tests/golden/drunk-app-example.yaml | sort
```

Expected to include at minimum: `kind: CronJob`, `kind: Deployment`, `kind: Job`, `kind: Service`, `kind: ServiceAccount`.

- [ ] **Step 5: Commit the baseline snapshots**

```bash
git add drunk-lib/snapshot.sh drunk-lib/tests/golden/
git commit -m "test: capture golden-file baselines for drunk-lib non-breaking guarantee"
```

---

## Task 2 (impl:be-extend-verify-sh): Extend verify.sh with Golden-File Diff

**Purpose:** Make `bash drunk-lib/verify.sh` enforce the non-breaking guarantee automatically. Machine-diff only the three stable golden files (default values, svc-disabled, secretprovider). The example golden file is excluded from machine diff because `_job.tpl` generates Job names with `randAlphaNum 5` — producing non-deterministic output on every render.

**`estimated_minutes`:** 3
**`files`:**
- Modify: `drunk-lib/verify.sh`

**`depends_on`:** [`impl:be-capture-golden-snapshots`]
**`tests`:** Running `bash drunk-lib/verify.sh` from inside `drunk-lib/` must exit 0. A deliberate template corruption (e.g. add stray text to `_service.tpl`) must cause a non-zero exit and print the diff.

### Context for the implementer

`verify.sh` is run from **inside** `drunk-lib/` (CWD is `drunk-lib/` — that is the convention used by `CLAUDE.md`'s `test_command: bash drunk-lib/verify.sh`). The existing script does `helm package ./` which works because CWD is the chart directory.

**Why the example file is excluded:** `_job.tpl` line 23 uses `randAlphaNum 5 | lower` as part of every Job metadata name. Two runs of `helm template` against the same values produce different Job names. Including `drunk-app-example.yaml` in the machine diff would cause `verify.sh` to fail on every run even when no template changed. The example file remains committed for human visual review (PR diff); it is not a regression gate.

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
# verify.sh — package drunk-lib, copy to drunk-app, then verify golden-file regression.
# Run from inside drunk-lib/: bash verify.sh   OR from repo root: bash drunk-lib/verify.sh
#
# Machine-diffed golden files (stable, no random content):
#   tests/golden/drunk-app-default.yaml       — default values (empty render)
#   tests/golden/drunk-app-svc-disabled.yaml  — service.enabled: false
#   tests/golden/drunk-app-secretprovider.yaml — secretProvider.enabled: true
#
# Excluded from machine diff (intentionally non-deterministic):
#   tests/golden/drunk-app-example.yaml       — contains randAlphaNum Job names;
#                                               committed for human PR review only
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
# Skip entirely if golden directory has not been initialised yet.
if [ ! -d "$GOLDEN_DIR" ]; then
    echo "No golden directory found at $GOLDEN_DIR — skipping regression check."
    echo "Run: bash drunk-lib/snapshot.sh"
    exit 0
fi

FAIL=0

run_diff() {
    local label="$1"
    local chart_dir="$2"
    local golden_file="$3"
    shift 3
    # remaining args are passed verbatim to helm template (--values / --set flags)

    if [ ! -f "$golden_file" ]; then
        echo "[SKIP] $label — golden file not found: $golden_file"
        return
    fi

    local tmp
    tmp="$(mktemp)"
    helm template test-release "$chart_dir" "$@" 2>/dev/null > "$tmp"

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
echo "==> Running golden-file regression checks (machine-diffable renders only) ..."

run_diff "drunk-app (values.yaml)" \
    "$REPO_ROOT/drunk-app" \
    "$GOLDEN_DIR/drunk-app-default.yaml" \
    --values "$REPO_ROOT/drunk-app/values.yaml"

run_diff "drunk-app (service.enabled: false)" \
    "$REPO_ROOT/drunk-app" \
    "$GOLDEN_DIR/drunk-app-svc-disabled.yaml" \
    --values "$REPO_ROOT/drunk-app/values.yaml" \
    --set service.enabled=false

run_diff "drunk-app (secretProvider.enabled: true)" \
    "$REPO_ROOT/drunk-app" \
    "$GOLDEN_DIR/drunk-app-secretprovider.yaml" \
    --values "$REPO_ROOT/drunk-app/values.yaml" \
    --set secretProvider.enabled=true \
    --set secretProvider.tenantId=test-tenant \
    --set secretProvider.vaultName=test-vault

# drunk-app-example.yaml is intentionally excluded: _job.tpl uses randAlphaNum 5
# in Job names → non-deterministic output. It is committed for human PR review only.

if [ "$FAIL" -eq 1 ]; then
    echo ""
    echo "ERROR: Golden-file regression detected. See diff above."
    echo "If the change is intentional, update golden files: bash drunk-lib/snapshot.sh"
    exit 1
fi

echo ""
echo "All checks passed."
```

- [ ] **Step 2: Run verify.sh to confirm it passes on unmodified templates**

```bash
cd drunk-lib && bash verify.sh
```

Expected last line: `All checks passed.`

If any diff appears, the golden files were captured with a different drunk-lib state than the current worktree. Re-run `bash drunk-lib/snapshot.sh` from the worktree root, then retry.

- [ ] **Step 3: Commit**

```bash
git add drunk-lib/verify.sh
git commit -m "test: add golden-file diff regression check to verify.sh (machine-diffable renders only)"
```

---

## Task 3 (impl:be-service-standalone): Make `drunk-lib.service` Standalone

**Purpose:** Allow a chart that only uses `drunk-lib.service` (without `drunk-lib.deployment`) to render a Service by reading `service.ports` as the primary port source. Also implement `service.enabled: false` suppression.

**`estimated_minutes`:** 5
**`files`:**
- Modify: `drunk-lib/templates/_service.tpl`

**`depends_on`:** [`impl:be-extend-verify-sh`]
**`tests`:** `bash drunk-lib/verify.sh` (three golden diffs); plus targeted `helm template` invocations in Step 3.

### Context for the implementer

Current render condition: `{{- if and .Values.deployment .Values.deployment.ports }}` — this blocks rendering when only `service.ports` is set.

**Critical type note:** The ports variable MUST be initialised as `dict` (an empty map), NOT as an empty string `""`. Initialising as `""` causes `len $ports` to return byte-length on a string and `range $k, $v := $ports` to iterate bytes — both produce wrong output or a template panic when a real map is later not assigned. The correct initialiser is `{{- $ports := dict -}}`.

New logic:
1. Determine the ports map: initialise as `dict`; prefer `service.ports` when it is a non-empty map, fall back to `deployment.ports` when that is a non-empty map, else leave as empty `dict`.
2. Render condition: `$ports` is non-empty (`gt (len $ports) 0`) AND `service.enabled` is not explicitly `false`.
3. Port enumeration: same single-port (→ port 80) / multi-port logic, operating on the resolved ports map.

- [ ] **Step 1: Write the new `drunk-lib/templates/_service.tpl`**

```
{{- /* Template: _service.tpl                                                */ -}}
{{- /* Renders a Service. Port source: service.ports → deployment.ports.     */ -}}
{{- /* Set service.enabled: false to suppress even when ports are defined.   */ -}}
{{- define "drunk-lib.service" -}}
{{- $svc := .Values.service | default dict -}}
{{- $ports := dict -}}
{{- if and (kindIs "map" $svc) $svc.ports (kindIs "map" $svc.ports) -}}
  {{- $ports = $svc.ports -}}
{{- else if and .Values.deployment (kindIs "map" .Values.deployment) .Values.deployment.ports -}}
  {{- $ports = .Values.deployment.ports -}}
{{- end -}}
{{- $enabled := not (and (kindIs "map" $svc) (eq (toString (index $svc "enabled")) "false")) -}}
{{- if and (gt (len $ports) 0) $enabled }}
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

- [ ] **Step 2: Run `bash drunk-lib/verify.sh` — must pass (all three golden diffs clean)**

```bash
cd drunk-lib && bash verify.sh
```

Expected: `All checks passed.`

This confirms:
- The `drunk-app-default.yaml` diff: no Service renders (no ports in default values) — still empty.
- The `drunk-app-svc-disabled.yaml` diff: Service suppressed by `service.enabled: false` — still empty.
- The `drunk-app-secretprovider.yaml` diff: no Service (no ports in default values) — same content.

- [ ] **Step 3: Run targeted standalone and opt-out helm template checks**

**3a — Service from `service.ports` only (no deployment):**

```bash
helm template test-release drunk-app \
  --set nameOverride=standalone-test \
  --set global.image=nginx \
  --set global.tag=latest \
  --set "service.ports.http=8080" \
  2>/dev/null | grep -A 20 "^kind: Service"
```

Expected: A Service resource with `targetPort: http` and `port: 80` (single-port maps to 80).

**3b — Service suppressed with `service.enabled: false` when deployment.ports is set:**

```bash
helm template test-release drunk-app \
  --set nameOverride=standalone-test \
  --set global.image=nginx \
  --set global.tag=latest \
  --set deployment.enabled=true \
  --set "deployment.ports.http=8080" \
  --set service.enabled=false \
  2>/dev/null | grep "kind: Service" | wc -l
```

Expected: `0` (no Service rendered).

**3c — Service still renders from `deployment.ports` when `service.ports` is absent (backwards-compat):**

```bash
helm template test-release drunk-app \
  --set nameOverride=standalone-test \
  --set global.image=nginx \
  --set global.tag=latest \
  --set deployment.enabled=true \
  --set "deployment.ports.http=8080" \
  2>/dev/null | grep "kind: Service"
```

Expected: `kind: Service`

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
**`tests`:** `bash drunk-lib/verify.sh` (three golden diffs); plus targeted `helm template` invocation in Step 3.

### Context for the implementer

**Critical type note:** Same as Task 3 — the ports variable MUST be initialised as `{{- $ports := dict -}}`, not as `""`. An empty string initialiser causes `len` to return byte count and `range` to iterate bytes, producing wrong output or a panic.

Current `drunk.utils.ingressPort` define (lines 10–22 of `_helpers.tpl`):
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

When the resolved ports map has exactly one entry, return `80` (consistent with the Service template's single-port mapping). When it has multiple entries, return the value (container port number) of the first key.

- [ ] **Step 1: Replace the `drunk.utils.ingressPort` define block in `drunk-lib/templates/_helpers.tpl`**

Replace the entire `drunk.utils.ingressPort` define (lines 10–22) with the following. All other content of `_helpers.tpl` (from `# Expand the name of the chart.` onward) is left completely unchanged.

```
{{- define "drunk.utils.ingressPort" -}}
{{- $svc := .Values.service | default dict -}}
{{- $ports := dict -}}
{{- if and (kindIs "map" $svc) $svc.ports (kindIs "map" $svc.ports) -}}
  {{- $ports = $svc.ports -}}
{{- else if and .Values.deployment (kindIs "map" .Values.deployment) .Values.deployment.ports -}}
  {{- $ports = .Values.deployment.ports -}}
{{- end -}}
{{- if gt (len $ports) 0 -}}
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

- [ ] **Step 2: Run `bash drunk-lib/verify.sh` — must pass (all three golden diffs clean)**

```bash
cd drunk-lib && bash verify.sh
```

Expected: `All checks passed.`

- [ ] **Step 3: Targeted check — ingress port resolves from `service.ports`**

```bash
helm template test-release drunk-app \
  --set nameOverride=ingress-test \
  --set global.image=nginx \
  --set global.tag=latest \
  --set "service.ports.http=9090" \
  --set ingress.enabled=true \
  --set "ingress.hosts[0].host=myapp.example.com" \
  --set "ingress.hosts[0].path=/" \
  2>/dev/null | grep "servicePort:"
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
**`tests`:** `bash drunk-lib/verify.sh` (three golden diffs); plus StatefulSet-targeted helm template invocation in Step 3.

### Context for the implementer

Current hardcoded lines in `_hpa.tpl` (lines 24–27):
```yaml
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "app.fullname" . }}
```

Replace with values-driven lines. Both `targetKind` and `targetApiVersion` must be emitted with `| quote` so the rendered YAML always quotes the string value — this prevents YAML type-coercion issues if a future value looks numeric or boolean.

Defaults must match the current hardcoded values exactly so existing consumers see bit-for-bit identical output when they do not set these new keys.

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
# Optional: .Values.autoscaling.targetKind (default: "Deployment"), .Values.autoscaling.targetApiVersion (default: "apps/v1")
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
  # Target workload for scaling.
  # Set autoscaling.targetKind to "StatefulSet" or another workload kind when not scaling a Deployment.
  # Set autoscaling.targetApiVersion if the workload uses a non-standard API group.
  scaleTargetRef:
    apiVersion: {{ .Values.autoscaling.targetApiVersion | default "apps/v1" | quote }}
    kind: {{ .Values.autoscaling.targetKind | default "Deployment" | quote }}
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

**Important:** Because existing consumers' golden files were captured with the old (unquoted) `apiVersion: apps/v1` and `kind: Deployment` and now the new template emits `apiVersion: "apps/v1"` and `kind: "Deployment"` (quoted), you MUST re-run `bash drunk-lib/snapshot.sh` after writing this template to update the golden files, then verify the diff is exactly and only the addition of quotes around those two values. Commit the updated golden files together with the template change.

- [ ] **Step 2: Write the template, then update golden files**

After writing `_hpa.tpl` as above, run:

```bash
# Repackage and update golden files to capture the quote addition
cd drunk-lib && bash verify.sh 2>/dev/null || true   # may fail — expected if autoscaling in golden
bash ../drunk-lib/snapshot.sh 2>/dev/null || bash drunk-lib/snapshot.sh
```

Wait — check whether any of the three machine-diffable renders enable autoscaling:

```bash
grep "autoscaling" drunk-app/values.yaml
```

Expected: no `autoscaling.enabled: true` in `values.yaml` (autoscaling is commented out). Therefore the HPA block does not appear in any of the three golden files, and `verify.sh` will pass immediately without a golden update.

Run:

```bash
cd drunk-lib && bash verify.sh
```

Expected: `All checks passed.` (no HPA in stable renders, so no golden update needed).

- [ ] **Step 3: Targeted check — HPA targets a StatefulSet**

```bash
helm template test-release drunk-app \
  --set nameOverride=sts-hpa-test \
  --set global.image=nginx \
  --set global.tag=latest \
  --set statefulset.enabled=true \
  --set statefulset.replicaCount=3 \
  --set "statefulset.ports.http=8080" \
  --set autoscaling.enabled=true \
  --set autoscaling.targetKind=StatefulSet \
  --set autoscaling.targetApiVersion=apps/v1 \
  --set autoscaling.minReplicas=2 \
  --set autoscaling.maxReplicas=10 \
  --set autoscaling.targetCPUUtilizationPercentage=70 \
  2>/dev/null | grep -A 5 "scaleTargetRef:"
```

Expected:
```yaml
  scaleTargetRef:
    apiVersion: "apps/v1"
    kind: "StatefulSet"
    name: sts-hpa-test-drunk-app
```

- [ ] **Step 4: Commit**

```bash
git add drunk-lib/templates/_hpa.tpl
git commit -m "feat: parameterise HPA scaleTargetRef — add autoscaling.targetKind and autoscaling.targetApiVersion (quoted)"
```

---

## Task 6 (impl:be-cronjob-enabled-flag): Add Per-Entry `enabled` Flag to CronJobs

**Purpose:** Allow a values file to include a CronJob entry with `enabled: false` so it is skipped without removing it from the array. Absent `enabled` (or `true`) preserves current behaviour.

**`estimated_minutes`:** 3
**`files`:**
- Modify: `drunk-lib/templates/_cronjob.tpl`

**`depends_on`:** [`impl:be-extend-verify-sh`]
**`tests`:** `bash drunk-lib/verify.sh` (three golden diffs); plus targeted helm template invocations in Step 3.

### Context for the implementer

Current loop in `_cronjob.tpl` (lines 17–20):
```
{{- define "drunk-lib.cronJobs" -}}
{{- $root := . }}
{{- range .Values.cronJobs }}
---
```

The closing structure at the bottom of the file is:
```
{{- end }}
{{- end }}
{{- end }}
```
(Three `end` tags: innermost closes the `volumeMounts` block, middle closes `range`, outer closes `define`.)

Add a per-entry guard using `ne (toString .enabled) "false"`:
- When `.enabled` is absent, `toString nil` → `"<nil>"` which is not equal to `"false"` → entry renders (correct).
- When `.enabled` is `true`, `toString true` → `"true"` → entry renders (correct).
- When `.enabled` is `false`, `toString false` → `"false"` → entry is skipped (correct).

- [ ] **Step 1: Replace lines 17–21 in `drunk-lib/templates/_cronjob.tpl`**

Find these lines (define opener, root assignment, range, and first `---`):
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

Then find the three closing `{{- end }}` tags at the bottom of the file:
```
{{- end }}
{{- end }}
{{- end }}
```

Replace with four closing tags (add one for the new `if` block):
```
{{- end }}
{{- end }}
{{- end }}
{{- end }}
```

No other content in `_cronjob.tpl` changes.

- [ ] **Step 2: Run `bash drunk-lib/verify.sh` — must pass (all three golden diffs clean)**

```bash
cd drunk-lib && bash verify.sh
```

Expected: `All checks passed.`

None of the three machine-diffable golden renders contain CronJobs (`values.yaml` has no cronJobs configured), so the diffs remain clean.

- [ ] **Step 3: Targeted checks**

**3a — CronJob with no `enabled` key renders normally:**

```bash
helm template test-release drunk-app \
  --set nameOverride=cj-test \
  --set global.image=nginx \
  --set global.tag=latest \
  --set "cronJobs[0].name=daily-job" \
  --set "cronJobs[0].schedule=0 2 * * *" \
  --set "cronJobs[0].command[0]=/bin/sh" \
  --set "cronJobs[0].command[1]=-c" \
  --set "cronJobs[0].command[2]=echo hello" \
  --set podSecurityContext=null \
  --set securityContext=null \
  --set resources=null \
  2>/dev/null | grep "kind: CronJob" | wc -l
```

Expected: `1`

**3b — CronJob with `enabled: false` is skipped; `enabled: true` still renders:**

```bash
helm template test-release drunk-app \
  --set nameOverride=cj-test \
  --set global.image=nginx \
  --set global.tag=latest \
  --set "cronJobs[0].name=daily-job" \
  --set "cronJobs[0].schedule=0 2 * * *" \
  --set "cronJobs[0].enabled=false" \
  --set "cronJobs[1].name=weekly-job" \
  --set "cronJobs[1].schedule=0 2 * * 0" \
  --set podSecurityContext=null \
  --set securityContext=null \
  --set resources=null \
  2>/dev/null | grep "kind: CronJob" | wc -l
```

Expected: `1` (only weekly-job renders)

```bash
helm template test-release drunk-app \
  --set nameOverride=cj-test \
  --set global.image=nginx \
  --set global.tag=latest \
  --set "cronJobs[0].name=daily-job" \
  --set "cronJobs[0].schedule=0 2 * * *" \
  --set "cronJobs[0].enabled=false" \
  --set "cronJobs[1].name=weekly-job" \
  --set "cronJobs[1].schedule=0 2 * * 0" \
  --set podSecurityContext=null \
  --set securityContext=null \
  --set resources=null \
  2>/dev/null | grep "name:.*daily" | wc -l
```

Expected: `0` (daily-job absent)

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
**`tests`:** `bash drunk-lib/verify.sh` (three golden diffs); plus targeted helm template invocations in Step 3.

### Context for the implementer

Same guard pattern as Task 6. Current loop opener in `_job.tpl` (lines 15–18):
```
{{- define "drunk-lib.jobs" -}}
{{- $root := . }}
{{- range .Values.jobs }}
---
```

The closing structure at the bottom is:
```
      {{- end }}
{{- end }}
{{- end }}
```
(Three `end` tags: innermost closes `secretProvider` volume block, middle closes `range`, outer closes `define`.)

- [ ] **Step 1: Replace lines 15–18 in `drunk-lib/templates/_job.tpl`**

Find:
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

Then find the three closing `{{- end }}` tags at the bottom:
```
      {{- end }}
{{- end }}
{{- end }}
```

Replace with four:
```
      {{- end }}
{{- end }}
{{- end }}
{{- end }}
```

No other content in `_job.tpl` changes.

- [ ] **Step 2: Run `bash drunk-lib/verify.sh` — must pass (all three golden diffs clean)**

```bash
cd drunk-lib && bash verify.sh
```

Expected: `All checks passed.`

None of the three machine-diffable golden renders contain Jobs (no `jobs` in `values.yaml`), so the diffs remain clean.

- [ ] **Step 3: Targeted checks**

**3a — Job with no `enabled` key renders normally:**

```bash
helm template test-release drunk-app \
  --set nameOverride=job-test \
  --set global.image=nginx \
  --set global.tag=latest \
  --set "jobs[0].name=migrate" \
  --set "jobs[0].command[0]=/bin/sh" \
  --set "jobs[0].command[1]=-c" \
  --set "jobs[0].command[2]=echo migrate" \
  --set podSecurityContext=null \
  --set securityContext=null \
  --set resources=null \
  2>/dev/null | grep "kind: Job" | wc -l
```

Expected: `1`

**3b — Job with `enabled: false` is skipped; other Job still renders:**

```bash
helm template test-release drunk-app \
  --set nameOverride=job-test \
  --set global.image=nginx \
  --set global.tag=latest \
  --set "jobs[0].name=migrate" \
  --set "jobs[0].enabled=false" \
  --set "jobs[1].name=seed" \
  --set "jobs[1].command[0]=/bin/sh" \
  --set "jobs[1].command[1]=-c" \
  --set "jobs[1].command[2]=echo seed" \
  --set podSecurityContext=null \
  --set securityContext=null \
  --set resources=null \
  2>/dev/null | grep "kind: Job" | wc -l
```

Expected: `1` (only seed renders)

```bash
helm template test-release drunk-app \
  --set nameOverride=job-test \
  --set global.image=nginx \
  --set global.tag=latest \
  --set "jobs[0].name=migrate" \
  --set "jobs[0].enabled=false" \
  --set "jobs[1].name=seed" \
  --set "jobs[1].command[0]=echo" \
  --set podSecurityContext=null \
  --set securityContext=null \
  --set resources=null \
  2>/dev/null | grep "job-test-migrate"
```

Expected: no output (migrate job absent from render)

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
**`tests`:** `bash drunk-lib/verify.sh` (three golden diffs — values.yaml library defaults do not affect consumer renders).

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
#   Same shape as deployment.ports: map of portName → containerPort.
#   When absent, drunk-lib.service falls back to deployment.ports.
#   drunk.utils.ingressPort also prefers this key over deployment.ports.
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
# autoscaling.targetKind — scaleTargetRef.kind in the HPA (emitted quoted).
#   Default: "Deployment". Set to "StatefulSet" for StatefulSet workloads.
#   Example:
#     autoscaling:
#       targetKind: StatefulSet
#
# autoscaling.targetApiVersion — scaleTargetRef.apiVersion in the HPA (emitted quoted).
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
**`tests`:** `bash drunk-lib/verify.sh` (three golden diffs — README does not affect render output).

### Context for the implementer

Read the current `drunk-lib/README.md` first to understand existing structure. You will **append** a new top-level section `## Standalone Template Usage` and a `## Non-Breaking Guarantee` section at the end of the file. Do not restructure or remove any existing content.

- [ ] **Step 1: Read `drunk-lib/README.md` to understand current structure**

```bash
wc -l drunk-lib/README.md
head -30 drunk-lib/README.md
```

- [ ] **Step 2: Append the Standalone Usage and Non-Breaking Guarantee sections to `drunk-lib/README.md`**

Add the following content at the **end** of the file (after the last existing line):

```markdown

---

## Standalone Template Usage

`drunk-lib` partials can be included individually — you are not required to use `drunk-lib.all`. A chart that only needs a ConfigMap and a Service can call exactly those two partials.

### Minimum values per template

| Template | Required keys | Optional keys added by this feature |
|---|---|---|
| `drunk-lib.configMap` | `configMap` (map) | — |
| `drunk-lib.secrets` | `secrets` (map) | — |
| `drunk-lib.service` | `service.ports` OR `deployment.ports` | `service.enabled` (bool, default true), `service.type` (string, default ClusterIP) |
| `drunk-lib.ingress` | `ingress.enabled: true`, `ingress.hosts` | Port resolved via `drunk.utils.ingressPort`: prefers `service.ports` → `deployment.ports` → 8080 |
| `drunk-lib.hpa` | `autoscaling.enabled: true`, `autoscaling.minReplicas`, `autoscaling.maxReplicas` | `autoscaling.targetKind` (default "Deployment"), `autoscaling.targetApiVersion` (default "apps/v1") |
| `drunk-lib.cronJobs` | `cronJobs` array with `name` and `schedule` | `cronJobs[].enabled` (bool, default true — set false to skip that entry) |
| `drunk-lib.jobs` | `jobs` array with `name` | `jobs[].enabled` (bool, default true — set false to skip that entry) |
| `drunk-lib.deployment` | `deployment.enabled: true`, `global.image`, `global.tag` | all other `deployment.*` keys |
| `drunk-lib.statefulset` | `statefulset.enabled: true`, `global.image`, `global.tag` | all other `statefulset.*` keys |
| `drunk-lib.serviceAccount` | `serviceAccount.enabled: true` | `serviceAccount.name` |
| `drunk-lib.gateway` | `gateway.enabled: true` | all `gateway.*` keys |
| `drunk-lib.httpRoute` | `httpRoute.enabled: true` | all `httpRoute.*` keys |
| `drunk-lib.networkPolicies` | `networkPolicies` array | `networkPolicy` (legacy single-policy) |
| `drunk-lib.volumes` | `volumes` map | — |
| `drunk-lib.secretProvider` | `secretProvider.enabled: true` | all `secretProvider.*` keys |
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

### Example — suppress Service in existing consumer

```yaml
# Add to your existing values — no other changes needed
service:
  enabled: false
```

---

## Non-Breaking Guarantee

Every `drunk-lib` change is regression-tested via golden-file snapshots in `drunk-lib/tests/golden/`. `bash drunk-lib/verify.sh` automatically re-renders and diffs the following stable renders after each packaging:

| Golden file | Render scenario |
|---|---|
| `drunk-app-default.yaml` | `drunk-app` with default `values.yaml` |
| `drunk-app-svc-disabled.yaml` | `drunk-app` with `service.enabled: false` |
| `drunk-app-secretprovider.yaml` | `drunk-app` with `secretProvider.enabled: true` |

`drunk-app-example.yaml` is also committed for human PR review but is **excluded from machine diff** because `_job.tpl` generates Job names with a random suffix (`randAlphaNum 5`) that changes on every render.

If you intentionally change consumer output (e.g. a format fix), update all golden files:

```bash
bash drunk-lib/snapshot.sh   # re-captures all golden files from repo root
bash drunk-lib/verify.sh     # must pass after update
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
            │               └─► (feeds impl:be-values-documentation)
            ├─► impl:be-hpa-targetkind
            │       └─► (feeds impl:be-values-documentation)
            ├─► impl:be-cronjob-enabled-flag
            │       └─► (feeds impl:be-values-documentation)
            └─► impl:be-job-enabled-flag
                    └─► (feeds impl:be-values-documentation)

impl:be-values-documentation (depends on: service-standalone, hpa-targetkind,
                               cronjob-enabled-flag, job-enabled-flag)
    └─► impl:be-readme-update
```

Tasks 5, 6, 7 (`hpa-targetkind`, `cronjob-enabled-flag`, `job-enabled-flag`) are independent of each other and can be executed in parallel after Task 2 completes. Task 4 (`ingressport-helper`) depends on Task 3 (`service-standalone`) because it must stay consistent with the port-resolution logic introduced there. Task 8 (`values-documentation`) depends on all four template tasks. Task 9 (`readme-update`) depends on Task 8.

---

## Revision Log

**Round 1 (2026-05-14) — addresses ARCH and SEC gate findings:**

- **CRITICAL-1 fixed (Tasks 3, 4):** Both `_service.tpl` and `drunk.utils.ingressPort` rewrites now initialise `$ports` as `{{- $ports := dict -}}` (an empty map), never as `""`. Added explicit "Critical type note" callouts in both task context blocks so the implementer cannot paste the wrong initialiser. Render condition uses `gt (len $ports) 0` which is correct for a map.

- **HIGH-1 fixed (Task 1):** Added an explicit per-consumer scope table in the Task 1 context block listing all six design-doc consumers and the exact reason each is or is not captured in `snapshot.sh`.

- **MEDIUM-3 fixed (Tasks 1, 2):** The `values.example.yaml` render is captured by `snapshot.sh` for human review but explicitly excluded from the machine-diff list in `verify.sh`. Task 2 documents why in a comment inside `verify.sh` itself: `_job.tpl` uses `randAlphaNum 5` → non-deterministic Job names. Three stable renders (`drunk-app-default`, `drunk-app-svc-disabled`, `drunk-app-secretprovider`) replace the previous two-render set.

- **MEDIUM-A (SEC) fixed (Tasks 1, 2):** Two new machine-diffable renders added: `drunk-app-svc-disabled.yaml` (`service.enabled: false`) and `drunk-app-secretprovider.yaml` (`secretProvider.enabled: true`). Both are captured by `snapshot.sh` and machine-diffed by `verify.sh`.

- **MEDIUM-B (SEC) fixed (Task 5):** `autoscaling.targetKind` and `autoscaling.targetApiVersion` are emitted with `| quote` in `_hpa.tpl`. Task 5 notes that this causes quoted strings in the HPA YAML and instructs the implementer to check whether a golden update is needed after writing the template (it will not be needed because the stable renders don't enable autoscaling).
