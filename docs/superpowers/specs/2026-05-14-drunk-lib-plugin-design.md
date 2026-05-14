# drunk-lib Plugin — Per-Template Claude Skills

**Status:** Approved
**Date:** 2026-05-14
**Author:** Steven Hoang
**Repo:** `drunk.charts`

## 1. Purpose

Ship a new Claude Code plugin `drunk-lib` that exposes one auto-activated skill per `drunk-lib` template partial. Each skill answers questions, generates `values.yaml` snippets, and validates user-provided YAML for the resource its partial renders. Plumb the repo to host multiple plugins cleanly so new plugins can be added with minimal friction.

## 2. Scope

### In scope

- New plugin at `plugins/drunk-lib/` with **18 skills**, one per template under `drunk-lib/templates/_*.tpl`.
- Registration of the plugin in `.claude-plugin/marketplace.json`.
- Hand-authored `SKILL.md` content for each skill, derived from reading the corresponding `_*.tpl` source plus `_helpers.tpl` and `drunk-lib/README.md`.
- Skill auto-activation via `description` frontmatter keywords.
- `scripts/new-plugin.sh` to scaffold future plugins.
- `.github/workflows/validate-plugins.yml` CI check that validates `marketplace.json`, every `plugin.json`, and every `SKILL.md` frontmatter.

### Out of scope

- Rewriting the existing `drunk-app` plugin.
- Auto-generating `SKILL.md` from `.tpl` AST.
- Building an umbrella router / dispatcher skill.
- `_helpers.tpl` does not get its own skill; helpers are referenced inline from the skills that consume them.
- Publishing the plugin to any external marketplace beyond this repo.

## 3. Architecture

```
plugins/
├── drunk-app/                       # existing, untouched
│   ├── .claude-plugin/plugin.json
│   └── skills/drunk-app/SKILL.md
└── drunk-lib/                       # NEW
    ├── .claude-plugin/plugin.json
    └── skills/
        ├── drunk-lib-deployment/SKILL.md
        ├── drunk-lib-statefulset/SKILL.md
        ├── drunk-lib-cronjob/SKILL.md
        ├── drunk-lib-job/SKILL.md
        ├── drunk-lib-service/SKILL.md
        ├── drunk-lib-ingress/SKILL.md
        ├── drunk-lib-httproute/SKILL.md
        ├── drunk-lib-gateway/SKILL.md
        ├── drunk-lib-backend-tls-policy/SKILL.md
        ├── drunk-lib-hpa/SKILL.md
        ├── drunk-lib-configmap/SKILL.md
        ├── drunk-lib-secrets/SKILL.md
        ├── drunk-lib-tls-secrets/SKILL.md
        ├── drunk-lib-secretprovider/SKILL.md
        ├── drunk-lib-imagepull-secret/SKILL.md
        ├── drunk-lib-networkpolicy/SKILL.md
        ├── drunk-lib-serviceaccount/SKILL.md
        └── drunk-lib-volumes/SKILL.md
```

`marketplace.json` gains a second entry:

```json
{
  "name": "drunk-lib",
  "version": "1.0.0",
  "source": "./plugins/drunk-lib",
  "description": "Per-template assistants for the drunk-lib Helm library chart"
}
```

`plugins/drunk-lib/.claude-plugin/plugin.json`:

```json
{
  "name": "drunk-lib",
  "version": "1.0.0",
  "description": "Per-template AI assistants for the drunk-lib Helm library chart — Deployment, StatefulSet, CronJob, Service, Ingress, HTTPRoute, Gateway, HPA, ConfigMap, Secrets, NetworkPolicy, ServiceAccount, Volumes, and more.",
  "author": { "name": "Steven Hoang" },
  "repository": "https://github.com/baoduy/drunk.charts",
  "license": "MIT",
  "keywords": ["helm", "kubernetes", "drunk-lib", "library-chart", "values", "configuration"]
}
```

## 4. Skill Anatomy

Each `SKILL.md` follows the same template.

### 4.1 Frontmatter

```yaml
---
name: drunk-lib-<template>
description: "Use when configuring/validating the drunk-lib <Resource> partial — answers questions, generates values.yaml snippets, validates a section. Triggers on: <keyword-list>."
---
```

The `description` field is the auto-activation signal. The trailing `Triggers on:` list is the keyword set in section 4.3.

### 4.2 Body sections

1. **What it renders** — one-paragraph summary of the resource produced.
2. **Include usage** — `{{- include "drunk-lib.<name>" . -}}` plus required context (e.g. `(dict "ctx" . "name" "foo")` where applicable).
3. **Values schema** — every `.Values.*` key the partial reads: key, type, default, required?, notes.
4. **Generate mode** — minimal snippet + typical snippet of `values.yaml` for that resource.
5. **Validate checklist** — common mistakes (e.g. Deployment without `tmp` emptyDir when `readOnlyRootFilesystem: true`, Ingress missing TLS, HPA target mismatch, NetworkPolicy that locks out the gateway).
6. **Cross-refs** — links to sibling skills (e.g. Deployment ↔ Service ↔ HPA ↔ NetworkPolicy).
7. **Last-reviewed-commit** — short git SHA noted at bottom for drift tracking.

### 4.3 Trigger keywords

| Skill | Trigger keywords |
|-------|-----------------|
| `drunk-lib-deployment` | deployment, drunk-lib deployment, workload, pod spec, replicas |
| `drunk-lib-statefulset` | statefulset, sts, stateful workload, persistent pod |
| `drunk-lib-cronjob` | cronjob, cron, scheduled job, schedule |
| `drunk-lib-job` | job, one-shot job, batch job |
| `drunk-lib-service` | service, svc, clusterip, nodeport, loadbalancer |
| `drunk-lib-ingress` | ingress, ingress-nginx, ingress rule |
| `drunk-lib-httproute` | httproute, gateway-api route, gateway api |
| `drunk-lib-gateway` | gateway, gateway-api gateway, listener |
| `drunk-lib-backend-tls-policy` | backendtlspolicy, backend tls, upstream tls |
| `drunk-lib-hpa` | hpa, horizontal pod autoscaler, autoscaling, scale |
| `drunk-lib-configmap` | configmap, cm, env config |
| `drunk-lib-secrets` | secret, opaque secret, env secret |
| `drunk-lib-tls-secrets` | tls secret, certificate secret, tls cert |
| `drunk-lib-secretprovider` | secretproviderclass, csi secret, azure key vault, vault csi |
| `drunk-lib-imagepull-secret` | imagepullsecret, dockerconfigjson, registry secret |
| `drunk-lib-networkpolicy` | networkpolicy, netpol, ingress egress policy |
| `drunk-lib-serviceaccount` | serviceaccount, sa, workload identity |
| `drunk-lib-volumes` | volume, pvc, emptydir, persistentvolumeclaim, tmp volume |

Where keywords overlap between skills (e.g. "deployment" vs "statefulset"), descriptions disambiguate by including the resource kind explicitly.

## 5. Multi-Plugin Tooling

### 5.1 `scripts/new-plugin.sh`

```
Usage: scripts/new-plugin.sh <plugin-name> "<description>"

Actions:
  1. Validate <plugin-name> matches ^[a-z][a-z0-9-]*$
  2. Refuse if plugins/<plugin-name> already exists
  3. Create plugins/<plugin-name>/.claude-plugin/plugin.json
       (name, version 0.1.0, description, author from `git config user.name`, repo, license MIT)
  4. Create plugins/<plugin-name>/skills/<plugin-name>/SKILL.md
       (frontmatter with name + description placeholder, TODO body)
  5. Use `jq` to append a new entry to .claude-plugin/marketplace.json
       (name, version 0.1.0, source "./plugins/<plugin-name>", description)
  6. Print next-step hints (edit SKILL.md, run validator, commit)
```

Dependencies: `bash`, `jq`. Script must be idempotent-safe (refuse on duplicate, no partial writes).

### 5.2 `.github/workflows/validate-plugins.yml`

Triggers: `pull_request` and `push` on paths `plugins/**`, `.claude-plugin/**`, `scripts/new-plugin.sh`.

Steps:

1. Checkout.
2. Install `jq` and `yq` (mikefarah/yq).
3. **Validate marketplace.json shape**: top-level `name`, `owner.name`, `plugins` array; each entry has `name`, `version`, `source`, `description`.
4. **Validate sources exist**: for each `plugins[].source`, assert the directory and its `.claude-plugin/plugin.json` exist.
5. **Validate plugin.json fields**: each `plugin.json` has non-empty `name`, `version`, `description`, `author.name`.
6. **Validate skill frontmatter**: for every `plugins/*/skills/*/SKILL.md`, parse YAML frontmatter and assert `name` and `description` exist and are non-empty.
7. **Validate skill name uniqueness**: no two skills in the repo share a `name` value.
8. Fail with `file:line: <reason>` on any violation.

## 6. Data Flow

```
user prompt
  │
  ▼
Claude Code matches description / triggers
  │
  ▼
loads relevant drunk-lib-<resource> SKILL.md
  │
  ├─► Mode 1: answer Q from "Values schema"
  ├─► Mode 2: generate values.yaml snippet from "Generate mode"
  └─► Mode 3: validate user YAML against "Validate checklist"
```

No runtime dependencies, no MCP servers, no scripts executed by the skill — content is static markdown.

## 7. Error Handling

- **Stale skill content** (template changes after skill written): out of scope for automated detection. Mitigation: `Last-reviewed-commit` SHA at bottom of each `SKILL.md`. Reviewers spot-check during PR review.
- **Activation collisions** (two skills triggered): Claude Code picks one; user can be explicit. Descriptions disambiguate.
- **Malformed marketplace.json**: caught by CI validator.
- **Missing skill frontmatter**: caught by CI validator.

## 8. Testing

- CI validator workflow runs on every PR.
- Manual smoke test: install plugin from local marketplace, invoke each skill by keyword, confirm activation.
- No unit test framework — content is markdown.

## 9. Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Skill content drifts from `.tpl` source | medium | `Last-reviewed-commit` SHA; periodic spot-checks |
| 18 overlapping descriptions cause activation noise | medium | Disambiguate descriptions; explicit resource kind in each |
| `marketplace.json` parse error breaks all plugins | high | CI validator gate |
| `scripts/new-plugin.sh` writes partial state on failure | low | Use `set -euo pipefail`, write to temp then move |

## 10. Acceptance Criteria

- [ ] `plugins/drunk-lib/.claude-plugin/plugin.json` exists and is valid.
- [ ] 18 `SKILL.md` files under `plugins/drunk-lib/skills/drunk-lib-*/` exist and have valid frontmatter.
- [ ] Each `SKILL.md` covers all six body sections defined in §4.2.
- [ ] `.claude-plugin/marketplace.json` has a `drunk-lib` entry.
- [ ] `scripts/new-plugin.sh` exists, is executable, and successfully scaffolds a throwaway test plugin (verified manually, not committed).
- [ ] `.github/workflows/validate-plugins.yml` exists and passes against the new layout.
- [ ] `bash drunk-lib/verify.sh` still passes (no chart changes expected, but enforce).

## 11. References

- Existing pattern: `plugins/drunk-app/`
- Source templates: `drunk-lib/templates/_*.tpl`
- Repo conventions: `CLAUDE.md`
- Library chart docs: `drunk-lib/README.md`
