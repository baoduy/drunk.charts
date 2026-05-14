# Publish All Helm Charts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend `.github/workflows/publish-oci.yml` to publish all 5 Helm charts (lib, app, 3 wrappers) to GHCR via a clean sequential OCI dependency chain, aligned with the reference `agents-and-skills/npm-publish.yaml` pattern.

**Architecture:** Single sequential job. Charts package + push in dependency order: `drunk-lib` → `drunk-app` (depends on lib) → `drunk-nginx-gateway`, `drunk-traefik-gateway`, `drunk-squid-basic-auth` (squid depends on app). Internal dep `repository:` fields in `Chart.yaml` change from `file://` / `https://` to `oci://ghcr.io/baoduy`. Workflow rewrites + commits `Chart.yaml` `version:` bumps to the repo before packaging, then creates a GitHub Release.

**Tech Stack:** GitHub Actions, Helm v3.17.3, `paulhatch/semantic-version@v5.4.0`, `softprops/action-gh-release@v2`, GHCR OCI registry, `yq` (Python) for YAML edits.

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `drunk-app/Chart.yaml` | Modify | Change `drunk-lib` dep `repository:` to OCI registry |
| `drunk-squid-basic-auth/Chart.yaml` | Modify | Change `drunk-app` dep `repository:` to OCI registry |
| `.github/workflows/publish-oci.yml` | Rewrite | New sequential pipeline with version sync, login, all 5 chart pushes, release |

No new files. No test files (Helm-only repo per CLAUDE.md `test_framework: none`).

---

## Task 1: Switch `drunk-app` dep to OCI registry

**Files:**
- Modify: `drunk-app/Chart.yaml`

- [ ] **Step 1: Edit `drunk-app/Chart.yaml`**

Replace the `dependencies` block. Current content (lines 11-14):

```yaml
dependencies:
  - name: drunk-lib
    version: 1.x.x
    #repository: "https://baoduy.github.io/drunk.charts/drunk-lib"
    repository: "file://../drunk-lib"
```

Replace with:

```yaml
dependencies:
  - name: drunk-lib
    version: 1.x.x
    repository: oci://ghcr.io/baoduy
```

- [ ] **Step 2: Lint chart**

Run from repo root:
```bash
helm lint drunk-app --quiet
```
Expected: no errors. May warn about missing dep tgz — that is fine (resolved at workflow time via OCI).

- [ ] **Step 3: Commit**

```bash
git add drunk-app/Chart.yaml
git commit -m "chore(drunk-app): switch drunk-lib dep to oci://ghcr.io/baoduy"
```

---

## Task 2: Switch `drunk-squid-basic-auth-proxy` `drunk-app` dep to OCI registry

**Files:**
- Modify: `drunk-squid-basic-auth/Chart.yaml`

- [ ] **Step 1: Edit `drunk-squid-basic-auth/Chart.yaml`**

Current `drunk-app` dep entry:
```yaml
  - name: drunk-app
    alias: proxy
    version: 1.x.x
    condition: proxy.enabled
    repository: "https://baoduy.github.io/drunk.charts/drunk-app"
```

Replace with:
```yaml
  - name: drunk-app
    alias: proxy
    version: 1.x.x
    condition: proxy.enabled
    repository: oci://ghcr.io/baoduy
```

Leave the `ingress-nginx` dep above it untouched.

- [ ] **Step 2: Lint chart**

```bash
helm lint drunk-squid-basic-auth --quiet
```
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add drunk-squid-basic-auth/Chart.yaml
git commit -m "chore(drunk-squid-basic-auth): switch drunk-app dep to oci://ghcr.io/baoduy"
```

---

## Task 3: Rewrite `.github/workflows/publish-oci.yml`

**Files:**
- Modify: `.github/workflows/publish-oci.yml`

This is a full rewrite. Single commit covers the new workflow.

- [ ] **Step 1: Replace entire workflow file**

Write the following content to `.github/workflows/publish-oci.yml`:

```yaml
name: Publish Helm Charts as OCI

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      release:
        description: "Publish to GHCR and create a GitHub release"
        required: false
        default: "true"

concurrency:
  group: publish-oci-${{ github.ref }}
  cancel-in-progress: false

permissions:
  contents: write
  packages: write
  id-token: write

jobs:
  publish:
    name: Build and Publish Helm Charts to GHCR
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
          fetch-tags: true

      - name: Set up Helm
        uses: azure/setup-helm@v4
        with:
          version: v3.17.3

      - name: Calculate version
        id: version
        uses: paulhatch/semantic-version@v5.4.0
        with:
          tag_prefix: "v"
          major_pattern: "(MAJOR)"
          minor_pattern: "(MINOR)"
          version_format: "${major}.${minor}.${patch}"
          bump_each_commit: false
          search_commit_body: false

      - name: Set NEXT_VERSION
        run: echo "NEXT_VERSION=${{ steps.version.outputs.version }}" >> "$GITHUB_ENV"

      - name: Print version
        run: echo "Next version is v${NEXT_VERSION}"

      - name: Determine release flag
        id: flag
        run: |
          if [ "${{ github.event_name }}" = "workflow_dispatch" ]; then
            echo "enable=${{ github.event.inputs.release }}" >> "$GITHUB_OUTPUT"
          elif [ "${{ github.event_name }}" = "push" ] && [ "${{ github.ref }}" = "refs/heads/main" ]; then
            echo "enable=true" >> "$GITHUB_OUTPUT"
          else
            echo "enable=false" >> "$GITHUB_OUTPUT"
          fi

      - name: Sync Chart.yaml versions
        if: steps.flag.outputs.enable == 'true'
        run: |
          set -euo pipefail
          for d in drunk-lib drunk-app drunk-nginx-gateway drunk-traefik-gateway drunk-squid-basic-auth; do
            f="$d/Chart.yaml"
            python3 -c "
          import sys, re
          p = '$f'
          s = open(p).read()
          s2 = re.sub(r'^version:.*$', 'version: ${NEXT_VERSION}', s, count=1, flags=re.M)
          open(p, 'w').write(s2)
          "
            echo "synced $f"
          done

      - name: Commit version bump
        if: steps.flag.outputs.enable == 'true'
        env:
          NEXT_VERSION: ${{ env.NEXT_VERSION }}
        run: |
          set -euo pipefail
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          git add drunk-lib/Chart.yaml drunk-app/Chart.yaml drunk-nginx-gateway/Chart.yaml drunk-traefik-gateway/Chart.yaml drunk-squid-basic-auth/Chart.yaml
          if git diff --cached --quiet; then
            echo "No version diff to commit"
            exit 0
          fi
          git commit -m "chore(release): v${NEXT_VERSION} [skip ci]"
          git push origin HEAD:main

      - name: Log in to GitHub Container Registry
        if: steps.flag.outputs.enable == 'true'
        run: |
          echo "${{ secrets.GITHUB_TOKEN }}" | helm registry login ghcr.io \
            --username ${{ github.actor }} \
            --password-stdin

      - name: Package + push drunk-lib
        if: steps.flag.outputs.enable == 'true'
        working-directory: drunk-lib
        run: |
          helm package . --version "${NEXT_VERSION}" --destination /tmp/charts
          helm push "/tmp/charts/drunk-lib-${NEXT_VERSION}.tgz" "oci://ghcr.io/${{ github.repository_owner }}"

      - name: Package + push drunk-app
        if: steps.flag.outputs.enable == 'true'
        working-directory: drunk-app
        run: |
          helm dependency update .
          helm package . --version "${NEXT_VERSION}" --destination /tmp/charts
          helm push "/tmp/charts/drunk-app-${NEXT_VERSION}.tgz" "oci://ghcr.io/${{ github.repository_owner }}"

      - name: Package + push drunk-nginx-gateway
        if: steps.flag.outputs.enable == 'true'
        working-directory: drunk-nginx-gateway
        run: |
          helm dependency update .
          helm package . --version "${NEXT_VERSION}" --destination /tmp/charts
          helm push "/tmp/charts/drunk-nginx-gateway-${NEXT_VERSION}.tgz" "oci://ghcr.io/${{ github.repository_owner }}"

      - name: Package + push drunk-traefik-gateway
        if: steps.flag.outputs.enable == 'true'
        working-directory: drunk-traefik-gateway
        run: |
          helm dependency update .
          helm package . --version "${NEXT_VERSION}" --destination /tmp/charts
          helm push "/tmp/charts/drunk-k8s-gateway-${NEXT_VERSION}.tgz" "oci://ghcr.io/${{ github.repository_owner }}"

      - name: Package + push drunk-squid-basic-auth
        if: steps.flag.outputs.enable == 'true'
        working-directory: drunk-squid-basic-auth
        run: |
          helm dependency update .
          helm package . --version "${NEXT_VERSION}" --destination /tmp/charts
          helm push "/tmp/charts/drunk-squid-basic-auth-proxy-${NEXT_VERSION}.tgz" "oci://ghcr.io/${{ github.repository_owner }}"

      - name: Log out from GHCR
        if: always()
        run: helm registry logout ghcr.io

      - name: Create GitHub Release
        if: steps.flag.outputs.enable == 'true'
        uses: softprops/action-gh-release@v2
        with:
          generate_release_notes: true
          make_latest: true
          tag_name: v${{ env.NEXT_VERSION }}
          name: Release v${{ env.NEXT_VERSION }}
          draft: false
          prerelease: false
        env:
          GITHUB_TOKEN: ${{ github.token }}
```

Notes for the implementer:
- Chart names in `.tgz` filenames differ from directory names for two charts:
  - `drunk-traefik-gateway/` → `drunk-k8s-gateway-${VERSION}.tgz`
  - `drunk-squid-basic-auth/` → `drunk-squid-basic-auth-proxy-${VERSION}.tgz`
- `helm dependency update` is used (not `helm dependency build`) because `Chart.lock` will not exist for OCI deps on a fresh checkout — `update` resolves and writes the lock.

- [ ] **Step 2: YAML syntax check**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/publish-oci.yml'))" && echo OK
```
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/publish-oci.yml
git commit -m "ci(publish-oci): publish all 5 charts via oci dep chain"
```

---

## Task 4: Local verification of chart packaging

The local `drunk-lib/verify.sh` only covers `drunk-lib`. We need to confirm the OCI-dep charts (`drunk-app`, `drunk-squid-basic-auth`) still lint and template after the `Chart.yaml` dep `repository:` switch — even though dependency resolution will require GHCR auth at workflow time.

**Files:**
- Read-only verification.

- [ ] **Step 1: Run drunk-lib verify**

```bash
bash drunk-lib/verify.sh
```
Expected: passes (lib chart unchanged structurally).

- [ ] **Step 2: Lint all charts**

```bash
helm lint drunk-lib drunk-app drunk-nginx-gateway drunk-traefik-gateway drunk-squid-basic-auth
```
Expected: each prints `[INFO] Chart.yaml: icon is recommended` style notes, all `1 chart(s) linted, 0 chart(s) failed`.

Note: `drunk-app` and `drunk-squid-basic-auth` may emit `WARNING` about missing dep tgz under `charts/`. That is acceptable — deps now resolve from GHCR at CI time, not from local `charts/` cache.

- [ ] **Step 3: Verify YAML parse of all 5 Chart.yaml files**

```bash
for f in drunk-lib/Chart.yaml drunk-app/Chart.yaml drunk-nginx-gateway/Chart.yaml drunk-traefik-gateway/Chart.yaml drunk-squid-basic-auth/Chart.yaml; do
  python3 -c "import yaml,sys; yaml.safe_load(open('$f')); print('OK', '$f')"
done
```
Expected: 5 lines, each `OK <path>`.

- [ ] **Step 4: No commit needed (read-only checks)**

Skip.

---

## Self-Review

### Spec coverage check

| Spec section | Covered by |
|---|---|
| `drunk-app/Chart.yaml` dep switch | Task 1 |
| `drunk-squid-basic-auth/Chart.yaml` dep switch | Task 2 |
| Triggers (push + workflow_dispatch with input) | Task 3 |
| Concurrency group | Task 3 |
| Permissions (contents/packages/id-token) | Task 3 |
| Version calc via paulhatch/semantic-version@v5.4.0 | Task 3 |
| Release flag gating | Task 3 |
| Chart.yaml version sync | Task 3 |
| Commit version bump `[skip ci]` | Task 3 |
| GHCR login | Task 3 |
| Sequential package + push for 5 charts in dependency order | Task 3 |
| Logout always | Task 3 |
| GitHub Release `softprops/action-gh-release@v2` | Task 3 |
| `.tgz` naming using chart-name (not dir-name) for traefik + squid | Task 3 (filenames hardcoded correctly) |
| Local verification still works | Task 4 |

All spec sections covered.

### Placeholder scan

No TBDs, TODOs, "add error handling", or "similar to Task N" placeholders. Every code/command step has full content.

### Type / name consistency

- Chart names verified against `Chart.yaml` contents:
  - `drunk-lib/Chart.yaml`: `name: drunk-lib` → tgz `drunk-lib-X.Y.Z.tgz` ✓
  - `drunk-app/Chart.yaml`: `name: drunk-app` → tgz `drunk-app-X.Y.Z.tgz` ✓
  - `drunk-nginx-gateway/Chart.yaml`: `name: drunk-nginx-gateway` → tgz `drunk-nginx-gateway-X.Y.Z.tgz` ✓
  - `drunk-traefik-gateway/Chart.yaml`: `name: drunk-k8s-gateway` → tgz `drunk-k8s-gateway-X.Y.Z.tgz` ✓
  - `drunk-squid-basic-auth/Chart.yaml`: `name: drunk-squid-basic-auth-proxy` → tgz `drunk-squid-basic-auth-proxy-X.Y.Z.tgz` ✓
- Env var `NEXT_VERSION` consistently used in all package/push steps.
- Dep `name:` field unchanged (`drunk-lib`, `drunk-app`) so OCI registry lookups will request `oci://ghcr.io/baoduy/drunk-lib` and `oci://ghcr.io/baoduy/drunk-app` — matches what the lib + app push steps publish.
