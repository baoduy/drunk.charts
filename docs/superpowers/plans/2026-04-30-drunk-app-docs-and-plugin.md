# drunk-app Docs & Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite `docs/drunk-app.md` as a values-first comprehensive reference, update `drunk-app/README.md` as a lean quickstart, and create an installable Claude Code plugin (`drunk-app`) that acts as an AI assistant for developers using the chart.

**Architecture:** Five files are created or replaced. All content is derived from `values.example.yaml` (source of truth) and `values.yaml` (defaults). The plugin follows the `.claude-plugin/` manifest convention used by the official superpowers plugin: a `marketplace.json` at the repo root registers the marketplace, and a `plugin.json` inside each plugin's subdirectory provides metadata. Skills live at `plugins/<name>/skills/<name>/SKILL.md`.

**Tech Stack:** Markdown, JSON (plugin manifests), Helm YAML (examples embedded in docs). No build step — all files are static.

---

## File Map

| Action | Path | Purpose |
|--------|------|---------|
| Rewrite | `docs/drunk-app.md` | Full values-first reference (~500 lines) |
| Rewrite | `drunk-app/README.md` | Lean quickstart (~60 lines) pointing to full docs |
| Create | `.claude-plugin/marketplace.json` | Registers repo as plugin marketplace |
| Create | `plugins/drunk-app/.claude-plugin/plugin.json` | Plugin metadata |
| Create | `plugins/drunk-app/skills/drunk-app/SKILL.md` | Skill content (schema + generation + validation) |

---

## Task 1: Plugin Infrastructure Files

**Files:**
- Create: `.claude-plugin/marketplace.json`
- Create: `plugins/drunk-app/.claude-plugin/plugin.json`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p .claude-plugin
mkdir -p plugins/drunk-app/.claude-plugin
mkdir -p plugins/drunk-app/skills/drunk-app
```

- [ ] **Step 2: Write `.claude-plugin/marketplace.json`**

Write this file exactly:

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

- [ ] **Step 3: Write `plugins/drunk-app/.claude-plugin/plugin.json`**

Write this file exactly:

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

- [ ] **Step 4: Validate JSON files**

```bash
cat .claude-plugin/marketplace.json | python3 -m json.tool > /dev/null && echo "marketplace.json OK"
cat plugins/drunk-app/.claude-plugin/plugin.json | python3 -m json.tool > /dev/null && echo "plugin.json OK"
```

Expected: both print `OK` with no errors.

- [ ] **Step 5: Commit**

```bash
git add .claude-plugin/marketplace.json plugins/drunk-app/.claude-plugin/plugin.json
git commit -m "feat(plugin): add drunk-app Claude Code plugin infrastructure"
```

---

## Task 2: Rewrite `docs/drunk-app.md`

**Files:**
- Rewrite: `docs/drunk-app.md`

- [ ] **Step 1: Write `docs/drunk-app.md` with the full content below**

Write this file exactly (replace all existing content):

````markdown
# Drunk App Helm Chart

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/drunk-app)](https://artifacthub.io/packages/search?repo=drunk-app)

The **drunk-app** Helm chart provides a production-ready framework for deploying applications on Kubernetes. It is a thin wrapper over the [`drunk-lib`](../drunk-lib) library chart — every template in [`templates/`](../drunk-app/templates/) is a single-line include of a `drunk-lib.<name>` named template.

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Configuration Reference](#configuration-reference)
  - [nameOverride](#nameoverride)
  - [imageCredentials](#imagecredentials)
  - [global](#global)
  - [env](#env)
  - [configMap & configFrom](#configmap--configfrom)
  - [secrets & secretFrom](#secrets--secretfrom)
  - [secretProvider](#secretprovider)
  - [tlsSecrets](#tlssecrets)
  - [deployment](#deployment)
  - [statefulset](#statefulset)
  - [cronJobs](#cronjobs)
  - [jobs](#jobs)
  - [volumes](#volumes)
  - [serviceAccount](#serviceaccount)
  - [Pod Settings](#pod-settings)
  - [service](#service)
  - [httpRoute](#httproute)
  - [gateway](#gateway)
  - [ingress](#ingress)
  - [resources](#resources)
  - [autoscaling](#autoscaling)
  - [Node Scheduling](#node-scheduling)
  - [networkPolicies](#networkpolicies)
- [Usage Examples](#usage-examples)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

---

## Overview

### Architecture

`drunk-app` is an **application chart** — a thin wrapper over [`drunk-lib`](../drunk-lib). Each template in `templates/` delegates all rendering to a `drunk-lib.<name>` named template. This means all logic lives in `drunk-lib`, and upgrading `drunk-lib` automatically improves all dependent apps.

```yaml
# Chart.yaml (excerpt)
dependencies:
  - name: drunk-lib
    version: 1.x.x
    repository: "file://../drunk-lib"
```

After pulling a new `drunk-lib` version, run:

```bash
helm dependency update ./drunk-app
```

### Key Features

- 🚀 **Deployment & StatefulSet** — choose the right workload type for your app
- ⚙️ **CronJobs & Jobs** — scheduled and one-time batch tasks
- 🔑 **Secrets Management** — inline secrets, external refs, CSI Secrets Store (Azure/AWS/GCP)
- 🔒 **TLS** — inline base64, file-based, or CA-only certificate modes
- 🌐 **Ingress & Gateway API** — classic Ingress or modern HTTPRoute
- 📈 **HPA** — CPU and memory-based autoscaling
- 🛡️ **Network Policies** — named, multiple policies with fine-grained rules
- 💾 **Storage** — PVC map and emptyDir volumes

---

## Installation

### Prerequisites

- Kubernetes 1.19+
- Helm 3.0+

### Add Repository

```bash
helm repo add drunk-charts https://baoduy.github.io/drunk.charts/drunk-app
helm repo update
```

### Install

```bash
# Basic install
helm install my-app drunk-charts/drunk-app

# Install with custom values
helm install my-app drunk-charts/drunk-app -f my-values.yaml

# Upgrade
helm upgrade my-app drunk-charts/drunk-app -f my-values.yaml

# Preview rendered manifests
helm template my-app drunk-charts/drunk-app -f my-values.yaml
```

---

## Configuration Reference

All parameters are documented below in the same order they appear in [`values.example.yaml`](values.example.yaml), which is the canonical reference covering every feature.

---

### nameOverride

Overrides the chart name used in resource labels and naming.

> **Note:** Do not use `fullnameOverride` — update the chart name directly instead.

| Parameter | Type | Default | Required |
|-----------|------|---------|----------|
| `nameOverride` | string | `""` | ❌ |

```yaml
nameOverride: "my-app"
```

---

### imageCredentials

Creates a `kubernetes.io/dockerconfigjson` pull secret for private container registries.

| Parameter | Type | Default | Required | Description |
|-----------|------|---------|----------|-------------|
| `imageCredentials.name` | string | `""` | ✅ (if set) | Pull secret resource name |
| `imageCredentials.registry` | string | `""` | ✅ (if set) | Registry URL |
| `imageCredentials.username` | string | `""` | ✅ (if set) | Registry username |
| `imageCredentials.password` | string | `""` | ✅ (if set) | Registry password |

```yaml
imageCredentials:
  name: "my-registry-secret"
  registry: "myregistry.example.com"
  username: "ci-user"
  password: "ci-token"
```

> Set `global.imagePullSecret` to the same value as `imageCredentials.name` to wire the secret to your pods.

---

### global

Settings that apply to all containers in the deployment.

| Parameter | Type | Default | Required | Description |
|-----------|------|---------|----------|-------------|
| `global.image` | string | `""` | ✅ | Container image repository |
| `global.tag` | string | `"latest"` | ❌ | Image tag |
| `global.imagePullPolicy` | string | `"IfNotPresent"` | ❌ | `Always`, `IfNotPresent`, or `Never` |
| `global.storageClassName` | string | `""` | ❌ | Default storage class for PVCs |
| `global.imagePullSecret` | string | `""` | ❌ | Pull secret name (must exist in namespace) |

#### Init Container

Runs before the main container starts. Useful for migrations, config generation, or dependency checks.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `global.initContainer.image` | string | `""` | Init container image |
| `global.initContainer.command` | string[] | `[]` | Command to run |

```yaml
global:
  image: "myregistry/myapp"
  tag: "v1.2.3"
  imagePullPolicy: "IfNotPresent"
  storageClassName: "fast-ssd"
  imagePullSecret: "my-registry-secret"
  initContainer:
    image: "myregistry/init-tool"
    command: ["sh", "-c", "echo Init complete;"]
```

---

### env

Plain environment variables injected directly into the container via a ConfigMap. Both keys and values are strings.

```yaml
env:
  NODE_ENV: "production"
  PORT: "8080"
  LOG_LEVEL: "info"
```

---

### configMap & configFrom

#### configMap

Key-value entries stored in a Kubernetes ConfigMap and injected as environment variables.

```yaml
configMap:
  APP_TIMEOUT: "30"
  FEATURE_FLAG: "enabled"
```

#### configFrom

Reference existing ConfigMaps by name to inject all their keys as environment variables into the container.

```yaml
configFrom:
  - "shared-config"
  - "environment-config"
```

---

### secrets & secretFrom

#### secrets

Inline secrets stored in a Kubernetes Secret (base64-encoded at rest in etcd).

> ⚠️ Do not commit plaintext secrets to source control. Use `secretProvider` for production workloads.

```yaml
secrets:
  DATABASE_PASSWORD: "my-password"
  API_KEY: "my-api-key"
```

#### secretFrom

Reference existing Secrets by name to inject all their keys as environment variables.

```yaml
secretFrom:
  - "database-credentials"
  - "external-api-keys"
```

---

### secretProvider

Wires the [CSI Secrets Store](https://secrets-store-csi-driver.sigs.k8s.io/) driver to fetch secrets from an external vault. Renders a `SecretProviderClass` resource. Auto-generates `secretObjects` from `objects[]` if not provided.

#### Top-level

| Parameter | Type | Default | Required | Description |
|-----------|------|---------|----------|-------------|
| `secretProvider.enabled` | bool | `false` | ❌ | Render the `SecretProviderClass` |
| `secretProvider.name` | string | `<app>-spc` | ❌ | Override the resource name |

#### provider

| Parameter | Type | Default | Required | Description |
|-----------|------|---------|----------|-------------|
| `secretProvider.provider.name` | string | `"azure"` | ✅ | Cloud provider: `azure`, `aws`, or `gcp` |
| `secretProvider.provider.tenantId` | string | `""` | ❌ | Azure tenant ID |
| `secretProvider.provider.vaultName` | string | `""` | ✅ | Vault or secrets store name |
| `secretProvider.provider.userAssignedIdentityID` | string | `""` | ❌ | Azure user-assigned managed identity |
| `secretProvider.provider.usePodIdentity` | bool | `false` | ❌ | Use AAD Pod Identity (Azure, legacy) |
| `secretProvider.provider.useWorkloadIdentity` | bool | `false` | ❌ | Use Workload Identity (recommended) |

#### objects[]

Each entry maps to one secret or certificate in the vault.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `objectName` | string | ✅ | Secret name in the vault |
| `objectType` | string | ✅ | `secret`, `cert`, or `key` |
| `objectFormat` | string | ❌ | `pem` or `pfx` (for certs) |
| `objectEncoding` | string | ❌ | `base64` or `utf-8` |

```yaml
secretProvider:
  enabled: true
  name: "my-secret-class"
  provider:
    name: aws
    vaultName: "my-secrets-store"
    useWorkloadIdentity: true
  objects:
    - objectName: db-password
      objectType: secret
    - objectName: tls-cert
      objectType: cert
      objectFormat: pfx
      objectEncoding: base64
```

---

### tlsSecrets

Creates `kubernetes.io/tls` Kubernetes Secrets for TLS termination. Supports three modes per named entry.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `tlsSecrets.<name>.enabled` | bool | `false` | Create this Secret |
| `tlsSecrets.<name>.crt` | string | `""` | Base64-encoded certificate |
| `tlsSecrets.<name>.key` | string | `""` | Base64-encoded private key |
| `tlsSecrets.<name>.crtFile` | string | `""` | Path to cert file (read at render time) |
| `tlsSecrets.<name>.keyFile` | string | `""` | Path to key file (read at render time) |
| `tlsSecrets.<name>.caFile` | string | `""` | Path to CA file (optional, file mode) |
| `tlsSecrets.<name>.ca` | string | `""` | Base64-encoded CA certificate (CA-only mode) |

#### Mode 1: Inline base64

```yaml
tlsSecrets:
  cloudflare:
    enabled: true
    crt: "<base64-encoded-certificate>"
    key: "<base64-encoded-private-key>"
```

#### Mode 2: File-based (reads cert files from disk at `helm template`/`install` time)

```yaml
tlsSecrets:
  my-cert:
    enabled: true
    crtFile: "certs/my.crt"
    keyFile: "certs/my.key"
    caFile: "certs/my-ca.crt"   # optional
```

#### Mode 3: CA-only (disabled by default)

> ⚠️ CA-only entries are not valid for `kubernetes.io/tls`, which requires both `tls.crt` and `tls.key`. Set `enabled: false` unless you provide `crt`+`key` as well.

```yaml
tlsSecrets:
  dev-ca:
    enabled: false
    ca: "<base64-encoded-ca-certificate>"
```

---

### deployment

Controls the main `Deployment` resource.

| Parameter | Type | Default | Required | Description |
|-----------|------|---------|----------|-------------|
| `deployment.enabled` | bool | `true` | ❌ | Render the Deployment. Set `false` for cron-only apps |
| `deployment.replicaCount` | int | `1` | ❌ | Desired number of replicas |
| `deployment.ports.http` | int | `8080` | ❌ | HTTP container port |
| `deployment.ports.tcp` | int | — | ❌ | Additional TCP container port |
| `deployment.liveness` | string | `""` | ❌ | HTTP path for liveness probe (e.g. `/healthz`) |
| `deployment.readiness` | string | `""` | ❌ | HTTP path for readiness probe |
| `deployment.command` | string[] | `[]` | ❌ | Override container entrypoint |
| `deployment.args` | string[] | `[]` | ❌ | Container arguments |
| `deployment.podAnnotations` | object | `{}` | ❌ | Annotations added to each pod |

#### Rolling Update Strategy

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `deployment.strategy.type` | string | `"RollingUpdate"` | `RollingUpdate` or `Recreate` |
| `deployment.strategy.maxSurge` | string | `"1"` | Max pods above desired count during a rolling update |
| `deployment.strategy.maxUnavailable` | string | `"1"` | Max pods unavailable during a rolling update |

> `maxSurge` and `maxUnavailable` are ignored when `strategy.type: Recreate`.

```yaml
deployment:
  enabled: true
  replicaCount: 2
  ports:
    http: 8080
    tcp: 9090
  liveness: "/healthz"
  readiness: "/healthz/ready"
  args:
    - "--config"
    - "/app/config.yaml"
  podAnnotations:
    prometheus.io/scrape: "true"
  strategy:
    type: "RollingUpdate"
    maxSurge: "1"
    maxUnavailable: "0"
```

---

### statefulset

Controls a `StatefulSet` resource. Use for workloads requiring stable network identity or ordered pod management (databases, queues).

> Enable either `deployment` or `statefulset`, not both simultaneously.

| Parameter | Type | Default | Required | Description |
|-----------|------|---------|----------|-------------|
| `statefulset.enabled` | bool | `false` | ❌ | Render the StatefulSet |
| `statefulset.replicaCount` | int | `1` | ❌ | Number of replicas |
| `statefulset.ports.http` | int | `8080` | ❌ | HTTP container port |
| `statefulset.ports.tcp` | int | — | ❌ | Additional TCP container port |
| `statefulset.liveness` | string | `""` | ❌ | HTTP path for liveness probe |
| `statefulset.readiness` | string | `""` | ❌ | HTTP path for readiness probe |
| `statefulset.command` | string[] | `[]` | ❌ | Override container entrypoint |
| `statefulset.args` | string[] | `[]` | ❌ | Container arguments |
| `statefulset.podAnnotations` | object | `{}` | ❌ | Annotations added to each pod |

```yaml
statefulset:
  enabled: true
  replicaCount: 3
  ports:
    http: 8080
  liveness: "/healthz"
  podAnnotations:
    app.kubernetes.io/component: "database"
```

---

### cronJobs

A list of `CronJob` resources. Each uses the global image unless overridden at the job level.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `cronJobs[].name` | string | ✅ | Job name — must be unique within the chart |
| `cronJobs[].schedule` | string | ✅ | Cron schedule expression (e.g. `"0 2 * * *"`) |
| `cronJobs[].command` | string[] | ❌ | Entrypoint command |
| `cronJobs[].args` | string[] | ❌ | Command arguments |
| `cronJobs[].restartPolicy` | string | `"OnFailure"` | `OnFailure`, `Never`, or `Always` |

```yaml
cronJobs:
  - name: "daily-backup"
    schedule: "0 2 * * *"
    command: ["/app/backup.sh"]
    restartPolicy: OnFailure
  - name: "weekly-cleanup"
    schedule: "0 4 * * 0"
    args:
      - "--purge"
      - "--older-than=30d"
    restartPolicy: OnFailure
```

---

### jobs

A list of one-time `Job` resources. Useful for database migrations or data seeding on deploy.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `jobs[].name` | string | ✅ | Job name — must be unique within the chart |
| `jobs[].command` | string[] | ❌ | Entrypoint command |
| `jobs[].args` | string[] | ❌ | Command arguments |
| `jobs[].restartPolicy` | string | `"OnFailure"` | `OnFailure` or `Never` |

```yaml
jobs:
  - name: "db-migrate"
    command: ["/app/migrate.sh"]
    restartPolicy: OnFailure
  - name: "seed-data"
    args: ["--seed", "--env=production"]
```

---

### volumes

A **map** of volumes to mount into the containers. The map key becomes the PVC name or emptyDir identifier.

#### PVC Volume

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `<name>.size` | string | ✅ | PVC size (e.g. `"2Gi"`) |
| `<name>.accessMode` | string | ✅ | `ReadWriteOnce`, `ReadWriteMany`, or `ReadOnlyMany` |
| `<name>.mountPath` | string | ✅ | Absolute mount path inside the container |
| `<name>.storageClassName` | string | ❌ | Overrides `global.storageClassName` |
| `<name>.subPath` | string | ❌ | Mount only this sub-path within the volume |
| `<name>.readOnly` | bool | `false` | Mount as read-only |

#### EmptyDir Volume

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `<name>.mountPath` | string | ✅ | Absolute mount path inside the container |
| `<name>.emptyDir` | bool | ✅ | Must be `true` |
| `<name>.readOnly` | bool | `false` | Mount as read-only |

```yaml
volumes:
  app-data:
    size: "10Gi"
    storageClassName: "fast-ssd"
    accessMode: "ReadWriteOnce"
    mountPath: "/app/data"
    subPath: "myapp"
    readOnly: false
  logs:
    size: "2Gi"
    accessMode: "ReadWriteOnce"
    mountPath: "/var/log/app"
  tmp:
    mountPath: "/tmp"
    readOnly: false
    emptyDir: true
```

> **Required when `readOnlyRootFilesystem: true`** (the default): always add a `tmp` emptyDir so the container can write temporary files.

> **Common mistake:** `volumes` is a **map** (key → object), not an array. Do not write `- name: tmp`. Write `tmp:` as a key.

---

### serviceAccount

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `serviceAccount.enabled` | bool | `false` | Create a dedicated ServiceAccount |
| `serviceAccount.annotations` | object | `{}` | Annotations (e.g. IRSA, Workload Identity bindings) |

```yaml
serviceAccount:
  enabled: true
  annotations:
    iam.gke.io/gcp-service-account: "my-app@project.iam.gserviceaccount.com"
```

---

### Pod Settings

#### podAnnotations

Annotations applied to all pods created by this chart.

```yaml
podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
```

#### podSecurityContext

Security context applied at the **pod** level.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `podSecurityContext.fsGroup` | int | `10000` | File system group for mounted volumes |
| `podSecurityContext.runAsUser` | int | `10000` | UID to run the container as |
| `podSecurityContext.runAsGroup` | int | `10000` | GID to run the container as |

#### securityContext

Security context applied at the **container** level.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `securityContext.capabilities.drop` | string[] | `["ALL"]` | Linux capabilities to drop |
| `securityContext.readOnlyRootFilesystem` | bool | `true` | Mount the root filesystem read-only |
| `securityContext.allowPrivilegeEscalation` | bool | `false` | Prevent privilege escalation |
| `securityContext.runAsNonRoot` | bool | `true` | Refuse to run as UID 0 |

```yaml
podSecurityContext:
  fsGroup: 10000
  runAsUser: 10000
  runAsGroup: 10000

securityContext:
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  runAsNonRoot: true
```

---

### service

A `ClusterIP` Service is always created automatically. Override the type if external access is needed without an Ingress.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `service.type` | string | `"ClusterIP"` | `ClusterIP`, `NodePort`, or `LoadBalancer` |

```yaml
service:
  type: ClusterIP
```

---

### httpRoute

Creates an [HTTPRoute](https://gateway-api.sigs.k8s.io/api-types/httproute/) resource for the Kubernetes Gateway API.

> **Prerequisite:** A Gateway API controller must be installed (e.g. NGINX Gateway Fabric, Cilium, Istio).

| Parameter | Type | Default | Required | Description |
|-----------|------|---------|----------|-------------|
| `httpRoute.enabled` | bool | `false` | ❌ | Render the HTTPRoute |
| `httpRoute.parentRefs[]` | object[] | `[]` | ✅ (if enabled) | Gateways to attach to |
| `httpRoute.parentRefs[].name` | string | — | ✅ | Gateway resource name |
| `httpRoute.parentRefs[].namespace` | string | — | ✅ | Gateway namespace |
| `httpRoute.parentRefs[].sectionName` | string | — | ❌ | Listener name on the Gateway |
| `httpRoute.hostnames[]` | string[] | `[]` | ❌ | Hostname matches for routing |
| `httpRoute.tlsValidation.caCertificateRefs[]` | object[] | `[]` | ❌ | CA refs for backend TLS validation |

```yaml
httpRoute:
  enabled: true
  parentRefs:
    - name: my-gateway
      namespace: gateway-system
      sectionName: https
  tlsValidation:
    caCertificateRefs:
      - group: ""
        kind: ConfigMap
        name: cloudflare-origin-ca
  hostnames:
    - "myapp.example.com"
```

---

### gateway

Creates a `Gateway` resource for the Kubernetes Gateway API. Typically managed at the infrastructure level — use `httpRoute` for application-level routing.

| Parameter | Type | Default | Required | Description |
|-----------|------|---------|----------|-------------|
| `gateway.enabled` | bool | `false` | ❌ | Render the Gateway |
| `gateway.gatewayClassName` | string | — | ✅ (if enabled) | GatewayClass to bind to |
| `gateway.listeners[]` | object[] | `[]` | ✅ (if enabled) | Listener specifications |

See [`drunk-app/README.md`](../drunk-app/README.md#gateway-api-gateway--httproute) for the `listeners[]` schema.

---

### ingress

Classic `Ingress` resource for external HTTP/HTTPS routing.

| Parameter | Type | Default | Required | Description |
|-----------|------|---------|----------|-------------|
| `ingress.enabled` | bool | `false` | ❌ | Render the Ingress |
| `ingress.className` | string | `""` | ❌ | Ingress class (e.g. `nginx`) |
| `ingress.hosts[]` | object[] | `[]` | ✅ (if enabled) | Host routing rules |
| `ingress.hosts[].host` | string | — | ✅ | Hostname |
| `ingress.hosts[].port` | int | — | ✅ | Backend service port |
| `ingress.tls` | string | `""` | ❌ | TLS Secret name |

```yaml
ingress:
  enabled: true
  className: nginx
  hosts:
    - host: myapp.example.com
      port: 8080
    - host: api.example.com
      port: 9090
  tls: myapp-tls
```

---

### resources

CPU and memory requests and limits for the main container.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `resources.limits.cpu` | string | `"100m"` | CPU limit |
| `resources.limits.memory` | string | `"128Mi"` | Memory limit |
| `resources.requests.cpu` | string | `"100m"` | CPU request |
| `resources.requests.memory` | string | `"128Mi"` | Memory request |

```yaml
resources:
  limits:
    cpu: "500m"
    memory: "512Mi"
  requests:
    cpu: "100m"
    memory: "128Mi"
```

---

### autoscaling

Horizontal Pod Autoscaler (HPA). When enabled, `replicaCount` sets the initial replica count and HPA manages scaling within `minReplicas`/`maxReplicas`.

| Parameter | Type | Default | Required | Description |
|-----------|------|---------|----------|-------------|
| `autoscaling.enabled` | bool | `false` | ❌ | Create an HPA resource |
| `autoscaling.minReplicas` | int | `1` | ❌ | Minimum replica count |
| `autoscaling.maxReplicas` | int | `100` | ❌ | Maximum replica count |
| `autoscaling.targetCPUUtilizationPercentage` | int | — | ❌ | Target CPU utilisation (%) |
| `autoscaling.targetMemoryUtilizationPercentage` | int | — | ❌ | Target memory utilisation (%) |

```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
```

---

### Node Scheduling

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `nodeSelector` | object | `{}` | Node label selector |
| `tolerations` | object[] | `[]` | Pod tolerations |
| `affinity` | object | `{}` | Pod/node affinity rules |

```yaml
nodeSelector:
  kubernetes.io/arch: "amd64"

tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "app"
    effect: "NoSchedule"

affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
              - key: app
                operator: In
                values:
                  - my-app
          topologyKey: kubernetes.io/hostname
```

---

### networkPolicies

Controls pod-level network access. Requires a CNI plugin that supports NetworkPolicy (Calico, Cilium, Weave Net).

#### Multiple Policies — Recommended

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `networkPolicies[].name` | string | ✅ | Policy name (used in resource naming) |
| `networkPolicies[].enabled` | bool | `true` | Enable/disable this individual policy |
| `networkPolicies[].policyTypes` | string[] | ✅ | `["Ingress"]`, `["Egress"]`, or `["Ingress","Egress"]` |
| `networkPolicies[].podSelector` | object | App labels | Custom pod selector |
| `networkPolicies[].ingress` | object[] | `[]` | Ingress rules |
| `networkPolicies[].egress` | object[] | `[]` | Egress rules |
| `networkPolicies[].labels` | object | `{}` | Additional labels on the resource |
| `networkPolicies[].nameSuffix` | string | `-<name>` | Custom name suffix |

```yaml
networkPolicies:
  - name: allow-all-ingress-restrict-egress
    enabled: true
    policyTypes:
      - Ingress
      - Egress
    ingress:
      - {}   # Allow all ingress
    egress:
      - to:
          - ipBlock:
              cidr: 192.168.253.253/32
      # Always include DNS when restricting egress
      - to:
          - namespaceSelector:
              matchLabels:
                kubernetes.io/metadata.name: kube-system
        ports:
          - protocol: UDP
            port: 53
```

#### Legacy Single Policy (backward-compatible)

Prefer `networkPolicies[]` for new deployments.

```yaml
networkPolicy:
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
      - podSelector:
          matchLabels:
            app: allowed-app
  egress:
    - to:
      - namespaceSelector: {}
```

---

## Usage Examples

### Simple Web Application

```yaml
nameOverride: "my-web-app"

global:
  image: "nginx"
  tag: "1.25"

deployment:
  ports:
    http: 80
  liveness: "/"

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: "www.example.com"
      port: 80

volumes:
  tmp:
    mountPath: "/tmp"
    emptyDir: true

resources:
  limits:
    cpu: "200m"
    memory: "256Mi"
  requests:
    cpu: "50m"
    memory: "64Mi"
```

### Microservice with Secrets and Autoscaling

```yaml
nameOverride: "payment-api"

global:
  image: "myregistry/payment-api"
  tag: "v2.1.0"
  imagePullSecret: "my-registry-secret"

imageCredentials:
  name: "my-registry-secret"
  registry: "myregistry.example.com"
  username: "ci-user"
  password: "ci-token"

env:
  NODE_ENV: "production"
  PORT: "8080"

secrets:
  STRIPE_SECRET_KEY: "sk_live_..."
  DATABASE_URL: "postgresql://..."

deployment:
  ports:
    http: 8080
  liveness: "/health"
  readiness: "/ready"
  strategy:
    type: "RollingUpdate"
    maxSurge: "1"
    maxUnavailable: "0"

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 20
  targetMemoryUtilizationPercentage: 80

volumes:
  tmp:
    mountPath: "/tmp"
    emptyDir: true

resources:
  limits:
    cpu: "500m"
    memory: "512Mi"
  requests:
    cpu: "100m"
    memory: "128Mi"
```

### Cron-Only / Batch Application

```yaml
nameOverride: "data-processor"

global:
  image: "myregistry/processor"
  tag: "latest"

deployment:
  enabled: false

cronJobs:
  - name: "daily-etl"
    schedule: "0 1 * * *"
    command: ["/app/etl.sh"]
    restartPolicy: OnFailure
  - name: "weekly-report"
    schedule: "0 8 * * 1"
    args: ["--report", "--email=team@example.com"]
    restartPolicy: OnFailure

volumes:
  workspace:
    size: "20Gi"
    accessMode: "ReadWriteOnce"
    mountPath: "/workspace"
  tmp:
    mountPath: "/tmp"
    emptyDir: true
```

### StatefulSet with Persistent Storage

```yaml
nameOverride: "postgres"

global:
  image: "postgres"
  tag: "15"

deployment:
  enabled: false

statefulset:
  enabled: true
  replicaCount: 1
  ports:
    tcp: 5432

secrets:
  POSTGRES_PASSWORD: "mypassword"
  POSTGRES_DB: "appdb"

volumes:
  pgdata:
    size: "50Gi"
    storageClassName: "fast-ssd"
    accessMode: "ReadWriteOnce"
    mountPath: "/var/lib/postgresql/data"
    subPath: "pgdata"
  tmp:
    mountPath: "/tmp"
    emptyDir: true

networkPolicies:
  - name: allow-app-only
    enabled: true
    policyTypes:
      - Ingress
    ingress:
      - from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: payment-api
        ports:
        - protocol: TCP
          port: 5432
```

---

## Troubleshooting

### Pod Not Starting

```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous
```

**Common causes:**

- Wrong image name or tag → check `global.image` and `global.tag`
- Image pull failure → verify `imageCredentials` and `global.imagePullSecret` match
- Read-only root filesystem error → add a `tmp` emptyDir volume
- Missing PVC → ensure `storageClassName` is valid and the StorageClass exists

### ConfigMap / Secret Not Injected

```bash
kubectl get configmap -l app.kubernetes.io/name=<app-name>
kubectl exec <pod-name> -- env | grep MY_VAR
```

### Ingress Not Routing

```bash
kubectl describe ingress -l app.kubernetes.io/name=<app-name>
kubectl get events --sort-by=.metadata.creationTimestamp
```

### NetworkPolicy Blocking Traffic

```bash
# List active policies
kubectl get networkpolicy -n <namespace>
# Test DNS from pod (breaks first when egress is restricted)
kubectl exec <pod-name> -- nslookup kubernetes.default
```

### Debug Commands

```bash
# All resources for this app
kubectl get all -l app.kubernetes.io/name=<app-name>

# Live pod logs
kubectl logs -f deployment/<app-name>

# Preview rendered manifests without installing
helm template my-app drunk-charts/drunk-app -f my-values.yaml
```

---

## Contributing

Contributions are welcome! For questions or issues, open a [GitHub issue](https://github.com/baoduy/drunk.charts/issues).

If you need an unsupported resource type, prefer adding a named template to `drunk-lib` (so all consumers benefit) rather than inlining it in `drunk-app`.

## License

MIT License — [Steven Hoang](https://drunkcoding.net)
````

- [ ] **Step 2: Verify the file was written**

```bash
wc -l docs/drunk-app.md
```

Expected: approximately 500–560 lines.

- [ ] **Step 3: Commit**

```bash
git add docs/drunk-app.md
git commit -m "docs(drunk-app): rewrite as values-first comprehensive reference"
```

---

## Task 3: Rewrite `drunk-app/README.md`

**Files:**
- Rewrite: `drunk-app/README.md`

- [ ] **Step 1: Write `drunk-app/README.md` with the full content below**

Write this file exactly (replace all existing content):

```markdown
# Drunk App Helm Chart

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/drunk-app)](https://artifacthub.io/packages/search?repo=drunk-app)

The **drunk-app** Helm chart is a production-ready framework for deploying applications on Kubernetes. Built as a thin wrapper over [`drunk-lib`](../drunk-lib), it handles Deployments, StatefulSets, CronJobs, Jobs, Ingress, Gateway API, TLS, Secrets, Volumes, and HPA from a single `values.yaml`.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+

## Installation

```bash
helm repo add drunk-charts https://baoduy.github.io/drunk.charts/drunk-app
helm repo update
helm install my-app drunk-charts/drunk-app -f my-values.yaml
```

## Minimal Configuration

```yaml
global:
  image: "myregistry/myapp"
  tag: "v1.0.0"

deployment:
  ports:
    http: 8080
  liveness: "/healthz"

volumes:
  tmp:
    mountPath: "/tmp"
    emptyDir: true
```

## Key Features

- **Deployment & StatefulSet** — choose the right workload type
- **CronJobs & Jobs** — scheduled and one-time batch tasks
- **Environment & Config** — env vars, ConfigMaps, external ConfigMap references
- **Secrets** — inline secrets, external references, CSI Secrets Store (Azure/AWS/GCP)
- **TLS** — inline base64, file-based, or CA-only certificate modes
- **Ingress & Gateway API** — classic Ingress or HTTPRoute with parentRef
- **HPA** — CPU and memory-based autoscaling
- **Network Policies** — multiple named policies with fine-grained ingress/egress rules
- **Storage** — PVC map and emptyDir volumes
- **Security** — non-root, read-only root filesystem, capability drops by default

## Built on drunk-lib

Every template in [`templates/`](templates/) is a one-line include of a `drunk-lib.<name>` named template. All rendering logic lives in `drunk-lib`.

```bash
# Refresh drunk-lib after a version bump
helm dependency update ./drunk-app
```

## Gateway API (Gateway + HTTPRoute)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `gateway.enabled` | Render the `Gateway` resource | `false` |
| `gateway.gatewayClassName` | GatewayClass to bind to | — |
| `gateway.listeners[]` | Listener specifications | `[]` |
| `httpRoute.enabled` | Render the `HTTPRoute` resource | `false` |
| `httpRoute.parentRefs[]` | Gateways to attach to | `[]` |
| `httpRoute.hostnames[]` | Hostname matches | `[]` |

## Full Documentation

See **[docs/drunk-app.md](../docs/drunk-app.md)** for the complete configuration reference — all parameters, types, defaults, and usage examples.

## Claude Code Plugin

Install the AI assistant for drunk-app to get help configuring `values.yaml`:

```bash
plugin marketplace add baoduy/drunk.charts
plugin install drunk-app
```

Then use `/drunk-app` in any Claude Code session.

## Contributing

Contributions welcome. Open a [GitHub issue](https://github.com/baoduy/drunk.charts/issues) for questions or bugs.

## License

MIT — [Steven Hoang](https://drunkcoding.net)
```

- [ ] **Step 2: Verify line count**

```bash
wc -l drunk-app/README.md
```

Expected: approximately 70–80 lines.

- [ ] **Step 3: Commit**

```bash
git add drunk-app/README.md
git commit -m "docs(drunk-app): replace README with lean quickstart pointing to full docs"
```

---

## Task 4: Write the Plugin Skill (`SKILL.md`)

**Files:**
- Create: `plugins/drunk-app/skills/drunk-app/SKILL.md`

- [ ] **Step 1: Write `plugins/drunk-app/skills/drunk-app/SKILL.md` with the full content below**

Write this file exactly:

````markdown
---
name: drunk-app
description: "Use when working with the drunk-app Helm chart — configuring values.yaml, understanding parameters, generating deployment configs, or validating settings. Activate with /drunk-app or when the user mentions drunk-app, drunk-charts, or asks for help writing a values.yaml for this chart."
---

# drunk-app Helm Assistant

You are an expert in the **drunk-app** Helm chart from [drunk.charts](https://github.com/baoduy/drunk.charts). Help developers configure, generate, and validate `values.yaml` files.

## What drunk-app Is

`drunk-app` is an application Helm chart (v1.3.x) that wraps the `drunk-lib` library chart. Install it:

```bash
plugin marketplace add baoduy/drunk.charts
helm repo add drunk-charts https://baoduy.github.io/drunk.charts/drunk-app
helm repo update
helm install my-app drunk-charts/drunk-app -f my-values.yaml
```

Supported resources: `Deployment`, `StatefulSet`, `CronJob`, `Job`, `ConfigMap`, `Secret`, `SecretProviderClass`, TLS Secrets, `Ingress`, `HTTPRoute`, `Gateway`, `HPA`, `NetworkPolicy`, `ServiceAccount`, `PVC`, emptyDir.

## Your Three Modes

### Mode 1 — Answer

When the developer asks "how does X work?" or "what does Y do?", explain from the schema below with a YAML snippet.

### Mode 2 — Generate

When the developer says "give me a values.yaml for [use case]", produce a **complete, correct** values.yaml. Always include:
- `global.image` and `global.tag`
- At least one workload (`deployment`, `statefulset`, or jobs/cronJobs)
- A `tmp` emptyDir volume (required because `readOnlyRootFilesystem: true` by default)

Use the Generation Templates section below as your starting points.

### Mode 3 — Validate

When the developer pastes a values.yaml, run every item in the Validation Checklist and report all issues with specific fix instructions.

---

## Full Parameter Schema

### nameOverride
```yaml
nameOverride: string   # optional — overrides chart name in resource labels
                       # DO NOT use fullnameOverride
```

### imageCredentials
```yaml
imageCredentials:
  name: string        # required — pull secret resource name
  registry: string    # required — registry URL
  username: string    # required
  password: string    # required
# Wire to pods: set global.imagePullSecret to the same value as imageCredentials.name
```

### global
```yaml
global:
  image: string              # REQUIRED — no default
  tag: string                # default: "latest"
  imagePullPolicy: string    # default: "IfNotPresent" | "Always" | "Never"
  storageClassName: string   # default storage class for PVCs
  imagePullSecret: string    # pull secret name (must exist in namespace)
  initContainer:             # runs before main container
    image: string
    command: string[]
```

### env
```yaml
env:
  KEY: "value"   # plain env vars injected via ConfigMap
```

### configMap & configFrom
```yaml
configMap:
  KEY: "value"   # creates a new ConfigMap

configFrom:
  - "existing-configmap-name"   # injects all keys from an existing ConfigMap
```

### secrets & secretFrom
```yaml
secrets:
  KEY: "value"   # inline Secret (base64-encoded at rest)

secretFrom:
  - "existing-secret-name"   # injects all keys from an existing Secret
```

### secretProvider (CSI Secrets Store)
```yaml
secretProvider:
  enabled: bool              # default: false
  name: string               # optional override — default: <app>-spc
  provider:
    name: string             # REQUIRED when enabled: "azure" | "aws" | "gcp"
    tenantId: string         # Azure only
    vaultName: string        # REQUIRED when enabled
    userAssignedIdentityID: string   # Azure only
    usePodIdentity: bool     # default: false (Azure legacy)
    useWorkloadIdentity: bool # default: false (recommended)
  objects:
    - objectName: string     # REQUIRED — secret name in vault
      objectType: string     # REQUIRED — "secret" | "cert" | "key"
      objectFormat: string   # optional — "pem" | "pfx"
      objectEncoding: string # optional — "base64" | "utf-8"
```

### tlsSecrets — three modes
```yaml
# Mode 1: Inline base64
tlsSecrets:
  <name>:
    enabled: bool
    crt: string    # base64 certificate (required with key)
    key: string    # base64 private key (required with crt)
    ca: string     # optional base64 CA

# Mode 2: File-based (files read at helm template/install time)
tlsSecrets:
  <name>:
    enabled: bool
    crtFile: string   # path to .crt file
    keyFile: string   # path to .key file
    caFile: string    # optional path to CA file

# Mode 3: CA-only — DISABLED by default (not valid for kubernetes.io/tls)
tlsSecrets:
  <name>:
    enabled: false   # must stay false unless crt+key are also provided
    ca: string
```

### deployment
```yaml
deployment:
  enabled: bool          # default: true — set false for cron-only apps
  replicaCount: int      # default: 1
  ports:
    http: int            # default: 8080
    tcp: int             # optional
  liveness: string       # HTTP path e.g. "/healthz"
  readiness: string      # HTTP path e.g. "/healthz/ready"
  command: string[]      # override entrypoint
  args: string[]
  podAnnotations: {}
  strategy:
    type: string         # "RollingUpdate" (default) | "Recreate"
    maxSurge: string     # default: "1" — ignored when type=Recreate
    maxUnavailable: string # default: "1" — ignored when type=Recreate
```

### statefulset
```yaml
statefulset:
  enabled: bool          # default: false
  replicaCount: int      # default: 1
  ports:
    http: int
    tcp: int
  liveness: string
  readiness: string
  command: string[]
  args: string[]
  podAnnotations: {}
# Do NOT enable both deployment and statefulset simultaneously
```

### cronJobs
```yaml
cronJobs:
  - name: string          # REQUIRED, unique within chart
    schedule: string      # REQUIRED, cron format e.g. "0 2 * * *"
    command: string[]
    args: string[]
    restartPolicy: string # "OnFailure" (default) | "Never" | "Always"
```

### jobs
```yaml
jobs:
  - name: string          # REQUIRED, unique within chart
    command: string[]
    args: string[]
    restartPolicy: string # "OnFailure" (default) | "Never"
```

### volumes — MAP format (key = volume name)
```yaml
volumes:
  <name>:                      # PVC volume
    size: string               # REQUIRED e.g. "2Gi"
    accessMode: string         # REQUIRED: "ReadWriteOnce" | "ReadWriteMany" | "ReadOnlyMany"
    mountPath: string          # REQUIRED
    storageClassName: string   # optional, falls back to global.storageClassName
    subPath: string            # optional
    readOnly: bool             # default: false
  <name>:                      # emptyDir volume
    mountPath: string          # REQUIRED
    emptyDir: true             # REQUIRED: must be true
    readOnly: bool             # default: false
```

### serviceAccount
```yaml
serviceAccount:
  enabled: bool   # default: false
  annotations: {} # e.g. IRSA, Workload Identity
```

### podSecurityContext & securityContext
```yaml
podSecurityContext:
  fsGroup: int      # default: 10000
  runAsUser: int    # default: 10000
  runAsGroup: int   # default: 10000

securityContext:
  capabilities:
    drop: ["ALL"]             # default
  readOnlyRootFilesystem: bool      # default: true
  allowPrivilegeEscalation: bool    # default: false
  runAsNonRoot: bool                # default: true
```

### service
```yaml
service:
  type: string   # default: "ClusterIP" | "NodePort" | "LoadBalancer"
```

### httpRoute (Gateway API)
```yaml
httpRoute:
  enabled: bool
  parentRefs:
    - name: string        # REQUIRED — Gateway name
      namespace: string   # REQUIRED — Gateway namespace
      sectionName: string # optional — listener name
  tlsValidation:
    caCertificateRefs:
      - group: string
        kind: string
        name: string
  hostnames:
    - string
```

### gateway
```yaml
gateway:
  enabled: bool
  gatewayClassName: string  # REQUIRED when enabled
  listeners: []
```

### ingress
```yaml
ingress:
  enabled: bool       # default: false
  className: string   # e.g. "nginx"
  hosts:
    - host: string    # REQUIRED
      port: int       # REQUIRED
  tls: string         # TLS secret name
```

### resources
```yaml
resources:
  limits:
    cpu: string     # default: "100m"
    memory: string  # default: "128Mi"
  requests:
    cpu: string     # default: "100m"
    memory: string  # default: "128Mi"
```

### autoscaling
```yaml
autoscaling:
  enabled: bool      # default: false
  minReplicas: int   # default: 1
  maxReplicas: int   # default: 100
  targetCPUUtilizationPercentage: int    # optional
  targetMemoryUtilizationPercentage: int # optional
```

### nodeSelector / tolerations / affinity
```yaml
nodeSelector: {}
tolerations: []
affinity: {}
```

### networkPolicies (recommended)
```yaml
networkPolicies:
  - name: string              # REQUIRED
    enabled: bool             # default: true
    policyTypes: string[]     # REQUIRED: ["Ingress"] | ["Egress"] | ["Ingress","Egress"]
    podSelector: {}           # optional, defaults to app labels
    ingress: []
    egress: []
    labels: {}
    nameSuffix: string
```

### networkPolicy (legacy single policy)
```yaml
networkPolicy:
  policyTypes: string[]
  podSelector: {}
  ingress: []
  egress: []
```

---

## Generation Templates

Fill in `<placeholders>` with real values.

### Web Application
```yaml
nameOverride: "<app-name>"

global:
  image: "<registry/image>"
  tag: "<tag>"

deployment:
  ports:
    http: 8080
  liveness: "/healthz"

volumes:
  tmp:
    mountPath: "/tmp"
    emptyDir: true

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: "<hostname>"
      port: 8080

resources:
  limits:
    cpu: "500m"
    memory: "512Mi"
  requests:
    cpu: "100m"
    memory: "128Mi"
```

### Microservice with Private Registry + Secrets + Autoscaling
```yaml
nameOverride: "<app-name>"

global:
  image: "<registry/image>"
  tag: "<tag>"
  imagePullSecret: "<pull-secret-name>"

imageCredentials:
  name: "<pull-secret-name>"
  registry: "<registry-url>"
  username: "<username>"
  password: "<password>"

secrets:
  DATABASE_URL: "<connection-string>"
  API_KEY: "<key>"

deployment:
  ports:
    http: 8080
  liveness: "/health"
  readiness: "/ready"
  strategy:
    type: "RollingUpdate"
    maxSurge: "1"
    maxUnavailable: "0"

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetMemoryUtilizationPercentage: 80

volumes:
  tmp:
    mountPath: "/tmp"
    emptyDir: true

resources:
  limits:
    cpu: "500m"
    memory: "512Mi"
  requests:
    cpu: "100m"
    memory: "128Mi"
```

### Cron-Only App (no Deployment)
```yaml
nameOverride: "<app-name>"

global:
  image: "<registry/image>"
  tag: "<tag>"

deployment:
  enabled: false

cronJobs:
  - name: "<job-name>"
    schedule: "0 2 * * *"
    command: ["<entrypoint>"]
    restartPolicy: OnFailure

volumes:
  tmp:
    mountPath: "/tmp"
    emptyDir: true
```

### StatefulSet with Persistent Storage
```yaml
nameOverride: "<app-name>"

global:
  image: "<registry/image>"
  tag: "<tag>"

deployment:
  enabled: false

statefulset:
  enabled: true
  replicaCount: 1
  ports:
    tcp: <port>

volumes:
  data:
    size: "10Gi"
    accessMode: "ReadWriteOnce"
    mountPath: "/data"
  tmp:
    mountPath: "/tmp"
    emptyDir: true
```

### Azure Key Vault Secrets (CSI)
```yaml
secretProvider:
  enabled: true
  provider:
    name: azure
    tenantId: "<tenant-id>"
    vaultName: "<vault-name>"
    useWorkloadIdentity: true
  objects:
    - objectName: <secret-name>
      objectType: secret

serviceAccount:
  enabled: true
  annotations:
    azure.workload.identity/client-id: "<client-id>"
```

---

## Validation Checklist

When reviewing a user's values.yaml, check ALL items and report every failure:

1. **`global.image` is set** — no default. If missing, the chart will fail to render. Flag immediately.

2. **At least one workload** — at least one of: `deployment.enabled: true` (or omitted, since default is true), `statefulset.enabled: true`, non-empty `cronJobs[]`, non-empty `jobs[]`.

3. **Port matches app** — `deployment.ports.http` (or `statefulset.ports.http`) should match the port the container actually listens on.

4. **`secretProvider` completeness** — if `secretProvider.enabled: true`, then `secretProvider.provider.name` AND `secretProvider.provider.vaultName` must be set.

5. **`tlsSecrets` completeness** — if `tlsSecrets.<name>.enabled: true`, must have either (`crt` + `key`) or (`crtFile` + `keyFile`). A CA-only entry (`ca:` without `crt`+`key`) is invalid for `kubernetes.io/tls`.

6. **HPA + replica floor** — if `autoscaling.enabled: true`, `deployment.replicaCount` should be ≥ `autoscaling.minReplicas`, otherwise the HPA will immediately scale up.

7. **Egress + DNS** — if `networkPolicies` has any `Egress` policy, there must be a DNS rule (UDP port 53 to kube-system). Without it, DNS resolution breaks and the pod cannot reach anything by hostname.

8. **PVC fields complete** — if a volume entry has `emptyDir` absent or `false`, then `size` and `accessMode` are required.

9. **`readOnlyRootFilesystem` + tmp** — default `securityContext.readOnlyRootFilesystem: true` means the container cannot write to `/`. A `tmp` emptyDir volume is required for any app that writes temp files (most do).

10. **imagePullSecret wired** — if `imageCredentials` is defined, `global.imagePullSecret` must match `imageCredentials.name`. If they don't match, the pod will fail to pull the image.

---

## Known Gotchas

1. **`volumes` is a map, not an array.** Keys are volume names. Common mistake: writing `- name: tmp` (array syntax). Correct: `tmp:` (map key).

2. **Do not enable `deployment` and `statefulset` together.** Use one or the other. StatefulSets are for workloads needing stable network identity or ordered pod startup.

3. **`tlsSecrets` CA-only mode.** Setting `enabled: true` with only `ca:` will fail — Kubernetes requires both `tls.crt` and `tls.key`. Keep `enabled: false` for CA-only entries.

4. **`secretProvider.provider.name` is the cloud type, not the resource name.** Values: `azure`, `aws`, `gcp`. The resource name override is `secretProvider.name`.

5. **`configMap` vs `configFrom`.** `configMap` creates a new ConfigMap owned by this chart. `configFrom` references an existing external ConfigMap by name.

6. **`deployment.strategy` with `Recreate`.** Fields `maxSurge` and `maxUnavailable` are silently ignored when `type: Recreate`.

7. **`nameOverride` only.** Never set `fullnameOverride` — use `nameOverride` instead. The chart comment explicitly warns against this.

8. **Egress network policies always need a DNS exception.** Port 53 UDP to `kube-system` is not automatic. Forget it and all hostname resolution silently fails.
````

- [ ] **Step 2: Verify the file was written**

```bash
head -5 plugins/drunk-app/skills/drunk-app/SKILL.md
```

Expected output starts with:
```
---
name: drunk-app
description: "Use when working with the drunk-app Helm chart
```

- [ ] **Step 3: Commit**

```bash
git add plugins/drunk-app/skills/drunk-app/SKILL.md
git commit -m "feat(plugin): add drunk-app Claude Code skill with schema, templates, and validation"
```

---

## Task 5: Verify and Final Commit

**Files:** No new files — verification only.

- [ ] **Step 1: Run verify.sh**

```bash
./drunk-lib/verify.sh
```

Expected: all tests pass, no errors. If verify.sh fails, investigate — this plan does not touch any chart templates, so a failure here indicates a pre-existing issue.

- [ ] **Step 2: Verify plugin structure is complete**

```bash
find .claude-plugin plugins/drunk-app -type f | sort
```

Expected output:
```
.claude-plugin/marketplace.json
plugins/drunk-app/.claude-plugin/plugin.json
plugins/drunk-app/skills/drunk-app/SKILL.md
```

- [ ] **Step 3: Validate all JSON files**

```bash
for f in .claude-plugin/marketplace.json plugins/drunk-app/.claude-plugin/plugin.json; do
  python3 -m json.tool "$f" > /dev/null && echo "$f OK"
done
```

Expected: both print `OK`.

- [ ] **Step 4: Verify docs line counts are reasonable**

```bash
wc -l docs/drunk-app.md drunk-app/README.md
```

Expected: `docs/drunk-app.md` ≥ 480 lines, `drunk-app/README.md` ≤ 85 lines.

- [ ] **Step 5: Check SKILL.md frontmatter is valid**

```bash
head -4 plugins/drunk-app/skills/drunk-app/SKILL.md
```

Expected: starts with `---`, `name: drunk-app`, `description:` line, ends with `---`.

- [ ] **Step 6: Final summary commit (if any unstaged files remain)**

```bash
git status
```

If all files were committed in previous tasks this will show a clean tree. If anything is untracked, add and commit:

```bash
git add -A
git commit -m "docs(drunk-app): complete docs rewrite and Claude Code plugin"
```

---

## Self-Review Notes

**Spec coverage check:**
- ✅ `docs/drunk-app.md` full rewrite — Task 2
- ✅ `drunk-app/README.md` lean quickstart — Task 3
- ✅ `.claude-plugin/marketplace.json` — Task 1
- ✅ `plugins/drunk-app/.claude-plugin/plugin.json` — Task 1
- ✅ `plugins/drunk-app/skills/drunk-app/SKILL.md` — Task 4
- ✅ Verification + commit — Task 5
- ✅ SKILL.md covers all three modes: answer, generate, validate
- ✅ All 10 validation checklist items from spec are in SKILL.md
- ✅ All 8 known gotchas from spec are in SKILL.md
- ✅ All generation templates (web app, microservice, cron-only, statefulset) are in SKILL.md
- ✅ `service.type` gap documented in docs
- ✅ `gateway` section documented in docs

**Placeholder scan:** No TBDs, no "implement later", no "similar to Task N". All file content is complete and literal.

**Type consistency:** No code types involved — all markdown and JSON. File paths are consistent across all tasks.
