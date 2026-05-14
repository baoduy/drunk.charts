# drunk-lib Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a new `drunk-lib` Claude Code plugin with 18 auto-activating per-template skills, plus a scaffolding script and CI validator that make this repo a first-class multi-plugin marketplace.

**Architecture:** Add `plugins/drunk-lib/` next to existing `plugins/drunk-app/`. Each `_*.tpl` partial gets a hand-authored `SKILL.md` under `plugins/drunk-lib/skills/drunk-lib-<resource>/`. Register the plugin in `.claude-plugin/marketplace.json`. Add `scripts/new-plugin.sh` for future plugins and `.github/workflows/validate-plugins.yml` to enforce shape on every PR.

**Tech Stack:** Helm 3.17.3, Markdown + YAML frontmatter, bash, `jq`, `yq` (mikefarah), GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-05-14-drunk-lib-plugin-design.md` (commit `86a1c79`).

**Working branch:** `dev` (per repo convention — implementation work occurs on `dev`).

---

## File Structure

### Created

```
plugins/drunk-lib/
├── .claude-plugin/plugin.json                          # plugin manifest
└── skills/
    ├── drunk-lib-deployment/SKILL.md                   # Deployment partial
    ├── drunk-lib-statefulset/SKILL.md                  # StatefulSet partial
    ├── drunk-lib-cronjob/SKILL.md                      # CronJob partial
    ├── drunk-lib-job/SKILL.md                          # Job partial
    ├── drunk-lib-service/SKILL.md                      # Service partial
    ├── drunk-lib-ingress/SKILL.md                      # Ingress partial
    ├── drunk-lib-httproute/SKILL.md                    # HTTPRoute partial
    ├── drunk-lib-gateway/SKILL.md                      # Gateway partial
    ├── drunk-lib-backend-tls-policy/SKILL.md           # BackendTLSPolicy
    ├── drunk-lib-hpa/SKILL.md                          # HPA partial
    ├── drunk-lib-configmap/SKILL.md                    # ConfigMap partial
    ├── drunk-lib-secrets/SKILL.md                      # Opaque Secret
    ├── drunk-lib-tls-secrets/SKILL.md                  # TLS Secret
    ├── drunk-lib-secretprovider/SKILL.md               # SecretProviderClass
    ├── drunk-lib-imagepull-secret/SKILL.md             # imagePullSecret
    ├── drunk-lib-networkpolicy/SKILL.md                # NetworkPolicy
    ├── drunk-lib-serviceaccount/SKILL.md               # ServiceAccount
    └── drunk-lib-volumes/SKILL.md                      # Volumes / PVC / emptyDir

scripts/new-plugin.sh                                   # plugin scaffolder
.github/workflows/validate-plugins.yml                  # PR validator
docs/superpowers/templates/SKILL.md.template            # shared skill skeleton
```

### Modified

```
.claude-plugin/marketplace.json                         # append drunk-lib entry
```

---

## Task 1: Worktree and branch baseline

**Files:**
- Read: `.claude-plugin/marketplace.json`
- Read: `CLAUDE.md`

- [ ] **Step 1: Confirm clean working tree on `dev`**

Run:
```bash
git status --short
git rev-parse --abbrev-ref HEAD
```
Expected: empty diff (or only the approved spec from commit `86a1c79`), branch = `dev`. If not on `dev`, switch with `git checkout dev`. If dirty, halt and ask user.

- [ ] **Step 2: Verify spec commit exists**

Run:
```bash
git log --oneline -1 -- docs/superpowers/specs/2026-05-14-drunk-lib-plugin-design.md
```
Expected: includes commit `86a1c79` (or later commit modifying the same spec).

- [ ] **Step 3: Verify baseline tests pass**

Run:
```bash
bash drunk-lib/verify.sh
```
Expected: completes with non-zero exit only if pre-existing golden mismatch (`drunk-lib-1.3.2 != 1.3.5`). Record exit code and stdout — used as baseline to compare against Task 23.

No commit in this task.

---

## Task 2: Add the shared SKILL.md template

**Files:**
- Create: `docs/superpowers/templates/SKILL.md.template`

- [ ] **Step 1: Create the template file**

Write `docs/superpowers/templates/SKILL.md.template` with this exact content:

````markdown
---
name: drunk-lib-<RESOURCE-SLUG>
description: "Use when configuring/validating the drunk-lib <Resource> partial — answers questions, generates values.yaml snippets, validates a section. Triggers on: <comma-separated keyword list>."
---

# drunk-lib · <Resource>

You are an expert on the `drunk-lib` Helm library chart's `<Resource>` partial (`drunk-lib/templates/_<file>.tpl`). Help developers configure, generate, and validate the `<resource-yaml-block>` section of `values.yaml`.

## What it renders

<One paragraph: what Kubernetes object the partial emits, when (`.Values.<gate>.enabled`), and how it depends on other partials.>

## Include usage

```yaml
{{- include "drunk-lib.<name>" . -}}
```

<Note any required context dict — most partials take the root `.`; some take `(dict "ctx" . "name" "foo")`.>

## Values schema

| Key | Type | Default | Required? | Notes |
|-----|------|---------|-----------|-------|
| `.Values.<gate>.enabled` | bool | `false` | yes | Toggles rendering. |
| `.Values.<…>` | … | … | … | … |

## Generate mode

When the developer says "give me a values.yaml for <Resource> doing X":

**Minimal:**
```yaml
<minimal working snippet>
```

**Typical:**
```yaml
<a richer real-world snippet>
```

## Validate checklist

When the developer pastes a values.yaml section, check each of these and report any miss:

- [ ] `<rule 1>` — <why>
- [ ] `<rule 2>` — <why>
- [ ] `<rule 3>` — <why>

## Cross-refs

- `drunk-lib-<sibling>` — <relationship>
- `drunk-lib-<sibling>` — <relationship>

## Last-reviewed-commit

`<short SHA of `drunk-lib/templates/_<file>.tpl` at time of authoring>`
````

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/templates/SKILL.md.template
git commit -m "docs: add shared SKILL.md template for plugin skills"
```

---

## Task 3: Scaffold the drunk-lib plugin shell

**Files:**
- Create: `plugins/drunk-lib/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Create plugin directory and manifest**

```bash
mkdir -p plugins/drunk-lib/.claude-plugin plugins/drunk-lib/skills
```

Write `plugins/drunk-lib/.claude-plugin/plugin.json`:

```json
{
  "name": "drunk-lib",
  "version": "1.0.0",
  "description": "Per-template AI assistants for the drunk-lib Helm library chart — Deployment, StatefulSet, CronJob, Job, Service, Ingress, HTTPRoute, Gateway, BackendTLSPolicy, HPA, ConfigMap, Secrets, TLS Secrets, SecretProviderClass, imagePullSecret, NetworkPolicy, ServiceAccount, and Volumes.",
  "author": { "name": "Steven Hoang" },
  "repository": "https://github.com/baoduy/drunk.charts",
  "license": "MIT",
  "keywords": ["helm", "kubernetes", "drunk-lib", "library-chart", "values", "configuration"]
}
```

- [ ] **Step 2: Append plugin to marketplace.json**

Edit `.claude-plugin/marketplace.json`. Final contents:

```json
{
  "name": "drunk-charts",
  "owner": {
    "name": "Steven Hoang"
  },
  "metadata": {
    "description": "Helm chart plugins for drunk.charts",
    "homepage": "https://github.com/baoduy/drunk.charts"
  },
  "plugins": [
    {
      "name": "drunk-app",
      "version": "1.0.0",
      "source": "./plugins/drunk-app",
      "description": "AI assistant for configuring drunk-app Helm chart deployments"
    },
    {
      "name": "drunk-lib",
      "version": "1.0.0",
      "source": "./plugins/drunk-lib",
      "description": "Per-template assistants for the drunk-lib Helm library chart"
    }
  ]
}
```

- [ ] **Step 3: Validate JSON**

```bash
jq . .claude-plugin/marketplace.json > /dev/null
jq . plugins/drunk-lib/.claude-plugin/plugin.json > /dev/null
```
Expected: no output, exit 0.

- [ ] **Step 4: Commit**

```bash
git add plugins/drunk-lib/.claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "feat(plugin): scaffold drunk-lib plugin manifest"
```

---

## Authoring each SKILL.md — shared procedure

Tasks 4–21 each create one `SKILL.md`. They all follow the **same five steps**:

1. **Read the source partial** to extract every `.Values.*` reference, what guards rendering (`enabled` gate), and required context.
2. **Capture the partial's commit SHA** for `Last-reviewed-commit`:
   ```bash
   git log -1 --format=%h -- drunk-lib/templates/_<file>.tpl
   ```
3. **Write `plugins/drunk-lib/skills/drunk-lib-<slug>/SKILL.md`** by copying `docs/superpowers/templates/SKILL.md.template` and filling every angle-bracket placeholder using the per-task table below. **No placeholders may remain** — if a row's data is unknown after reading the partial, stop and report.
4. **Frontmatter sanity check**:
   ```bash
   awk 'NR==1,/^---$/{print}' plugins/drunk-lib/skills/drunk-lib-<slug>/SKILL.md
   ```
   Expected: opens with `---`, closes with `---`, contains `name:` and `description:` lines.
5. **Commit**:
   ```bash
   git add plugins/drunk-lib/skills/drunk-lib-<slug>/SKILL.md
   git commit -m "feat(skill): drunk-lib-<slug> per-template assistant"
   ```

The per-task tables below give the **substitution data** specific to that template. The authoring agent reads the `.tpl` file to flesh out the `Values schema` rows and snippets — the table fixes the unique identifiers and trigger keywords so disambiguation rules from the spec hold.

---

## Task 4: SKILL — drunk-lib-deployment

**Files:**
- Read: `drunk-lib/templates/_deployment.tpl`
- Read: `drunk-lib/templates/_helpers.tpl`
- Create: `plugins/drunk-lib/skills/drunk-lib-deployment/SKILL.md`

- [ ] **Step 1: Read partial and capture SHA**

```bash
mkdir -p plugins/drunk-lib/skills/drunk-lib-deployment
git log -1 --format=%h -- drunk-lib/templates/_deployment.tpl
```

- [ ] **Step 2: Author SKILL.md using these substitutions**

| Placeholder | Value |
|-------------|-------|
| `<RESOURCE-SLUG>` | `deployment` |
| `<Resource>` | `Deployment` |
| `<file>` | `deployment` |
| `<name>` | `deployment` |
| `<gate>` | `deployment.enabled` |
| `<resource-yaml-block>` | `deployment` |
| Trigger keywords | `deployment, drunk-lib deployment, workload, pod spec, replicas` |

**Values schema rows** (extract every `.Values.deployment.*` plus `.Values.global.*` reads): `replicaCount`, `strategy.type`, `strategy.maxSurge`, `strategy.maxUnavailable`, `podAnnotations`, `podLabels`, `nodeSelector`, `tolerations`, `affinity`, `topologySpreadConstraints`, `priorityClassName`, `terminationGracePeriodSeconds`, `restartPolicy`, ports, probes (`livenessProbe`, `readinessProbe`, `startupProbe`), `resources`, `env`, `envFrom`, `volumeMounts`, `securityContext`, `containers` extras, plus `global.image`, `global.tag`, `global.imagePullSecrets`, `global.serviceAccount`, `global.initContainer`.

**Validate checklist** must include:
- Missing `tmp` emptyDir when `readOnlyRootFilesystem: true` (default).
- `replicaCount: 1` with `strategy.type: RollingUpdate` + `maxUnavailable: 0` — deployments will block; recommend ≥2 or `Recreate`.
- Probes hitting a port not declared in `ports`.
- `env` referencing a `valueFrom.configMapKeyRef`/`secretKeyRef` whose name does not match a `configmap`/`secret` block in values.

**Cross-refs:** `drunk-lib-service`, `drunk-lib-hpa`, `drunk-lib-configmap`, `drunk-lib-secrets`, `drunk-lib-volumes`, `drunk-lib-networkpolicy`, `drunk-lib-serviceaccount`.

- [ ] **Step 3: Verify no placeholders left**

```bash
grep -nE '<[A-Za-z-]+>' plugins/drunk-lib/skills/drunk-lib-deployment/SKILL.md || echo OK
```
Expected: `OK`.

- [ ] **Step 4: Frontmatter sanity check** (shared procedure step 4)

- [ ] **Step 5: Commit** (shared procedure step 5)

---

## Task 5: SKILL — drunk-lib-statefulset

**Files:**
- Read: `drunk-lib/templates/_statefulset.tpl`
- Create: `plugins/drunk-lib/skills/drunk-lib-statefulset/SKILL.md`

- [ ] **Step 1: Read partial, capture SHA**

| Placeholder | Value |
|-------------|-------|
| `<RESOURCE-SLUG>` | `statefulset` |
| `<Resource>` | `StatefulSet` |
| `<file>` | `statefulset` |
| `<name>` | `statefulset` |
| `<gate>` | `statefulset.enabled` |
| Trigger keywords | `statefulset, sts, stateful workload, persistent pod` |

**Values schema** must cover `statefulset.replicaCount`, `serviceName`, `volumeClaimTemplates`, `updateStrategy`, `podManagementPolicy`, plus all the same container-level keys as Deployment.

**Validate checklist** must include:
- Missing `serviceName` — StatefulSet requires a headless Service.
- `volumeClaimTemplates` entry with no matching `volumeMounts` in the container.
- Storage class not specified when cluster has no default.

**Cross-refs:** `drunk-lib-service` (headless), `drunk-lib-volumes`, `drunk-lib-configmap`, `drunk-lib-secrets`.

- [ ] **Step 2: Author SKILL.md**

Follow shared procedure with substitutions above and Deployment-style guarantees. Disambiguating phrase in `description`: "Use for **StatefulSet** workloads (sticky identity, stable storage)."

- [ ] **Step 3: Placeholder + frontmatter check + Commit** (shared steps 4–5)

---

## Task 6: SKILL — drunk-lib-cronjob

**Files:**
- Read: `drunk-lib/templates/_cronjob.tpl`
- Create: `plugins/drunk-lib/skills/drunk-lib-cronjob/SKILL.md`

| Placeholder | Value |
|-------------|-------|
| `<RESOURCE-SLUG>` | `cronjob` |
| `<Resource>` | `CronJob` |
| `<file>` | `cronjob` |
| `<name>` | `cronjob` |
| `<gate>` | `cronJobs[].enabled` (per-item) |
| Trigger keywords | `cronjob, cron, scheduled job, schedule` |

**Values schema** must cover the list shape `cronJobs[]`: `name`, `schedule`, `concurrencyPolicy`, `successfulJobsHistoryLimit`, `failedJobsHistoryLimit`, `suspend`, `startingDeadlineSeconds`, `timeZone`, then per-item job template fields mirroring `drunk-lib-job`.

**Validate checklist:**
- Invalid cron syntax in `schedule`.
- `concurrencyPolicy: Forbid` paired with very frequent schedule and long-running jobs — risks suspension cascade.
- Missing `restartPolicy: OnFailure | Never`.
- No resource requests/limits.

**Cross-refs:** `drunk-lib-job`, `drunk-lib-configmap`, `drunk-lib-secrets`, `drunk-lib-serviceaccount`.

- [ ] Author, placeholder + frontmatter check, commit (shared procedure).

---

## Task 7: SKILL — drunk-lib-job

**Files:**
- Read: `drunk-lib/templates/_job.tpl`
- Create: `plugins/drunk-lib/skills/drunk-lib-job/SKILL.md`

| Placeholder | Value |
|-------------|-------|
| `<RESOURCE-SLUG>` | `job` |
| `<Resource>` | `Job` |
| `<file>` | `job` |
| `<name>` | `job` |
| `<gate>` | `jobs[].enabled` (per-item) |
| Trigger keywords | `job, one-shot job, batch job` |

**Values schema:** `jobs[]` with `name`, `parallelism`, `completions`, `backoffLimit`, `activeDeadlineSeconds`, `ttlSecondsAfterFinished`, container template.

**Validate checklist:**
- Missing `restartPolicy: OnFailure | Never`.
- `backoffLimit: 0` with non-idempotent container — single failure terminates.
- No `ttlSecondsAfterFinished` — completed jobs pile up.

**Cross-refs:** `drunk-lib-cronjob`, `drunk-lib-configmap`, `drunk-lib-secrets`, `drunk-lib-serviceaccount`.

- [ ] Author, placeholder + frontmatter check, commit.

---

## Task 8: SKILL — drunk-lib-service

**Files:**
- Read: `drunk-lib/templates/_service.tpl`
- Create: `plugins/drunk-lib/skills/drunk-lib-service/SKILL.md`

| Placeholder | Value |
|-------------|-------|
| `<RESOURCE-SLUG>` | `service` |
| `<Resource>` | `Service` |
| `<file>` | `service` |
| `<name>` | `service` |
| `<gate>` | `service.enabled` |
| Trigger keywords | `service, svc, clusterip, nodeport, loadbalancer` |

**Values schema:** `service.type`, `service.ports[]` (`name`, `port`, `targetPort`, `protocol`, `nodePort`), `service.annotations`, `service.clusterIP`, `service.externalTrafficPolicy`, `service.sessionAffinity`.

**Validate checklist:**
- `targetPort` not declared by Deployment/StatefulSet containers.
- `type: LoadBalancer` without cloud-controller annotations on managed clusters.
- Headless service for StatefulSet missing `clusterIP: None`.

**Cross-refs:** `drunk-lib-deployment`, `drunk-lib-statefulset`, `drunk-lib-ingress`, `drunk-lib-httproute`.

- [ ] Author, placeholder + frontmatter check, commit.

---

## Task 9: SKILL — drunk-lib-ingress

**Files:**
- Read: `drunk-lib/templates/_ingress.tpl`
- Create: `plugins/drunk-lib/skills/drunk-lib-ingress/SKILL.md`

| Placeholder | Value |
|-------------|-------|
| `<RESOURCE-SLUG>` | `ingress` |
| `<Resource>` | `Ingress` |
| `<file>` | `ingress` |
| `<name>` | `ingress` |
| `<gate>` | `ingress.enabled` |
| Trigger keywords | `ingress, ingress-nginx, ingress rule` |

**Values schema:** `ingress.className`, `ingress.annotations`, `ingress.hosts[]` (`host`, `paths[]` with `path`, `pathType`, `serviceName`, `servicePort`), `ingress.tls[]` (`hosts`, `secretName`).

**Validate checklist:**
- `tls[].secretName` missing from `tls-secrets` block or external secret.
- `paths[].serviceName` not declared as a Service.
- `pathType` missing — required since networking.k8s.io/v1.

**Cross-refs:** `drunk-lib-service`, `drunk-lib-tls-secrets`, `drunk-lib-httproute` ("prefer HTTPRoute on Gateway API clusters").

- [ ] Author, placeholder + frontmatter check, commit.

---

## Task 10: SKILL — drunk-lib-httproute

**Files:**
- Read: `drunk-lib/templates/_httproute.tpl`
- Create: `plugins/drunk-lib/skills/drunk-lib-httproute/SKILL.md`

| Placeholder | Value |
|-------------|-------|
| `<RESOURCE-SLUG>` | `httproute` |
| `<Resource>` | `HTTPRoute` |
| `<file>` | `httproute` |
| `<name>` | `httproute` |
| `<gate>` | `httpRoute.enabled` |
| Trigger keywords | `httproute, gateway-api route, gateway api` |

**Values schema:** `httpRoute.parentRefs[]`, `httpRoute.hostnames[]`, `httpRoute.rules[]` (`matches`, `filters`, `backendRefs`).

**Validate checklist:**
- `parentRefs` referring to a Gateway not in cluster.
- `backendRefs[].name` not matching a Service.
- Mixing path-prefix + exact-path rules with the same precedence (ambiguous routing).

**Cross-refs:** `drunk-lib-gateway`, `drunk-lib-service`, `drunk-lib-backend-tls-policy`, `drunk-lib-ingress`.

- [ ] Author, placeholder + frontmatter check, commit.

---

## Task 11: SKILL — drunk-lib-gateway

**Files:**
- Read: `drunk-lib/templates/_gateway.tpl`
- Create: `plugins/drunk-lib/skills/drunk-lib-gateway/SKILL.md`

| Placeholder | Value |
|-------------|-------|
| `<RESOURCE-SLUG>` | `gateway` |
| `<Resource>` | `Gateway` |
| `<file>` | `gateway` |
| `<name>` | `gateway` |
| `<gate>` | `gateway.enabled` |
| Trigger keywords | `gateway, gateway-api gateway, listener` |

**Values schema:** `gateway.gatewayClassName`, `gateway.listeners[]` (`name`, `port`, `protocol`, `hostname`, `tls`, `allowedRoutes`).

**Validate checklist:**
- TLS listener missing `certificateRefs`.
- `allowedRoutes.namespaces.from: Selector` with no `selector` defined.
- Duplicate `(port, protocol, hostname)` across listeners.

**Cross-refs:** `drunk-lib-httproute`, `drunk-lib-tls-secrets`, `drunk-lib-backend-tls-policy`.

- [ ] Author, placeholder + frontmatter check, commit.

---

## Task 12: SKILL — drunk-lib-backend-tls-policy

**Files:**
- Read: `drunk-lib/templates/_backend-tls-policy.tpl`
- Create: `plugins/drunk-lib/skills/drunk-lib-backend-tls-policy/SKILL.md`

| Placeholder | Value |
|-------------|-------|
| `<RESOURCE-SLUG>` | `backend-tls-policy` |
| `<Resource>` | `BackendTLSPolicy` |
| `<file>` | `backend-tls-policy` |
| `<name>` | `backendTlsPolicy` |
| `<gate>` | `backendTlsPolicy.enabled` |
| Trigger keywords | `backendtlspolicy, backend tls, upstream tls` |

**Values schema:** `backendTlsPolicy.targetRefs[]`, `backendTlsPolicy.validation` (`caCertificateRefs`, `hostname`, `wellKnownCACertificates`).

**Validate checklist:**
- No CA refs and no `wellKnownCACertificates: System` — validation will fail.
- `hostname` mismatch with backend SAN.
- TargetRef to a non-Service kind.

**Cross-refs:** `drunk-lib-httproute`, `drunk-lib-gateway`, `drunk-lib-service`.

- [ ] Author, placeholder + frontmatter check, commit.

---

## Task 13: SKILL — drunk-lib-hpa

**Files:**
- Read: `drunk-lib/templates/_hpa.tpl`
- Create: `plugins/drunk-lib/skills/drunk-lib-hpa/SKILL.md`

| Placeholder | Value |
|-------------|-------|
| `<RESOURCE-SLUG>` | `hpa` |
| `<Resource>` | `HorizontalPodAutoscaler` |
| `<file>` | `hpa` |
| `<name>` | `hpa` |
| `<gate>` | `hpa.enabled` |
| Trigger keywords | `hpa, horizontal pod autoscaler, autoscaling, scale` |

**Values schema:** `hpa.scaleTargetRef` (defaults to the chart's Deployment/StatefulSet), `hpa.minReplicas`, `hpa.maxReplicas`, `hpa.metrics[]`, `hpa.behavior`.

**Validate checklist:**
- HPA enabled while `deployment.replicaCount` is set — values fight.
- `minReplicas > maxReplicas`.
- CPU/memory metric without `resources.requests` on the container.
- ScaleTargetRef to a workload not declared elsewhere in values.

**Cross-refs:** `drunk-lib-deployment`, `drunk-lib-statefulset`.

- [ ] Author, placeholder + frontmatter check, commit.

---

## Task 14: SKILL — drunk-lib-configmap

**Files:**
- Read: `drunk-lib/templates/_configMap.tpl`
- Create: `plugins/drunk-lib/skills/drunk-lib-configmap/SKILL.md`

| Placeholder | Value |
|-------------|-------|
| `<RESOURCE-SLUG>` | `configmap` |
| `<Resource>` | `ConfigMap` |
| `<file>` | `configMap` |
| `<name>` | `configmap` |
| `<gate>` | `configMap[].enabled` or list presence |
| Trigger keywords | `configmap, cm, env config` |

**Values schema:** `configMap[]` with `name`, `data` (key/value), `binaryData`.

**Validate checklist:**
- ConfigMap name referenced by Deployment `envFrom.configMapRef` does not exist in values.
- Non-string values in `data` (Helm coerces but K8s requires strings).
- Binary blobs that should be in a Secret.

**Cross-refs:** `drunk-lib-deployment`, `drunk-lib-statefulset`, `drunk-lib-secrets`.

- [ ] Author, placeholder + frontmatter check, commit.

---

## Task 15: SKILL — drunk-lib-secrets

**Files:**
- Read: `drunk-lib/templates/_secrets.tpl`
- Create: `plugins/drunk-lib/skills/drunk-lib-secrets/SKILL.md`

| Placeholder | Value |
|-------------|-------|
| `<RESOURCE-SLUG>` | `secrets` |
| `<Resource>` | `Secret (Opaque)` |
| `<file>` | `secrets` |
| `<name>` | `secrets` |
| `<gate>` | `secrets[]` |
| Trigger keywords | `secret, opaque secret, env secret` |

**Values schema:** `secrets[]` with `name`, `type` (default `Opaque`), `stringData`, `data`.

**Validate checklist:**
- Plaintext secrets committed to values.yaml — recommend `SecretProviderClass`.
- Both `data` and `stringData` setting the same key.
- Missing `type` when not Opaque (`kubernetes.io/dockerconfigjson` needs explicit type — defer to imagepull-secret skill).

**Cross-refs:** `drunk-lib-secretprovider`, `drunk-lib-tls-secrets`, `drunk-lib-imagepull-secret`, `drunk-lib-configmap`.

- [ ] Author, placeholder + frontmatter check, commit.

---

## Task 16: SKILL — drunk-lib-tls-secrets

**Files:**
- Read: `drunk-lib/templates/_tls-secrets.tpl`
- Create: `plugins/drunk-lib/skills/drunk-lib-tls-secrets/SKILL.md`

| Placeholder | Value |
|-------------|-------|
| `<RESOURCE-SLUG>` | `tls-secrets` |
| `<Resource>` | `Secret (kubernetes.io/tls)` |
| `<file>` | `tls-secrets` |
| `<name>` | `tlsSecrets` |
| `<gate>` | `tlsSecrets[]` |
| Trigger keywords | `tls secret, certificate secret, tls cert` |

**Values schema:** `tlsSecrets[]` with `name`, `cert`, `key` (PEM-encoded), or `certData`/`keyData` (base64).

**Validate checklist:**
- PEM cert + key mismatch (different modulus).
- Cert expiry in the past.
- Wildcard cert used for hostname outside the wildcard.

**Cross-refs:** `drunk-lib-ingress`, `drunk-lib-gateway`, `drunk-lib-secretprovider`.

- [ ] Author, placeholder + frontmatter check, commit.

---

## Task 17: SKILL — drunk-lib-secretprovider

**Files:**
- Read: `drunk-lib/templates/_secretprovider.tpl`
- Create: `plugins/drunk-lib/skills/drunk-lib-secretprovider/SKILL.md`

| Placeholder | Value |
|-------------|-------|
| `<RESOURCE-SLUG>` | `secretprovider` |
| `<Resource>` | `SecretProviderClass` |
| `<file>` | `secretprovider` |
| `<name>` | `secretproviderclass` |
| `<gate>` | `secretProviderClass.enabled` |
| Trigger keywords | `secretproviderclass, csi secret, azure key vault, vault csi` |

**Values schema:** `secretProviderClass.provider` (azure/aws/vault/gcp), `secretProviderClass.parameters` (raw map), `secretProviderClass.secretObjects[]`.

**Validate checklist:**
- `provider: azure` without `keyvaultName`, `tenantId`, `userAssignedIdentityID` in parameters.
- `secretObjects[].secretName` collision with a `secrets[]` entry.
- Mount path expected but no `volumeMounts` entry referencing the CSI volume in Deployment.

**Cross-refs:** `drunk-lib-secrets`, `drunk-lib-volumes`, `drunk-lib-deployment`, `drunk-lib-serviceaccount` (workload identity).

- [ ] Author, placeholder + frontmatter check, commit.

---

## Task 18: SKILL — drunk-lib-imagepull-secret

**Files:**
- Read: `drunk-lib/templates/_imagePull-secret.tpl`
- Create: `plugins/drunk-lib/skills/drunk-lib-imagepull-secret/SKILL.md`

| Placeholder | Value |
|-------------|-------|
| `<RESOURCE-SLUG>` | `imagepull-secret` |
| `<Resource>` | `Secret (kubernetes.io/dockerconfigjson)` |
| `<file>` | `imagePull-secret` |
| `<name>` | `imagePullSecret` |
| `<gate>` | `imagePullSecret.enabled` |
| Trigger keywords | `imagepullsecret, dockerconfigjson, registry secret` |

**Values schema:** `imagePullSecret.name`, `imagePullSecret.registry`, `imagePullSecret.username`, `imagePullSecret.password`, `imagePullSecret.email`, or pre-built `imagePullSecret.dockerConfigJson`.

**Validate checklist:**
- Plaintext password committed — recommend `secretProviderClass`.
- Secret name not referenced by `global.imagePullSecrets`.
- Wrong type — must be `kubernetes.io/dockerconfigjson`.

**Cross-refs:** `drunk-lib-secrets`, `drunk-lib-secretprovider`, `drunk-lib-serviceaccount`.

- [ ] Author, placeholder + frontmatter check, commit.

---

## Task 19: SKILL — drunk-lib-networkpolicy

**Files:**
- Read: `drunk-lib/templates/_networkPolicy.tpl`
- Create: `plugins/drunk-lib/skills/drunk-lib-networkpolicy/SKILL.md`

| Placeholder | Value |
|-------------|-------|
| `<RESOURCE-SLUG>` | `networkpolicy` |
| `<Resource>` | `NetworkPolicy` |
| `<file>` | `networkPolicy` |
| `<name>` | `networkpolicy` |
| `<gate>` | `networkPolicy.enabled` |
| Trigger keywords | `networkpolicy, netpol, ingress egress policy` |

**Values schema:** `networkPolicy.policyTypes`, `networkPolicy.ingress[]`, `networkPolicy.egress[]`, `networkPolicy.podSelector` (defaults to workload selector).

**Validate checklist:**
- `policyTypes: [Egress]` with no `egress` rules — locks all egress including DNS.
- Default-deny without an explicit DNS allow (port 53 to kube-system).
- Ingress rule allowing only a `namespaceSelector` that matches no namespaces.

**Cross-refs:** `drunk-lib-deployment`, `drunk-lib-statefulset`, `drunk-lib-service`.

- [ ] Author, placeholder + frontmatter check, commit.

---

## Task 20: SKILL — drunk-lib-serviceaccount

**Files:**
- Read: `drunk-lib/templates/_serviceAccount.tpl`
- Create: `plugins/drunk-lib/skills/drunk-lib-serviceaccount/SKILL.md`

| Placeholder | Value |
|-------------|-------|
| `<RESOURCE-SLUG>` | `serviceaccount` |
| `<Resource>` | `ServiceAccount` |
| `<file>` | `serviceAccount` |
| `<name>` | `serviceaccount` |
| `<gate>` | `serviceAccount.create` |
| Trigger keywords | `serviceaccount, sa, workload identity` |

**Values schema:** `serviceAccount.create`, `serviceAccount.name`, `serviceAccount.annotations` (e.g. workload identity), `serviceAccount.automountServiceAccountToken`.

**Validate checklist:**
- `create: false` but `name` references SA that doesn't exist.
- Workload identity annotation present but `automountServiceAccountToken: false`.
- Missing `azure.workload.identity/client-id` annotation when secretProviderClass uses Azure WI.

**Cross-refs:** `drunk-lib-deployment`, `drunk-lib-secretprovider`, `drunk-lib-imagepull-secret`.

- [ ] Author, placeholder + frontmatter check, commit.

---

## Task 21: SKILL — drunk-lib-volumes

**Files:**
- Read: `drunk-lib/templates/_volumes.tpl`
- Create: `plugins/drunk-lib/skills/drunk-lib-volumes/SKILL.md`

| Placeholder | Value |
|-------------|-------|
| `<RESOURCE-SLUG>` | `volumes` |
| `<Resource>` | `Volumes / PVC / emptyDir` |
| `<file>` | `volumes` |
| `<name>` | `volumes` |
| `<gate>` | `volumes[]` (list presence) |
| Trigger keywords | `volume, pvc, emptydir, persistentvolumeclaim, tmp volume` |

**Values schema:** `volumes[]` with `name`, `type` (`pvc` / `emptyDir` / `configMap` / `secret` / `csi`), `mountPath`, `subPath`, `readOnly`, plus type-specific keys (`pvc.size`, `pvc.storageClass`, `pvc.accessModes`, `emptyDir.medium`, `emptyDir.sizeLimit`).

**Validate checklist:**
- `readOnlyRootFilesystem: true` in container but no `tmp` emptyDir mounted at `/tmp`.
- PVC without `storageClass` on a cluster with no default class.
- `accessModes: [ReadWriteMany]` on a storage class that only supports RWO.
- ConfigMap/secret volume referencing names not declared elsewhere.

**Cross-refs:** `drunk-lib-deployment`, `drunk-lib-statefulset`, `drunk-lib-configmap`, `drunk-lib-secrets`, `drunk-lib-secretprovider`.

- [ ] Author, placeholder + frontmatter check, commit.

---

## Task 22: Plugin scaffolding script

**Files:**
- Create: `scripts/new-plugin.sh`

- [ ] **Step 1: Create the script**

Write `scripts/new-plugin.sh`:

```bash
#!/usr/bin/env bash
# scripts/new-plugin.sh — scaffold a new plugin under plugins/<name>/ and
# register it in .claude-plugin/marketplace.json.
#
# Usage: scripts/new-plugin.sh <plugin-name> "<description>"
set -euo pipefail

usage() {
  echo "Usage: $0 <plugin-name> \"<description>\"" >&2
  exit 64
}

[[ $# -eq 2 ]] || usage
NAME="$1"
DESC="$2"

if ! [[ "$NAME" =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo "error: plugin name must match ^[a-z][a-z0-9-]*$ (got: $NAME)" >&2
  exit 2
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

PLUGIN_DIR="plugins/$NAME"
MARKET=".claude-plugin/marketplace.json"

if [[ -e "$PLUGIN_DIR" ]]; then
  echo "error: $PLUGIN_DIR already exists" >&2
  exit 3
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required" >&2
  exit 4
fi

if jq -e --arg n "$NAME" '.plugins[]? | select(.name==$n)' "$MARKET" >/dev/null; then
  echo "error: plugin '$NAME' already in $MARKET" >&2
  exit 5
fi

AUTHOR="$(git config user.name || echo Unknown)"

mkdir -p "$PLUGIN_DIR/.claude-plugin" "$PLUGIN_DIR/skills/$NAME"

cat > "$PLUGIN_DIR/.claude-plugin/plugin.json" <<JSON
{
  "name": "$NAME",
  "version": "0.1.0",
  "description": "$DESC",
  "author": { "name": "$AUTHOR" },
  "repository": "https://github.com/baoduy/drunk.charts",
  "license": "MIT",
  "keywords": []
}
JSON

cat > "$PLUGIN_DIR/skills/$NAME/SKILL.md" <<MD
---
name: $NAME
description: "TODO — describe when this skill activates. Triggers on: <keywords>."
---

# $NAME

TODO — write the skill body. Use \`docs/superpowers/templates/SKILL.md.template\` as a starting point.
MD

# Atomic marketplace.json update via temp file
TMP="$(mktemp)"
jq --arg name "$NAME" --arg desc "$DESC" --arg src "./plugins/$NAME" '
  .plugins += [{
    "name": $name,
    "version": "0.1.0",
    "source": $src,
    "description": $desc
  }]
' "$MARKET" > "$TMP"
mv "$TMP" "$MARKET"

cat <<EOF
✅ Scaffolded plugins/$NAME

Next:
  1. Edit $PLUGIN_DIR/.claude-plugin/plugin.json (set keywords).
  2. Edit $PLUGIN_DIR/skills/$NAME/SKILL.md (use docs/superpowers/templates/SKILL.md.template).
  3. Run: bash scripts/new-plugin.sh --self-check  # or rely on CI workflow.
  4. git add plugins/$NAME .claude-plugin/marketplace.json && git commit
EOF
```

- [ ] **Step 2: Make executable**

```bash
chmod +x scripts/new-plugin.sh
```

- [ ] **Step 3: Smoke-test on a throwaway plugin (DO NOT COMMIT)**

```bash
bash scripts/new-plugin.sh test-plugin "scratch plugin for validation"
jq . .claude-plugin/marketplace.json > /dev/null
test -f plugins/test-plugin/.claude-plugin/plugin.json
test -f plugins/test-plugin/skills/test-plugin/SKILL.md
```
Expected: all three commands exit 0.

- [ ] **Step 4: Roll back the smoke test**

```bash
rm -rf plugins/test-plugin
git checkout -- .claude-plugin/marketplace.json
git status --short
```
Expected: working tree shows only `scripts/new-plugin.sh` as new file.

- [ ] **Step 5: Commit**

```bash
git add scripts/new-plugin.sh
git commit -m "tools: add scripts/new-plugin.sh plugin scaffolder"
```

---

## Task 23: CI validator workflow

**Files:**
- Create: `.github/workflows/validate-plugins.yml`

- [ ] **Step 1: Create the workflow**

Write `.github/workflows/validate-plugins.yml`:

```yaml
name: validate-plugins

on:
  pull_request:
    paths:
      - 'plugins/**'
      - '.claude-plugin/**'
      - 'scripts/new-plugin.sh'
      - '.github/workflows/validate-plugins.yml'
  push:
    branches: [main, dev]
    paths:
      - 'plugins/**'
      - '.claude-plugin/**'
      - 'scripts/new-plugin.sh'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install yq
        run: |
          sudo wget -qO /usr/local/bin/yq \
            https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
          sudo chmod +x /usr/local/bin/yq
          yq --version

      - name: Validate marketplace.json shape
        run: |
          set -euo pipefail
          M=.claude-plugin/marketplace.json
          jq -e '.name and .owner.name and (.plugins | type == "array") and (.plugins | length > 0)' "$M" \
            || { echo "::error file=$M::missing required top-level fields"; exit 1; }
          jq -e '.plugins | all(.name and .version and .source and .description)' "$M" \
            || { echo "::error file=$M::plugin entry missing name/version/source/description"; exit 1; }

      - name: Validate plugin sources exist
        run: |
          set -euo pipefail
          M=.claude-plugin/marketplace.json
          jq -r '.plugins[].source' "$M" | while read -r src; do
            test -d "$src" || { echo "::error::missing plugin dir: $src"; exit 1; }
            test -f "$src/.claude-plugin/plugin.json" || { echo "::error::missing plugin.json under: $src"; exit 1; }
          done

      - name: Validate plugin.json fields
        run: |
          set -euo pipefail
          find plugins -mindepth 2 -maxdepth 3 -name plugin.json -print0 | while IFS= read -r -d '' f; do
            jq -e '.name and .version and .description and .author.name' "$f" \
              || { echo "::error file=$f::plugin.json missing name/version/description/author.name"; exit 1; }
          done

      - name: Validate SKILL.md frontmatter
        run: |
          set -euo pipefail
          find plugins -path '*/skills/*/SKILL.md' -print0 | while IFS= read -r -d '' f; do
            # extract frontmatter between first two --- lines
            FM=$(awk 'NR==1 && /^---$/ {flag=1; next} /^---$/ && flag {exit} flag' "$f")
            if [[ -z "$FM" ]]; then
              echo "::error file=$f::missing YAML frontmatter"; exit 1
            fi
            NAME=$(echo "$FM" | yq -r '.name // ""')
            DESC=$(echo "$FM" | yq -r '.description // ""')
            [[ -n "$NAME" ]] || { echo "::error file=$f::frontmatter missing name"; exit 1; }
            [[ -n "$DESC" ]] || { echo "::error file=$f::frontmatter missing description"; exit 1; }
          done

      - name: Validate skill name uniqueness
        run: |
          set -euo pipefail
          DUPES=$(find plugins -path '*/skills/*/SKILL.md' -print0 \
            | xargs -0 -I{} sh -c "awk 'NR==1 && /^---$/ {flag=1; next} /^---$/ && flag {exit} flag' \"{}\" | yq -r '.name // \"\"'" \
            | sort | uniq -d)
          if [[ -n "$DUPES" ]]; then
            echo "::error::duplicate skill names: $DUPES"; exit 1
          fi
```

- [ ] **Step 2: Local dry-run of validation steps**

Reproduce each `run:` block locally against the current tree:

```bash
M=.claude-plugin/marketplace.json
jq -e '.name and .owner.name and (.plugins | type == "array") and (.plugins | length > 0)' "$M"
jq -e '.plugins | all(.name and .version and .source and .description)' "$M"
jq -r '.plugins[].source' "$M" | while read -r src; do test -d "$src" && test -f "$src/.claude-plugin/plugin.json"; done
find plugins -mindepth 2 -maxdepth 3 -name plugin.json -print0 | xargs -0 -I{} jq -e '.name and .version and .description and .author.name' {}
find plugins -path '*/skills/*/SKILL.md' | wc -l    # expect 19 (1 drunk-app + 18 drunk-lib)
```
Expected: all commands exit 0, count = 19.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/validate-plugins.yml
git commit -m "ci: validate marketplace.json, plugin.json, and SKILL.md frontmatter"
```

---

## Task 24: End-to-end verification

**Files:**
- Touch nothing; this is a verification pass.

- [ ] **Step 1: Re-run baseline test**

```bash
bash drunk-lib/verify.sh
```
Expected: same exit code and output as Task 1 step 3. The plugin work touched no Helm templates, so behavior must be identical.

- [ ] **Step 2: Confirm file inventory**

```bash
find plugins/drunk-lib -type f | sort
```
Expected output (exactly):

```
plugins/drunk-lib/.claude-plugin/plugin.json
plugins/drunk-lib/skills/drunk-lib-backend-tls-policy/SKILL.md
plugins/drunk-lib/skills/drunk-lib-configmap/SKILL.md
plugins/drunk-lib/skills/drunk-lib-cronjob/SKILL.md
plugins/drunk-lib/skills/drunk-lib-deployment/SKILL.md
plugins/drunk-lib/skills/drunk-lib-gateway/SKILL.md
plugins/drunk-lib/skills/drunk-lib-hpa/SKILL.md
plugins/drunk-lib/skills/drunk-lib-httproute/SKILL.md
plugins/drunk-lib/skills/drunk-lib-imagepull-secret/SKILL.md
plugins/drunk-lib/skills/drunk-lib-ingress/SKILL.md
plugins/drunk-lib/skills/drunk-lib-job/SKILL.md
plugins/drunk-lib/skills/drunk-lib-networkpolicy/SKILL.md
plugins/drunk-lib/skills/drunk-lib-secretprovider/SKILL.md
plugins/drunk-lib/skills/drunk-lib-secrets/SKILL.md
plugins/drunk-lib/skills/drunk-lib-service/SKILL.md
plugins/drunk-lib/skills/drunk-lib-serviceaccount/SKILL.md
plugins/drunk-lib/skills/drunk-lib-statefulset/SKILL.md
plugins/drunk-lib/skills/drunk-lib-tls-secrets/SKILL.md
plugins/drunk-lib/skills/drunk-lib-volumes/SKILL.md
```

That is 19 files (1 manifest + 18 skills).

- [ ] **Step 3: No-placeholders sweep across all SKILL.md**

```bash
grep -nE '<[A-Z][A-Za-z-]+>|TBD|TODO' plugins/drunk-lib/skills/*/SKILL.md && exit 1 || echo OK
```
Expected: `OK`. (Note: `TODO` should not appear in any committed `SKILL.md`; the scaffold script's stub is a separate, uncommitted artifact.)

- [ ] **Step 4: Unique skill names across the repo**

```bash
find plugins -path '*/skills/*/SKILL.md' -print0 \
  | xargs -0 -I{} sh -c "awk 'NR==1 && /^---$/ {flag=1; next} /^---\$/ && flag {exit} flag' {} | yq -r '.name'" \
  | sort | uniq -d
```
Expected: empty output.

- [ ] **Step 5: Trigger keyword sanity**

```bash
for slug in deployment statefulset cronjob job service ingress httproute gateway backend-tls-policy hpa configmap secrets tls-secrets secretprovider imagepull-secret networkpolicy serviceaccount volumes; do
  f="plugins/drunk-lib/skills/drunk-lib-$slug/SKILL.md"
  grep -q 'Triggers on:' "$f" || { echo "MISSING Triggers on in $f"; exit 1; }
done
echo OK
```
Expected: `OK`.

- [ ] **Step 6: Push branch and open PR (optional, on user instruction only)**

```bash
git push -u origin dev
gh pr create --title "feat: drunk-lib plugin with 18 per-template skills" --body "$(cat <<'EOF'
## Summary
- New `drunk-lib` plugin with 18 auto-activating per-template skills
- Scaffolding script `scripts/new-plugin.sh` for future plugins
- CI workflow `.github/workflows/validate-plugins.yml` validating marketplace + plugin.json + SKILL.md frontmatter

## Spec
- `docs/superpowers/specs/2026-05-14-drunk-lib-plugin-design.md`

## Test plan
- [ ] CI `validate-plugins` job passes
- [ ] `bash drunk-lib/verify.sh` matches pre-change baseline
- [ ] Manual smoke: install plugin from local marketplace, trigger each skill by keyword
EOF
)"
```

Only run Step 6 when the user explicitly asks to open a PR.

---

## Self-Review Notes (author)

- Spec §3 architecture covered by Tasks 3 + 4–21.
- Spec §4 skill anatomy covered by Task 2 (template) + Tasks 4–21 (substitutions).
- Spec §4.3 trigger keyword table replicated 1:1 across Tasks 4–21.
- Spec §5.1 scaffolder covered by Task 22.
- Spec §5.2 CI validator covered by Task 23.
- Spec §10 acceptance criteria covered by Task 24.
- No `<placeholder>`/TODO/TBD left in any committed file (Task 24 step 3 enforces).
- Skill name slugs are consistent: `drunk-lib-<slug>` used in every task header, frontmatter `name`, directory name, and verification grep.
