# Publish All Helm Charts to GHCR — Design

**Date:** 2026-05-14
**Status:** Approved
**Owner:** steven.hoang@transwap.com

## Problem

`.github/workflows/publish-oci.yml` currently builds and pushes only `drunk-lib` and `drunk-app` to `ghcr.io/baoduy`. Three additional charts in the repo (`drunk-nginx-gateway`, `drunk-traefik-gateway`, `drunk-squid-basic-auth`) are not published. Internal chart dependencies use mixed resolution strategies (`file://` for `drunk-app → drunk-lib`; `https://baoduy.github.io/...` for `drunk-squid-basic-auth-proxy → drunk-app`), which is inconsistent and brittle.

Goal: publish all 5 charts on every `main` push, with a clean sequential pipeline that resolves internal dependencies via the OCI registry the charts are also published to.

## Scope

In scope (5 charts with `Chart.yaml`):

| Directory | Chart name (`.tgz`) | Internal deps | External deps |
|---|---|---|---|
| `drunk-lib/` | `drunk-lib` | — | — |
| `drunk-app/` | `drunk-app` | `drunk-lib` | — |
| `drunk-nginx-gateway/` | `drunk-nginx-gateway` | — | `cert-manager`, `nginx-gateway-fabric` |
| `drunk-traefik-gateway/` | `drunk-k8s-gateway` | — | `cert-manager`, `traefik` |
| `drunk-squid-basic-auth/` | `drunk-squid-basic-auth-proxy` | `drunk-app` | `ingress-nginx` |

Out of scope: `drunk-sample/`, `drunk-k8s-gateway/` (dir, not a chart), `microsoft-hello-world-app/` — none have `Chart.yaml`.

Note: chart name ≠ directory name for two charts. `.tgz` artifacts use the chart name.

## Chart.yaml changes

### `drunk-app/Chart.yaml`

Switch `drunk-lib` dependency from `file://../drunk-lib` to OCI registry:

```yaml
dependencies:
  - name: drunk-lib
    version: 1.x.x
    repository: oci://ghcr.io/baoduy
```

### `drunk-squid-basic-auth/Chart.yaml`

Switch `drunk-app` dependency from `https://baoduy.github.io/drunk.charts/drunk-app` to OCI registry:

```yaml
dependencies:
  - name: ingress-nginx
    alias: nginx
    version: 4.x.x
    condition: nginx.enabled
    repository: "https://kubernetes.github.io/ingress-nginx"
  - name: drunk-app
    alias: proxy
    version: 1.x.x
    condition: proxy.enabled
    repository: oci://ghcr.io/baoduy
```

Gateway charts (`drunk-nginx-gateway`, `drunk-traefik-gateway`) — no changes; external deps only.

## Workflow design — `.github/workflows/publish-oci.yml`

Aligned with reference `baoduy/agents-and-skills/.github/workflows/npm-publish.yaml`.

### Triggers

```yaml
on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      release:
        description: "Publish to GHCR and create a GitHub release"
        required: false
        default: "true"
```

### Concurrency

```yaml
concurrency:
  group: publish-oci-${{ github.ref }}
  cancel-in-progress: false
```

### Permissions

```yaml
permissions:
  contents: write   # commit version bump, create release
  packages: write   # push to GHCR
  id-token: write   # match reference workflow
```

### Steps

1. **Checkout** — `actions/checkout@v4` with `fetch-depth: 0`, `fetch-tags: true`.
2. **Set up Helm** — `azure/setup-helm@v4`, version `v3.17.3` (pinned per CLAUDE.md).
3. **Calculate version** — `paulhatch/semantic-version@v5.4.0` (downgrade from v6.0.2 to match reference). Same inputs: `tag_prefix: "v"`, `major_pattern: "(MAJOR)"`, `minor_pattern: "(MINOR)"`, `version_format: "${major}.${minor}.${patch}"`, `bump_each_commit: false`, `search_commit_body: false`.
4. **Set `NEXT_VERSION`** — `echo "NEXT_VERSION=${{ steps.version.outputs.version }}" >> "$GITHUB_ENV"`.
5. **Print version** — `echo "Next version is v${NEXT_VERSION}"`.
6. **Determine release flag** — id `flag`, output `enable`:
   - `workflow_dispatch` → use `inputs.release`.
   - `push` to `refs/heads/main` → `true`.
   - else → `false`.
7. **Sync Chart.yaml versions** (if `enable == 'true'`) — bump `version:` in all 5 `Chart.yaml` files to `NEXT_VERSION` via `yq` or node. Idempotent (no-op if already equal).
8. **Commit version bump** (if `enable == 'true'`) — `chore(release): v${NEXT_VERSION} [skip ci]`. Skip if no staged diff. Configure git as `github-actions[bot]`.
9. **Log in to GHCR** (if `enable == 'true'`) — `helm registry login ghcr.io -u ${{ github.actor }} --password-stdin` using `GITHUB_TOKEN`.
10. **Package + push `drunk-lib`** (if `enable == 'true'`):
    ```
    helm package . --version $NEXT_VERSION --destination /tmp/charts
    helm push /tmp/charts/drunk-lib-$NEXT_VERSION.tgz oci://ghcr.io/${{ github.repository_owner }}
    ```
11. **Package + push `drunk-app`** (if `enable == 'true'`):
    ```
    helm dependency update .
    helm package . --version $NEXT_VERSION --destination /tmp/charts
    helm push /tmp/charts/drunk-app-$NEXT_VERSION.tgz oci://ghcr.io/${{ github.repository_owner }}
    ```
12. **Package + push `drunk-nginx-gateway`** (if `enable == 'true'`) — same pattern, tgz `drunk-nginx-gateway-$NEXT_VERSION.tgz`.
13. **Package + push `drunk-traefik-gateway`** (if `enable == 'true'`) — same pattern, tgz `drunk-k8s-gateway-$NEXT_VERSION.tgz`.
14. **Package + push `drunk-squid-basic-auth`** (if `enable == 'true'`) — same pattern, tgz `drunk-squid-basic-auth-proxy-$NEXT_VERSION.tgz`.
15. **Log out GHCR** — `if: always()`, `helm registry logout ghcr.io`.
16. **Create GitHub Release** (if `enable == 'true'`) — `softprops/action-gh-release@v2`, tag `v${NEXT_VERSION}`, generated notes, `make_latest: true`.

### Build order rationale

Sequential single job, not matrix:
- `drunk-lib` first — no deps.
- `drunk-app` next — pulls `drunk-lib` from GHCR (just pushed).
- `drunk-nginx-gateway`, `drunk-traefik-gateway` — independent (external deps only); order arbitrary, sequential for log clarity.
- `drunk-squid-basic-auth` last — pulls `drunk-app` from GHCR (must be pushed first).

## Versioning policy

- Single `NEXT_VERSION` applied uniformly to all 5 charts.
- Dep `version:` constraints remain `1.x.x` (owner manages major-version bumps manually by editing constraints when needed).
- Chart.yaml `version:` field is rewritten by the workflow and committed back to `main`, mirroring the reference `package.json` flow.

## Non-goals

- No matrix parallelism.
- No release-asset uploads (`.tgz` not attached to GitHub Release).
- No per-chart independent versioning.
- No GH Pages publishing — OCI registry only.
- No retroactive changes to charts already published under old dep schemes.

## Risks / verification

- **Major version jump:** if `NEXT_VERSION` becomes `2.0.0`, dep constraint `1.x.x` will not resolve. Owner must bump constraints in dep `version:` field beforehand.
- **GHCR auth ordering:** `helm dependency update` for `drunk-app` and `drunk-squid-basic-auth` requires `helm registry login` to have run before the dep update step. The login step (9) runs before any package step — correct.
- **Backward compatibility:** existing consumers of `drunk-app` who relied on `https://baoduy.github.io/drunk.charts/drunk-app` for the squid chart's dep — none in this repo. External consumers are unaffected because they fetch the published `.tgz`, not the source `Chart.yaml`.
- **`bash drunk-lib/verify.sh`:** still works locally; uses `file://` style indirectly via `helm package`. After this change, `drunk-app` consumers in the local verify path need to also have `helm registry login` for OCI dep resolution. Update `drunk-lib/verify.sh` if it breaks — out of scope for this design, flag separately.

## Open items

None. Owner approved.
