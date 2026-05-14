# Project: drunk.charts

This repo packages Helm charts published as OCI images to `ghcr.io/baoduy`.

- `drunk-lib/` — Helm **library** chart (`type: library`) used as a dependency by other charts. All templates are `_*.tpl` partials consumed via `include`. This is the chart we are improving.
- `drunk-app/` — Helm **application** chart that depends on `drunk-lib` and renders real workloads.
- `drunk-traefik-gateway/`, `drunk-nginx-gateway/`, `drunk-squid-basic-auth/`, `drunk-sample/`, `microsoft-hello-world-app/` — additional application charts that may also use `drunk-lib`.

CI: `.github/workflows/publish-oci.yml` builds and pushes the charts to GHCR on push to `main`. Helm `v3.17.3` is pinned.

Verification: `drunk-lib/verify.sh` runs `helm package` + `helm repo index` and copies the latest `.tgz` into `drunk-app/charts/`. Per user instruction, run `drunk-lib/verify.sh` after any change to `drunk-lib/`.

```team-superpower
# ────────────────────────────────────────────────────────────────────────────
# Backend — Helm library chart authoring
# ────────────────────────────────────────────────────────────────────────────
backend:
  language: yaml
  framework: helm-library
  test_framework: none
  build_command: helm package drunk-lib
  test_command: bash drunk-lib/verify.sh
  format_command: none
  migration_tool: none
  package_manager: helm

# ────────────────────────────────────────────────────────────────────────────
# Frontend — none
# ────────────────────────────────────────────────────────────────────────────
frontend: none

# ────────────────────────────────────────────────────────────────────────────
# Contracts — none
# ────────────────────────────────────────────────────────────────────────────
contracts:
  source_of_truth: none

# ────────────────────────────────────────────────────────────────────────────
# CI
# ────────────────────────────────────────────────────────────────────────────
ci:
  provider: github-actions
  workflow_path: .github/workflows/publish-oci.yml
  required_checks: ["publish"]
  poll_timeout_minutes: 20

# ────────────────────────────────────────────────────────────────────────────
# Security
# ────────────────────────────────────────────────────────────────────────────
security:
  domain: internal-only
  pii: no
  public_endpoints: no
  data_at_rest: none

# ────────────────────────────────────────────────────────────────────────────
# Limits
# ────────────────────────────────────────────────────────────────────────────
limits:
  phase_stall_minutes: 30
  max_tasks_per_implementer: 12
  max_concurrent_teammates: 5
```

## Conventions

- All `drunk-lib` templates are **partials** (`_name.tpl`) consumed by other charts via `{{- include "drunk-lib.<name>" . -}}`.
- Backward compatibility is REQUIRED. Existing consumers (`drunk-app/`, gateways) must keep rendering identically unless they opt into new behavior.
- After changing anything under `drunk-lib/`, run `bash drunk-lib/verify.sh` before declaring done.
- Helm template naming: `drunk-lib.<resource>` (e.g. `drunk-lib.deployment`). Keep this prefix.
- Values keys live under `.Values` and are documented in `drunk-lib/README.md`. Update README when you add or rename a value.
- Use `with` / `if` / `default` to keep fields optional. Avoid hard-required values when a sensible default exists.
- Library charts must not render any top-level templates themselves — only `_*.tpl` partials. Adding a non-partial file under `drunk-lib/templates/` will break OCI packaging.
