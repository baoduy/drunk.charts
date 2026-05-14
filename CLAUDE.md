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
<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **drunk.charts** (1166 symbols, 1187 relationships, 0 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> If any GitNexus tool warns the index is stale, run `npx gitnexus analyze` in terminal first.

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `gitnexus_impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `gitnexus_detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `gitnexus_query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `gitnexus_context({name: "symbolName"})`.

## Never Do

- NEVER edit a function, class, or method without first running `gitnexus_impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `gitnexus_rename` which understands the call graph.
- NEVER commit changes without running `gitnexus_detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/drunk.charts/context` | Codebase overview, check index freshness |
| `gitnexus://repo/drunk.charts/clusters` | All functional areas |
| `gitnexus://repo/drunk.charts/processes` | All execution flows |
| `gitnexus://repo/drunk.charts/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
