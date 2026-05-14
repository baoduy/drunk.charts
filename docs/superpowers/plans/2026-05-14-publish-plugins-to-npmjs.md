# Publish Plugins to npmjs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a new `npm-publish.yaml` GitHub Actions workflow plus root `package.json` and `LICENSE` so the `plugins/` bundle publishes to npmjs as `@drunkcoding/drunk-charts` on every push to `main`, coexisting with the existing Helm chart OCI publish flow.

**Architecture:** Mirror the reference `baoduy/agents-and-skills/npm-publish.yaml` adapted for drunk.charts. Single-job workflow: checkout → semantic-version compute → setup-node → rewrite `package.json` version → sync `marketplace.json` + `plugins/*/.claude-plugin/plugin.json` versions → commit with rebase-retry → `npm publish --access public`. No GitHub Release creation — `publish-oci.yml` owns that.

**Tech Stack:** GitHub Actions, `actions/checkout@v4`, `actions/setup-node@v4`, `paulhatch/semantic-version@v5.4.0`, Node.js 20, npm, `jq`/`node` for JSON edits.

**Spec:** [docs/superpowers/specs/2026-05-14-publish-plugins-to-npmjs-design.md](../specs/2026-05-14-publish-plugins-to-npmjs-design.md)

---

## Task 1: Add root `LICENSE` (MIT)

**Files:**
- Create: `LICENSE`

- [ ] **Step 1: Write MIT LICENSE file**

```
MIT License

Copyright (c) 2026 Steven Hoang

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 2: Verify file present**

Run: `test -f LICENSE && head -1 LICENSE`
Expected: `MIT License`

- [ ] **Step 3: Commit**

```bash
git add LICENSE
git commit -m "chore: add MIT LICENSE file"
```

---

## Task 2: Add root `package.json`

**Files:**
- Create: `package.json`

- [ ] **Step 1: Write `package.json` at repo root**

```json
{
  "name": "@drunkcoding/drunk-charts",
  "version": "0.0.0",
  "description": "Claude Code plugins for drunk.charts — AI assistants for configuring Helm chart deployments (drunk-app, drunk-lib).",
  "keywords": [
    "claude-code",
    "claude-skills",
    "claude-plugins",
    "agent-skills",
    "helm",
    "kubernetes",
    "drunk-charts"
  ],
  "author": "Steven Hoang",
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "https://github.com/baoduy/drunk.charts.git"
  },
  "homepage": "https://github.com/baoduy/drunk.charts#readme",
  "bugs": {
    "url": "https://github.com/baoduy/drunk.charts/issues"
  },
  "files": [
    "plugins/**",
    ".claude-plugin/marketplace.json",
    "README.md",
    "LICENSE"
  ],
  "private": false,
  "publishConfig": {
    "access": "public"
  }
}
```

- [ ] **Step 2: Validate JSON syntactically**

Run: `node -e "JSON.parse(require('fs').readFileSync('package.json','utf8'))" && echo OK`
Expected: `OK`

- [ ] **Step 3: Validate publish file list with `npm pack --dry-run`**

Run: `npm pack --dry-run 2>&1 | grep -E '(plugins/|marketplace.json|LICENSE|README.md)' | head`
Expected: includes lines for `plugins/drunk-app/.claude-plugin/plugin.json`, `plugins/drunk-lib/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `LICENSE`, `README.md`. Must NOT include `drunk-lib/Chart.yaml` or any Helm chart files.

- [ ] **Step 4: Commit**

```bash
git add package.json
git commit -m "chore: add root package.json for @drunkcoding/drunk-charts"
```

---

## Task 3: Update `.gitignore` for `node_modules/`

**Files:**
- Modify: `.gitignore`

- [ ] **Step 1: Check current `.gitignore`**

Run: `grep -F 'node_modules' .gitignore || echo MISSING`
Expected: either a line containing `node_modules` (skip remaining steps), or `MISSING`.

- [ ] **Step 2: Append `node_modules/` if missing**

If Step 1 printed `MISSING`, append the line. Otherwise skip.

```bash
echo 'node_modules/' >> .gitignore
```

- [ ] **Step 3: Verify**

Run: `grep -F 'node_modules' .gitignore`
Expected: `node_modules/`

- [ ] **Step 4: Commit (only if file changed)**

```bash
git diff --quiet .gitignore || { git add .gitignore && git commit -m "chore: ignore node_modules/"; }
```

---

## Task 4: Add `.github/workflows/npm-publish.yaml`

**Files:**
- Create: `.github/workflows/npm-publish.yaml`

- [ ] **Step 1: Write workflow file**

```yaml
name: npm-publish

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      release:
        description: "Publish to npm"
        required: false
        default: "true"

concurrency:
  group: npm-publish-${{ github.ref }}
  cancel-in-progress: false

jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      packages: write
      id-token: write

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
          fetch-tags: true

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

      - name: Print the version
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

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          registry-url: "https://registry.npmjs.org/"

      - name: Update version in package.json
        if: steps.flag.outputs.enable == 'true'
        run: npm version "${NEXT_VERSION}" --no-git-tag-version --allow-same-version

      - name: Sync plugin manifest versions
        if: steps.flag.outputs.enable == 'true'
        run: |
          set -euo pipefail
          if [ -f .claude-plugin/marketplace.json ]; then
            node -e "const fs=require('fs');const p='.claude-plugin/marketplace.json';const j=JSON.parse(fs.readFileSync(p,'utf8'));if(Array.isArray(j.plugins)){j.plugins.forEach(pl=>{pl.version=process.env.NEXT_VERSION});}fs.writeFileSync(p,JSON.stringify(j,null,2)+'\n');"
          fi
          for f in plugins/*/.claude-plugin/plugin.json; do
            [ -f "$f" ] || continue
            node -e "const fs=require('fs');const j=JSON.parse(fs.readFileSync('$f','utf8'));j.version=process.env.NEXT_VERSION;fs.writeFileSync('$f',JSON.stringify(j,null,2)+'\n');"
          done

      - name: Commit version bump
        if: steps.flag.outputs.enable == 'true'
        env:
          NEXT_VERSION: ${{ env.NEXT_VERSION }}
        run: |
          set -euo pipefail
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

          git add package.json .claude-plugin/marketplace.json plugins/*/.claude-plugin/plugin.json

          if git diff --cached --quiet; then
            echo "No version diff to commit"
            exit 0
          fi

          git commit -m "chore(release): npm v${NEXT_VERSION} [skip ci]"

          # Tolerate concurrent push from publish-oci.yml on the same SHA.
          for i in 1 2 3; do
            if git push origin HEAD:main; then
              exit 0
            fi
            git pull --rebase origin main
          done
          echo "::error::Failed to push version bump after 3 rebase attempts"
          exit 1

      - name: Publish to npm
        if: steps.flag.outputs.enable == 'true'
        run: npm publish --access public --no-git-checks
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
```

- [ ] **Step 2: Validate YAML parses**

Run: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/npm-publish.yaml'))" && echo OK`
Expected: `OK`

- [ ] **Step 3: Lint with `actionlint` if available**

Run: `command -v actionlint >/dev/null && actionlint .github/workflows/npm-publish.yaml || echo "actionlint not installed (skipping)"`
Expected: either no output (clean) or the skip message. If actionlint reports errors, fix them inline.

- [ ] **Step 4: Smoke-test the inline Node JSON sync logic locally**

Run:
```bash
NEXT_VERSION=9.9.9-test node -e "const fs=require('fs');const p='.claude-plugin/marketplace.json';const j=JSON.parse(fs.readFileSync(p,'utf8'));if(Array.isArray(j.plugins)){j.plugins.forEach(pl=>{pl.version=process.env.NEXT_VERSION});}console.log(JSON.stringify(j.plugins.map(p=>({n:p.name,v:p.version})),null,2));"
```
Expected: prints each plugin with `"v": "9.9.9-test"`. No filesystem mutation (used `console.log` instead of `writeFileSync` for the smoke test).

- [ ] **Step 5: Smoke-test the plugin.json sync**

Run:
```bash
NEXT_VERSION=9.9.9-test bash -c 'for f in plugins/*/.claude-plugin/plugin.json; do
  [ -f "$f" ] || continue
  node -e "const fs=require(\"fs\");const j=JSON.parse(fs.readFileSync(\"$f\",\"utf8\"));j.version=process.env.NEXT_VERSION;console.log(\"$f\",\"->\",j.version);"
done'
```
Expected: one line per plugin, each ending `-> 9.9.9-test`.

- [ ] **Step 6: Commit**

```bash
git add .github/workflows/npm-publish.yaml
git commit -m "ci: add npm-publish workflow for @drunkcoding/drunk-charts"
```

---

## Task 5: Update `validate-plugins.yml` path filter

**Files:**
- Modify: `.github/workflows/validate-plugins.yml`

- [ ] **Step 1: Inspect current paths block**

Run: `sed -n '/^on:/,/^jobs:/p' .github/workflows/validate-plugins.yml`
Expected: shows `paths:` lists under `pull_request:` and `push:` triggers.

- [ ] **Step 2: Add `package.json` and `npm-publish.yaml` to PR `paths:`**

In the `pull_request:` `paths:` block of `.github/workflows/validate-plugins.yml`, append two entries:

```yaml
      - 'package.json'
      - '.github/workflows/npm-publish.yaml'
```

The full PR trigger after the change reads:

```yaml
on:
  pull_request:
    paths:
      - 'plugins/**'
      - '.claude-plugin/**'
      - 'scripts/new-plugin.sh'
      - '.github/workflows/validate-plugins.yml'
      - 'package.json'
      - '.github/workflows/npm-publish.yaml'
  push:
    branches: [main, dev]
    paths:
      - 'plugins/**'
      - '.claude-plugin/**'
      - 'scripts/new-plugin.sh'
```

Note: only the `pull_request:` `paths:` block gains new entries. The `push:` block is unchanged (publish is the validator on push).

- [ ] **Step 3: Validate YAML parses**

Run: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/validate-plugins.yml'))" && echo OK`
Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/validate-plugins.yml
git commit -m "ci(validate-plugins): cover package.json and npm-publish workflow"
```

---

## Task 6: End-to-end local verification

**Files:**
- (read-only verification — no edits)

- [ ] **Step 1: `npm pack --dry-run` produces tarball preview**

Run: `npm pack --dry-run 2>&1 | tee /tmp/npm-pack.txt`
Expected: lists `plugins/drunk-app/.claude-plugin/plugin.json`, `plugins/drunk-lib/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `LICENSE`, `README.md`, `package.json`. Total file count should be ~10–30 (plugins/skills + manifests). Should NOT include `drunk-app/`, `drunk-lib/`, `drunk-nginx-gateway/`, `drunk-traefik-gateway/`, `drunk-squid-basic-auth/`, `.github/`, `docs/`, `scripts/`.

- [ ] **Step 2: Confirm absence of Helm chart files in pack output**

Run: `grep -Ec '(Chart\.yaml|templates/|values\.yaml)' /tmp/npm-pack.txt || echo "0 matches OK"`
Expected: `0 matches OK` (or `0`).

- [ ] **Step 3: Validate `marketplace.json` still parses after design (no destructive edits yet)**

Run: `jq -e '.plugins | length' .claude-plugin/marketplace.json`
Expected: `2`

- [ ] **Step 4: Validate each `plugins/*/.claude-plugin/plugin.json` still parses**

Run:
```bash
for f in plugins/*/.claude-plugin/plugin.json; do
  jq -e '.name and .version and .description' "$f" >/dev/null \
    && echo "$f OK" \
    || { echo "$f FAILED" >&2; exit 1; }
done
```
Expected: one `OK` line per plugin.

- [ ] **Step 5: Confirm both workflows parse together**

Run:
```bash
python3 -c "
import yaml, glob
for f in glob.glob('.github/workflows/*.y*ml'):
    yaml.safe_load(open(f))
    print(f, 'OK')
"
```
Expected: `OK` per workflow file.

- [ ] **Step 6: Final commit checkpoint (no-op expected)**

Run: `git status --short`
Expected: clean working tree (all edits already committed in Tasks 1–5).

---

## Post-implementation operational checklist (manual, outside this plan's scope)

These items must happen in the GitHub UI / npm UI **before the first `main` push** that triggers `npm-publish.yaml`. They are not scripted tasks:

1. Create or confirm npm org `@drunkcoding` exists and the publishing user has the `developer` (or higher) role.
2. Generate a `Automation` npm token scoped to publish for `@drunkcoding`.
3. Add the token to the GitHub repo as the secret `NPM_TOKEN` (Settings → Secrets and variables → Actions → New repository secret).
4. Confirm the repo `Settings → Actions → General → Workflow permissions` is set to `Read and write permissions` (needed for the version-bump commit push).

If any of these are missed, the workflow's `Publish to npm` or `Commit version bump` step fails with a clear permissions/auth error — non-destructive, safe to re-run after fixing.

---

## Self-Review

### Spec coverage check

| Spec section | Covered by |
|---|---|
| §1 Root `package.json` | Task 2 |
| §2 Root `LICENSE` | Task 1 |
| §3 `npm-publish.yaml` workflow body | Task 4 |
| §4 Coexistence with `publish-oci.yml` (distinct commit msg, rebase-retry, no Release) | Task 4 (commit + rebase-retry block; Release step omitted from workflow body) |
| §5 `NPM_TOKEN` secret | Post-implementation operational checklist (manual) |
| §6 Validate workflow path-filter update | Task 5 |
| File table: `.gitignore` `node_modules/` | Task 3 |
| Acceptance #1 (push → version compute → sync → commit → publish) | Task 4 (workflow body) |
| Acceptance #2 (`npx --yes @drunkcoding/drunk-charts` installs plugins) | Task 2 (files whitelist) + Task 6 (pack dry-run verifies contents) |
| Acceptance #3 (`publish-oci.yml` unchanged) | Confirmed by absence of edits to `publish-oci.yml` across all tasks |
| Acceptance #4 (versions tracked after run) | Task 4 sync step |
| Acceptance #5 (validate runs on `package.json` PRs) | Task 5 |
| Acceptance #6 (clear failure on missing `NPM_TOKEN`) | Inherited from `npm publish` default behavior; no extra step required |

No gaps.

### Placeholder scan

No `TBD`, `TODO`, `implement later`, or unspecified "add appropriate X" steps. All code blocks are concrete.

### Type / identifier consistency

- `NEXT_VERSION` env var: same name across Tasks 4 + 6.
- `@drunkcoding/drunk-charts` package name: same in Task 2 (package.json) and Task 6 (pack verification).
- `paulhatch/semantic-version@v5.4.0`: same pin as existing `publish-oci.yml`.
- Workflow file path `.github/workflows/npm-publish.yaml` (lowercase `.yaml`, matching reference repo's extension): consistent across Task 4 (created) and Task 5 (path filter entry).

Clean.
