# Publish Claude Code Plugins to npmjs — Design

## Goal

Publish the plugins under `plugins/` (currently `drunk-app`, `drunk-lib`) as a single npm package on the public npmjs registry so users can install them via `npx`. Mirror the publish flow used by [`baoduy/agents-and-skills`](https://github.com/baoduy/agents-and-skills), adapted for `drunk.charts`.

The npm package complements (does not replace) the existing GHCR OCI Helm chart publish flow. Helm charts continue to publish via `publish-oci.yml`. The new `npm-publish.yaml` publishes the Claude Code plugin bundle.

## Non-Goals

- Publishing each plugin as its own npm package (single bundled package, like the reference repo).
- Replacing or modifying the existing `publish-oci.yml` Helm chart publish flow.
- Publishing the Helm charts themselves to npm (charts ship via GHCR OCI only).
- Build steps / TypeScript compilation. Plugins are pure JSON + Markdown — no transpilation.

## Reference

- Package manifest: <https://github.com/baoduy/agents-and-skills/blob/main/package.json>
- Workflow: <https://github.com/baoduy/agents-and-skills/blob/main/.github/workflows/npm-publish.yaml>

Both files were fetched verbatim and used as the structural template for the design below.

## Current State

- Repo root has **no** `package.json`.
- Plugins live under `plugins/<name>/.claude-plugin/plugin.json`.
- Marketplace manifest at `.claude-plugin/marketplace.json` lists plugins with `name`, `version`, `source`, `description`.
- `version: "1.0.0"` is hard-coded in every plugin.json and in each marketplace entry.
- Existing workflows:
  - `.github/workflows/publish-oci.yml` — push to `main` + dispatch, owns Helm chart publish, version commit, and GitHub Release.
  - `.github/workflows/validate-plugins.yml` — PR + push to `main`/`dev`, validates marketplace + plugin.json shapes.
- No `LICENSE` file at root (plugin.json files declare MIT).

## Design

### 1. Root `package.json`

New file at repo root:

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

Notes:
- Scoped name `@drunkcoding/drunk-charts` matches the owner scope used by the reference repo (`@drunkcoding/agents-and-skills`).
- Version `0.0.0` is a stub. The workflow rewrites it before publish via `npm version --no-git-tag-version --allow-same-version`. The actual published version is computed by `paulhatch/semantic-version@v5.4.0` from git tags.
- `files` whitelist ships only the plugin bundle, marketplace manifest, README, and LICENSE. No source code, no CI files, no Helm charts.

### 2. Root `LICENSE`

Add `MIT License` file at repo root. Plugin and marketplace metadata already declare MIT; root file makes this explicit and is referenced by `package.json.files`.

### 3. New workflow `.github/workflows/npm-publish.yaml`

```yaml
name: npm-publish

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      release:
        description: "Publish to npm and create a GitHub release"
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
          echo "::error::Failed to push version bump after 3 rebase attempts" && exit 1

      - name: Publish to npm
        if: steps.flag.outputs.enable == 'true'
        run: npm publish --access public --no-git-checks
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
```

### 4. Coexistence with `publish-oci.yml`

Both `publish-oci.yml` and `npm-publish.yaml` fire on `push: branches: [main]` and both compute the same `NEXT_VERSION` from `paulhatch/semantic-version@v5.4.0`. Three real concerns + how the design addresses them:

1. **Duplicate GitHub Release** — `publish-oci.yml` already creates the `v${NEXT_VERSION}` release. `npm-publish.yaml` **omits** the `Create GitHub Release` step from the reference workflow. The Helm publish workflow remains the sole owner of the GitHub Release.
2. **Concurrent version-bump commits** — both workflows want to commit a version bump and `git push` to `main`. They race. Resolution: `npm-publish.yaml` uses a distinct commit message (`chore(release): npm v${NEXT_VERSION} [skip ci]`) and tolerates a non-fast-forward push by retrying once after `git pull --rebase origin main`. (Implementation detail captured in the plan; both commits are `[skip ci]` so neither triggers a workflow loop.)
3. **Tag conflict** — only `publish-oci.yml` creates tags. `npm-publish.yaml` does **not** tag (`npm version --no-git-tag-version`), so no conflict.

### 5. Repo Secrets

Required:
- `NPM_TOKEN` — npm publish token with `publish` scope on `@drunkcoding` org. Must be configured before first run. Workflow fails fast at `Publish to npm` step if absent.

Already present:
- `GITHUB_TOKEN` — auto-provided.

### 6. Validation Hooks

Update `.github/workflows/validate-plugins.yml` paths to also trigger on `package.json` changes, so PRs that touch the manifest are validated:

```yaml
on:
  pull_request:
    paths:
      - 'plugins/**'
      - '.claude-plugin/**'
      - 'scripts/new-plugin.sh'
      - '.github/workflows/validate-plugins.yml'
      - 'package.json'                       # added
      - '.github/workflows/npm-publish.yaml' # added
```

(The validate workflow itself doesn't need new validation logic — its existing checks on marketplace.json + plugin.json shape are sufficient.)

## File-by-file Changes

| File | Action |
|---|---|
| `package.json` | **Create** at repo root with the JSON shown in §1. |
| `LICENSE` | **Create** at repo root with MIT license text, copyright `2026 Steven Hoang`. |
| `.github/workflows/npm-publish.yaml` | **Create** with the YAML shown in §3. |
| `.github/workflows/validate-plugins.yml` | **Edit**: add `package.json` and `npm-publish.yaml` to PR path filter. |
| `.gitignore` | **Edit**: add `node_modules/` if not already present. |
| Plugin metadata files | **No change** at design time. The workflow rewrites them at publish time. |

## Acceptance Criteria

1. Push to `main` triggers `npm-publish.yaml`; it computes a version, syncs all plugin manifests, commits the bump (`[skip ci]`), and publishes `@drunkcoding/drunk-charts@<version>` to npmjs.
2. `npx --yes @drunkcoding/drunk-charts` (or equivalent install) installs the package and exposes `plugins/` + `.claude-plugin/marketplace.json` to the consumer.
3. `publish-oci.yml` continues to run unchanged and remains the sole creator of the GitHub Release for `v${NEXT_VERSION}`.
4. Plugin `version` fields in `plugin.json` and `marketplace.json` track the released semver after each successful run.
5. `validate-plugins.yml` runs on any PR that modifies `package.json` or `npm-publish.yaml`.
6. Workflow fails clearly if `NPM_TOKEN` is missing.

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Race between `npm-publish.yaml` and `publish-oci.yml` version-bump pushes | Rebase-and-retry on non-fast-forward in npm-publish commit step. Distinct commit messages so neither overwrites the other's intent. |
| First-run version is `0.0.x` (no `(MAJOR)` markers yet), but plugin.json files currently hard-code `1.0.0` | Plugin.json `version` is rewritten to `NEXT_VERSION` at publish time, then committed back. After first run, all manifests track the semver line started from existing `v0.0.x` tags. npm registry accepts any version on first publish of a new package name. |
| `NPM_TOKEN` unconfigured | Documented in §5. Workflow fails at publish step with a clear npm error. |
| Scope `@drunkcoding` doesn't exist or PAT lacks publish rights | Manual one-time setup outside this design's scope. First publish must succeed by `npm publish --access public` against a valid org. |
| Marketplace consumers depending on `version: "1.0.0"` literal | None known. Marketplace consumers read the value, not match it. |

## Out of Scope (Future Work)

- Per-plugin npm packages (would require nested `package.json` per plugin and matrix publish — explicitly avoided per reference repo's bundled approach).
- Provenance / sigstore attestation (`--provenance` flag).
- Pinning paulhatch action by SHA instead of `@v5.4.0`.
- Tag-based publish trigger (`on: release: published`) as alternative to push-to-main.
