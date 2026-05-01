# drunk-app Docs & Plugin Design

**Date:** 2026-04-30  
**Status:** Approved  
**Scope:** Two deliverables — (1) comprehensive documentation rewrite for `drunk-app` helm chart, (2) a Claude Code plugin developers can install to get AI-assisted helm configuration help.

---

## 1. Background & Goals

The `drunk-app` Helm chart is a production-ready application chart that wraps `drunk-lib`. It currently has:
- `drunk-app/README.md` — parameter tables (ships with the chart)
- `docs/drunk-app.md` — a comprehensive guide (14.6K, 700 lines) that has gaps vs. the actual `values.example.yaml`

**Goal 1:** Fully rewrite `docs/drunk-app.md` using `values.example.yaml` as the source of truth, so every parameter is documented accurately — including currently undocumented ones like `deployment.strategy`, `tlsSecrets` file-based mode, `secretProvider.provider` multi-cloud structure, and the `volumes` map format.

**Goal 2:** Create a Claude Code plugin (`drunk-app`) that developers can install from the `drunk.charts` GitHub repo. When activated, Claude knows the entire drunk-app schema and can answer questions, generate values.yaml snippets, and validate configurations.

---

## 2. Deliverables

| # | File | Description |
|---|------|-------------|
| 1 | `docs/drunk-app.md` | Full rewrite — values-first comprehensive reference |
| 2 | `drunk-app/README.md` | Lean quickstart (~60 lines) pointing to `docs/drunk-app.md` |
| 3 | `plugins/drunk-app/skills/drunk-app/SKILL.md` | The Claude Code skill content |
| 4 | `plugins/drunk-app/.claude-plugin/plugin.json` | Plugin metadata |
| 5 | `.claude-plugin/marketplace.json` | Marketplace registry for the repo |

---

## 3. Documentation Design (`docs/drunk-app.md`)

### Approach: Values-First Reference

The entire document is structured around the top-level keys in `values.example.yaml`. Each section follows a consistent pattern:

```
### Section Name

Brief description of what this section controls.

| Parameter | Type | Default | Required | Description |
|-----------|------|---------|----------|-------------|
| ...       | ...  | ...     | ...      | ...         |

**Example:**
```yaml
...example from values.example.yaml...
```
```

### Document Structure

```
# Drunk App Helm Chart

## Table of Contents

## Overview
- What drunk-app is
- Relationship to drunk-lib (thin wrapper, all logic in drunk-lib templates)
- Chart version, Kubernetes requirements (1.19+, Helm 3.0+)

## Installation
- Add repo + helm install commands
- Install with custom values (-f my-values.yaml)
- Dependency update (helm dependency update ./drunk-app)

## Configuration Reference

### General
- nameOverride

### Image Credentials (imageCredentials)
- name, registry, username, password
- Note: creates a kubernetes.io/dockerconfigjson secret

### Global Settings (global)
- image, tag, imagePullPolicy, storageClassName, imagePullSecret
- initContainer (image, command)

### Environment Variables (env)
- Plain key-value pairs → injected as env vars via ConfigMap

### ConfigMap (configMap + configFrom)
- configMap: inline key-value config data
- configFrom: list of external ConfigMap names to mount from

### Secrets (secrets + secretFrom)
- secrets: inline key-value secret data (base64-encoded in the cluster)
- secretFrom: list of external Secret names to reference

### CSI Secret Provider (secretProvider)
- enabled, name (override)
- provider block: name (aws|azure|gcp), tenantId, vaultName, userAssignedIdentityID, usePodIdentity, useWorkloadIdentity
- objects[]: objectName, objectType, objectFormat, objectEncoding
- secretObjects[]: auto-generated if not provided

### TLS Secrets (tlsSecrets)
- Three modes:
  1. Inline (crt + key): base64-encoded certificate and key
  2. File-based (crtFile + keyFile + caFile): reads from local cert files
  3. CA-only (ca): disabled by default — not valid for kubernetes.io/tls without crt+key
- enabled flag per entry

### Deployment (deployment)
- enabled, replicaCount
- ports: http, tcp (https optional)
- liveness, readiness (path strings)
- command, args
- podAnnotations
- strategy: type (RollingUpdate|Recreate), maxSurge, maxUnavailable

### StatefulSet (statefulset)
- enabled, replicaCount
- ports: http, tcp
- liveness, readiness
- args, command
- podAnnotations
- Note: use volumes map for persistent storage with statefulsets

### CronJobs (cronJobs)
- List of: name, schedule (cron format), args, command, restartPolicy

### Jobs (jobs)
- List of: name, args, command, restartPolicy

### Volumes (volumes)
- Map format: key = volume name, value = config object
- PVC fields: size, storageClassName, accessMode, mountPath, subPath, readOnly
- EmptyDir: mountPath, readOnly, emptyDir: true
- global.storageClassName used as fallback if storageClassName omitted

### Service Account (serviceAccount)
- enabled, annotations

### Pod Settings
- podAnnotations
- podSecurityContext: fsGroup, runAsUser, runAsGroup
- securityContext: capabilities.drop, readOnlyRootFilesystem, allowPrivilegeEscalation, runAsNonRoot

### HTTPRoute — Gateway API (httpRoute)
- enabled
- parentRefs[]: name, namespace, sectionName
- tlsValidation.caCertificateRefs[]: group, kind, name
- hostnames[]
- Note: requires Gateway API CRDs + controller in cluster

### Ingress (ingress)
- enabled, className
- hosts[]: host, port
- tls (secret name)

### Resources (resources)
- limits: cpu, memory
- requests: cpu, memory

### Autoscaling (autoscaling)
- enabled, minReplicas, maxReplicas
- targetCPUUtilizationPercentage (optional)
- targetMemoryUtilizationPercentage

### Node Scheduling
- nodeSelector, tolerations, affinity

### Network Policies (networkPolicies / networkPolicy)
- Multiple policies (recommended): networkPolicies[] with name, enabled, policyTypes, podSelector, ingress, egress, labels, nameSuffix
- Legacy single policy: networkPolicy with policyTypes, podSelector, ingress, egress
- Note: requires CNI with NetworkPolicy support (Calico, Cilium, Weave Net)

## Usage Examples
1. Simple web application
2. Microservice with secrets + autoscaling
3. Cron-only / batch application (deployment.enabled: false)
4. StatefulSet with persistent volumes

## Troubleshooting & Debug Commands
- Pod not starting
- Image pull errors
- ConfigMap / secret issues
- Ingress not routing
- Common kubectl debug commands

## Contributing / License
```

### Gaps to surface from values.yaml (not in values.example.yaml)
- `service.type` — default `ClusterIP` from `values.yaml`; document in the Networking section with note that a ClusterIP Service is always created automatically
- `gateway` — not in `values.example.yaml`; document with a brief table (enabled, gatewayClassName, listeners[]) and a cross-reference to the `httpRoute` section and the drunk-app README Gateway API table

---

## 4. README Design (`drunk-app/README.md`)

Target: ~60 lines. Structure:

```
# Drunk App Helm Chart
[badges]

One-paragraph description.

## Prerequisites
- Kubernetes 1.19+, Helm 3.0+

## Installation
helm repo add / helm install commands

## Minimal Configuration
```yaml
# minimal values.yaml example
global:
  image: "myregistry/myapp"
  tag: "v1.0.0"
deployment:
  ports:
    http: 8080
```

## Key Features (bullet list)

## Full Documentation
→ See [docs/drunk-app.md](../docs/drunk-app.md) for the complete reference.

## Contributing / License
```

---

## 5. Plugin Design

### Installation (developer UX)

```bash
# Register drunk.charts as a plugin marketplace
plugin marketplace add baoduy/drunk.charts

# Install the drunk-app skill
plugin install drunk-app
```

### Repo Structure

```
drunk.charts/
├── .claude-plugin/
│   └── marketplace.json          ← repo-level marketplace registry
└── plugins/
    └── drunk-app/
        ├── .claude-plugin/
        │   └── plugin.json       ← plugin metadata
        └── skills/
            └── drunk-app/
                └── SKILL.md      ← skill content
```

### `.claude-plugin/marketplace.json`

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
    }
  ]
}
```

### `plugins/drunk-app/.claude-plugin/plugin.json`

```json
{
  "name": "drunk-app",
  "version": "1.0.0",
  "description": "AI assistant for configuring drunk-app Helm chart deployments — answers questions, generates values.yaml, validates configurations",
  "author": {
    "name": "Steven Hoang"
  },
  "repository": "https://github.com/baoduy/drunk.charts",
  "license": "MIT",
  "keywords": ["helm", "kubernetes", "drunk-app", "values", "configuration"]
}
```

### `SKILL.md` Structure

```
---
name: drunk-app
description: "Use when working with drunk-app Helm chart — configuring values.yaml, 
  understanding parameters, generating deployment configs, or validating settings."
---

# drunk-app Helm Assistant

[Trigger conditions]

## Schema Reference
[Complete parameter schema — every key, type, default, required flag]

## Common Patterns
[Answer templates for frequently asked questions]

## Generation Templates
[Ready-to-fill values.yaml for: web app, microservice, batch/cron, statefulset]

## Validation Checklist
[What Claude checks when the developer pastes their values.yaml]

## Known Gotchas
[volumes map vs array, tlsSecrets modes, secretProvider multi-cloud, etc.]
```

### SKILL.md Behaviour

| Mode | Trigger | Claude behaviour |
|------|---------|-----------------|
| **Answer** | "What does `deployment.strategy` do?" | Explains from schema with example |
| **Generate** | "Give me a values.yaml for a .NET API with Azure Key Vault" | Produces complete, correct values.yaml |
| **Validate** | User pastes values.yaml | Runs validation checklist, flags issues |

### Validation checklist (baked into skill)
1. `global.image` is set (required)
2. At least one workload is enabled (`deployment`, `statefulset`, or jobs/cronJobs)
3. `deployment.ports.http` matches what the app actually listens on
4. `secretProvider.enabled: true` → `provider.name` is set
5. `tlsSecrets` with `enabled: true` → has both `crt` and `key` (or both `crtFile` and `keyFile`)
6. `autoscaling.enabled: true` → `deployment.replicaCount` ≥ `autoscaling.minReplicas`
7. `networkPolicies` with egress rules → DNS egress (port 53 UDP) is allowed
8. `volumes` using PVC → `size` and `accessMode` are set
9. `securityContext.readOnlyRootFilesystem: true` → `/tmp` emptyDir volume is present
10. `imageCredentials` set → `global.imagePullSecret` matches `imageCredentials.name`

---

## 6. Implementation Order

1. Write `docs/drunk-app.md` — full rewrite
2. Write `drunk-app/README.md` — lean quickstart
3. Create `plugins/drunk-app/` structure — metadata files
4. Write `plugins/drunk-app/skills/drunk-app/SKILL.md` — skill content
5. Write `.claude-plugin/marketplace.json` — repo marketplace registry
6. Run `drunk-lib/verify.sh` to validate nothing broke
7. Commit all files

---

## 7. Out of Scope

- Generic multi-chart skill (each chart gets its own plugin if needed)
- Automated doc regeneration (docs are maintained manually, updated when values.example.yaml changes)
- CI/CD automation for plugin versioning
