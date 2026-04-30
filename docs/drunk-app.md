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
