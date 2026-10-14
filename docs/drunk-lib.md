# Drunk-lib Library Chart Reference

The **drunk-lib** Helm chart library provides a comprehensive collection of reusable templates for Kubernetes applications. It serves as the foundation for the **drunk-app** chart and can be used by any Helm chart that needs standardized, production-ready Kubernetes resources.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Available Templates](#available-templates)
- [Template Reference](#template-reference)
- [Usage Examples](#usage-examples)
- [Extending the Library](#extending-the-library)
- [Contributing](#contributing)

## Overview

### Purpose

Drunk-lib eliminates the need to write repetitive Kubernetes resource templates by providing:

- **Standardized Templates**: Production-ready templates following best practices
- **Flexible Configuration**: Comprehensive configuration options for all use cases
- **Consistency**: Uniform resource generation across all applications
- **Maintainability**: Centralized template management and updates

### Key Benefits

- 🔄 **Reusability**: Use the same templates across multiple charts
- 📋 **Standards**: Built-in Kubernetes best practices
- 🛠 **Flexibility**: Extensive configuration options
- 🧩 **Modularity**: Include only the resources you need
- 🔧 **Maintainability**: Single source of truth for templates

## Architecture

### Library Chart Structure

```
drunk-lib/
├── Chart.yaml                 # Chart metadata (type: library)
├── values.yaml               # Default configuration values
└── templates/
    ├── _helpers.tpl          # Helper functions and labels
    ├── _deployment.tpl       # Deployment template
    ├── _statefulset.tpl      # StatefulSet template
    ├── _service.tpl          # Service template
    ├── _ingress.tpl          # Ingress template
    ├── _gateway.tpl          # Gateway API Gateway template
    ├── _httproute.tpl        # Gateway API HTTPRoute template
    ├── _configMap.tpl        # ConfigMap template
    ├── _secrets.tpl          # Secret template
    ├── _secretprovider.tpl   # Azure Key Vault SecretProviderClass
    ├── _serviceAccount.tpl   # ServiceAccount template
    ├── _volumes.tpl          # PersistentVolumeClaim templates
    ├── _cronjob.tpl          # CronJob template
    ├── _job.tpl              # Job template
    ├── _hpa.tpl              # HorizontalPodAutoscaler template
    └── _tls-secrets.tpl      # TLS Secret template
```

### How workload includes render

![A consumer includes drunk-lib workload templates, which render shared probes and lifecycle or stop on invalid shutdown values.](diagrams/workload-render.svg)

A consumer passes its values to `drunk-lib.deployment` or `drunk-lib.statefulset`; each renders only when its workload is enabled.
The helpers `drunk-lib.probes`, `drunk-lib.lifecycle` and `drunk-lib.podScheduling` apply the same rollout-safety rules as `drunk-app`.
Library consumers provide their own workload, image, resource and security defaults; they do not inherit `drunk-app/values.yaml`.

### Template Naming Convention

All templates follow the naming pattern: `drunk-lib.<resource-type>`

Examples:
- `drunk-lib.deployment`
- `drunk-lib.service`
- `drunk-lib.configMap`

## Available Templates

### Core Resources

| Template | Purpose | Template Name |
|----------|---------|---------------|
| **Deployment** | Standard application deployment | `drunk-lib.deployment` |
| **StatefulSet** | Stateful application deployment | `drunk-lib.statefulset` |
| **Service** | Service discovery and load balancing | `drunk-lib.service` |
| **Ingress** | External access routing (traditional) | `drunk-lib.ingress` |
| **Gateway** | External access via Gateway API | `drunk-lib.gateway` |
| **HTTPRoute** | HTTP routing rules for Gateway API | `drunk-lib.httpRoute` |

### Configuration Resources

| Template | Purpose | Template Name |
|----------|---------|---------------|
| **ConfigMap** | Application configuration | `drunk-lib.configMap` |
| **Secret** | Sensitive configuration | `drunk-lib.secrets` |
| **SecretProviderClass** | Azure Key Vault integration | `drunk-lib.secretProvider` |
| **TLS Secret** | TLS certificate storage | `drunk-lib.tlsSecrets` |

### Storage Resources

| Template | Purpose | Template Name |
|----------|---------|---------------|
| **PersistentVolumeClaim** | Persistent storage | `drunk-lib.volumes` |

### Batch Resources

| Template | Purpose | Template Name |
|----------|---------|---------------|
| **CronJob** | Scheduled jobs | `drunk-lib.cronJobs` |
| **Job** | One-time jobs | `drunk-lib.jobs` |

### Scaling & Security

| Template | Purpose | Template Name |
|----------|---------|---------------|
| **HPA** | Horizontal Pod Autoscaler | `drunk-lib.hpa` |
| **ServiceAccount** | Pod identity | `drunk-lib.serviceAccount` |
| **ImagePullSecret** | Registry authentication | `drunk-lib.imagePullSecret` |
| **NetworkPolicy** | Network access control | `drunk-lib.networkPolicies` |
| **PodDisruptionBudget** | Voluntary eviction budget | `drunk-lib.pdb` |

## Template Reference

### Helper Templates

#### `app.name`
Returns the application name based on chart name or `nameOverride`.

```yaml
{{- include "app.name" . }}
```

#### `app.fullname`
Returns the full application name including release name.

```yaml
{{- include "app.fullname" . }}
```

#### `app.labels`
Returns standard Kubernetes labels for resources.

```yaml
labels:
  {{- include "app.labels" . | nindent 4 }}
```

#### `app.selectorLabels`
Returns selector labels for matching pods.

```yaml
selector:
  matchLabels:
    {{- include "app.selectorLabels" . | nindent 6 }}
```

### Deployment Template

**Template**: `drunk-lib.deployment`

Creates a Kubernetes Deployment with comprehensive configuration options.

#### Key Features:
- Multi-container support (main + init containers)
- Flexible port configuration
- Health checks (liveness/readiness probes)
- Resource management
- Volume mounting
- Environment variable injection
- Security contexts

#### Configuration:

```yaml
deployment:
  enabled: true
  replicaCount: 1
  command: []
  args: []
  ports:
    http: 8080
    https: 8443
  liveness: "/health"
  readiness: "/ready"
  podAnnotations: {}
  
global:
  image: "myapp/image"
  tag: "latest"
  imagePullPolicy: "IfNotPresent"
  imagePullSecret: "registry-secret"

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi
```

#### Rollout-safety keys

These keys apply to `drunk-lib.deployment` and `drunk-lib.statefulset`.
All new fields are opt-in; omitted fields leave the previous rendering behavior.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `deployment.liveness`, `statefulset.liveness` | string or object | — | HTTP path shorthand or raw probe map |
| `deployment.readiness`, `statefulset.readiness` | string or object | — | HTTP path shorthand or raw probe map |
| `deployment.startup`, `statefulset.startup` | string or object | — | HTTP startup path or raw probe map |
| `deployment.terminationGracePeriodSeconds`, `statefulset.terminationGracePeriodSeconds` | int | — | Pod termination budget; Kubernetes supplies its default when absent |
| `deployment.preStopSleepSeconds`, `statefulset.preStopSleepSeconds` | int | — | Native `preStop.sleep.seconds`; Kubernetes 1.30+ |
| `deployment.lifecycle`, `statefulset.lifecycle` | object | — | Raw lifecycle, including `{}`, overrides convenience sleep |
| `deployment.minReadySeconds`, `statefulset.minReadySeconds` | int | — | Minimum ready interval; retains explicit `0` |
| `deployment.progressDeadlineSeconds` | int | — | Deployment progress deadline; retained when supplied |
| `deployment.revisionHistoryLimit` | int | — | Retained ReplicaSets; retains explicit `0` |
| `deployment.strategy.maxSurge` | int or percentage string | `1` | Extra pods during RollingUpdate; retains explicit `0` |
| `deployment.strategy.maxUnavailable` | int or percentage string | `0` | Unavailable pods during RollingUpdate; retains explicit `0` |

The rollout fields render only when present; the chart does not validate their Kubernetes ranges.
RollingUpdate refuses both max values at zero (`0` or `"0%"`). `strategy.type: Recreate` emits no `rollingUpdate` block.
StatefulSet uses its existing `updateStrategy`, not the Deployment strategy or progress/revision fields.

#### Probes and graceful shutdown

These keys configure the main container only. Init containers, Jobs and CronJobs do not use them.
A non-empty probe map passes through unchanged: use `httpGet` (including HTTPS), `tcpSocket`, `exec` or `grpc`, plus Kubernetes probe timing fields.
An empty string or map emits no probe. String shorthand uses the named `http` port; define that container port.
Liveness shorthand keeps `initialDelaySeconds: 60` and `periodSeconds: 300`; readiness shorthand adds only `httpGet`.
Startup shorthand uses `periodSeconds: 5` and `failureThreshold: 30`.

```yaml
deployment:
  ports: {http: 8080}
  liveness: "/healthz"
  readiness:
    httpGet: {path: /healthz/ready, port: http}
    periodSeconds: 5
    failureThreshold: 3
  startup: "/healthz"
  terminationGracePeriodSeconds: 45
  preStopSleepSeconds: 10
```

`preStopSleepSeconds` emits native `preStop.sleep.seconds`, so no shell or sleep binary is needed in the image.
Use Kubernetes **1.30+** with the `PodLifecycleSleepAction` feature gate enabled (beta and enabled by default in 1.30).
See the [Kubernetes lifecycle update](https://kubernetes.io/blog/2025/05/14/kubernetes-v1-33-updates-to-container-lifecycle/).
Set an explicit grace period that leaves time for the app to finish after the sleep.
When both convenience values are present, sleep greater than or equal to the grace period fails rendering, even if `lifecycle` overrides the sleep.
Without an explicit grace period, the chart performs no comparison; Kubernetes supplies its pod default.

A raw `lifecycle` key, including `{}`, takes precedence over convenience sleep. For an HTTP shutdown hook instead:

```yaml
deployment:
  terminationGracePeriodSeconds: 45
  lifecycle:
    preStop:
      httpGet: {path: /shutdown, port: 8080}
```

Use the same example under `statefulset` with `deployment.enabled: false` and `statefulset.enabled: true`.

### StatefulSet Template

**Template**: `drunk-lib.statefulset`

Creates a Kubernetes StatefulSet for stateful applications.

The [rollout-safety table](#rollout-safety-keys) covers its probes, shutdown and `minReadySeconds` keys.

#### Configuration:

```yaml
deployment:
  enabled: false
statefulset:
  enabled: true
  volumeClaimTemplates:
    - name: "data"
      mountPath: "/data"
      storage: "10Gi"
      storageClassName: "fast-ssd"
      accessModes: ["ReadWriteOnce"]
```

### Service Template

**Template**: `drunk-lib.service`

Creates a Kubernetes Service for pod discovery and load balancing.

#### Configuration:

```yaml
service:
  type: "ClusterIP"  # ClusterIP, NodePort, LoadBalancer
  ports:
    http: 8080
  port: 80
```

### ConfigMap Template

**Template**: `drunk-lib.configMap`

Creates a ConfigMap for application configuration.

#### Configuration:

```yaml
configMap:
  app.properties: |
    server.port=8080
    logging.level=INFO
  config.json: |
    {"feature": "enabled"}

# Reference external ConfigMaps
configFrom:
  - "shared-config"
  - "environment-config"
```

### Secrets Template

**Template**: `drunk-lib.secrets`

Creates a Secret for sensitive configuration.

#### Configuration:

```yaml
secrets:
  DATABASE_PASSWORD: "secret-password"
  API_KEY: "your-api-key"

# Reference external Secrets
secretFrom:
  - "database-credentials"
  - "api-keys"
```

### SecretProviderClass Template

**Template**: `drunk-lib.secretProvider`

Creates a SecretProviderClass for Azure Key Vault integration using the Secrets Store CSI driver.

#### Configuration:

```yaml
secretProvider:
  enabled: true
  name: "my-key-vault-spc"
  provider:
    tenantId: "your-tenant-id"
    vaultName: "your-key-vault"
    usePodIdentity: false
    useVMManagedIdentity: false
    useWorkloadIdentity: true
  objects:
    - objectName: "database-password"
      objectType: "secret"
    - objectName: "api-certificate"
      objectType: "cert"
  secretObjects:
    - secretName: "app-secrets"
      type: "Opaque"
      data:
        - key: "DATABASE_PASSWORD"
          objectName: "database-password"
```

### CronJob Template

**Template**: `drunk-lib.cronJobs`

Creates CronJob resources for scheduled tasks.

#### Configuration:

```yaml
cronJobs:
  - name: "backup"
    schedule: "0 2 * * *"
    command: ["/app/backup.sh"]
    args: ["--verbose"]
    restartPolicy: "OnFailure"
    concurrencyPolicy: "Forbid"
  - name: "cleanup"
    schedule: "0 4 * * 0"
    command: ["/app/cleanup.sh"]
```

### Job Template

**Template**: `drunk-lib.jobs`

Creates Job resources for one-time tasks.

#### Configuration:

```yaml
jobs:
  - name: "migration"
    command: ["/app/migrate.sh"]
    args: ["--force"]
    restartPolicy: "Never"
```

### Volumes Template

**Template**: `drunk-lib.volumes`

Creates PersistentVolumeClaim resources for storage.

#### Configuration:

```yaml
volumes:
  data:
    size: "10Gi"
    storageClassName: "fast-ssd"
    accessMode: "ReadWriteOnce"
    mountPath: "/app/data"
  logs:
    size: "5Gi"
    accessMode: "ReadWriteOnce"
    mountPath: "/var/log/app"
    readOnly: false
  # EmptyDir volumes
  tmp:
    mountPath: "/tmp"
    emptyDir: true
```

### Ingress Template

**Template**: `drunk-lib.ingress`

Creates Ingress resources for external access.

#### Configuration:

```yaml
ingress:
  enabled: true
  className: "nginx"
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: "/"
  hosts:
    - host: "myapp.example.com"
      path: "/"
      pathType: "Prefix"
      port: 80
  tls: "myapp-tls"
```

### HPA Template

**Template**: `drunk-lib.hpa`

Creates HorizontalPodAutoscaler for automatic scaling.

#### Configuration:

```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
```

#### Replica ownership

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `autoscaling.omitReplicas` | bool | `false` | Omit Deployment replicas only when HPA is enabled and targets Deployment |
| `autoscaling.targetKind` | string | `"Deployment"` | HPA target kind; supports `StatefulSet` |

StatefulSet `spec.replicas` and HPA `minReplicas` remain unchanged.
On an existing HPA-managed release, the first Helm/Argo sync that removes `replicas` can reset it to `1` until HPA scales up.
Plan that sync with the [upgrade guide](upgrade-guide.md#hpa-replica-ownership).

### Pod Scheduling

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `podAntiAffinityPreset` | string | `""` | `""`, `soft` or `hard`; unknown values fail rendering |
| `topologySpreadConstraints` | object[] | — | Raw spread constraints; inject selector labels when `labelSelector` is absent |

These top-level keys apply to Deployment and StatefulSet only.
`soft` adds preferred anti-affinity, weight `100`; `hard` adds required anti-affinity.
Both use `kubernetes.io/hostname` and the current chart's selector labels.
The preset preserves other affinity. Explicit `affinity.podAntiAffinity`, including `{}`, takes precedence.
A hard preset needs enough eligible nodes or pods can stay Pending.
Explicit spread selectors remain untouched; injected selectors use each sub-chart alias's own labels without mutating shared values.

```yaml
podAntiAffinityPreset: soft
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: ScheduleAnyway
```

### PodDisruptionBudget Template

**Template**: `drunk-lib.pdb` (also included by `drunk-lib.all`).
A consumer using individual includes must add this include to its templates to render a PDB.
The budget renders only for an enabled Deployment or StatefulSet and selects its pods with `app.selectorLabels`.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `podDisruptionBudget.enabled` | bool | `false` | Render a `policy/v1` budget when a workload is enabled |
| `podDisruptionBudget.minAvailable` | int or percentage string | — | Choose exactly one availability key |
| `podDisruptionBudget.maxUnavailable` | int or percentage string | — | Choose exactly one availability key |
| `podDisruptionBudget.unhealthyPodEvictionPolicy` | string | `AlwaysAllow` (when enabled) | `AlwaysAllow` or `IfHealthyBudget`; stable in Kubernetes 1.31+ |

```yaml
deployment:
  enabled: true
  replicaCount: 3
podDisruptionBudget:
  enabled: true
  minAvailable: 1
  unhealthyPodEvictionPolicy: AlwaysAllow
```

Both availability keys, or neither, fail rendering.
With autoscaling disabled, an integer `minAvailable` at least equal to the effective replica count (default `1`) fails because it blocks every drain.
Strings and HPA-enabled workloads bypass that guard; review their budget against the minimum replica count.
An enabled PDB always emits `unhealthyPodEvictionPolicy`; use Kubernetes **1.31+** for the stable field.
See the [Kubernetes PDB guidance](https://kubernetes.io/docs/tasks/run-application/configure-pdb/#unhealthy-pod-eviction-policy).
A PDB controls voluntary eviction; Deployment rolling-update availability comes from the strategy.

### NetworkPolicy Template

**Template**: `drunk-lib.networkPolicies`

Creates NetworkPolicy resources to control network access to pods. Supports both legacy single policy and modern multiple policies configurations.

**Note**: Requires a CNI plugin that supports NetworkPolicy (e.g., Calico, Cilium, Weave Net).

#### Legacy Single Policy Configuration:

```yaml
networkPolicy:
  policyTypes:
    - Ingress
  podSelector:
    app: my-app
  ingress:
    - from:
      - podSelector:
          matchLabels:
            app: frontend
      ports:
      - protocol: TCP
        port: 8080
```

#### Multiple Policies Configuration (Recommended):

```yaml
networkPolicies:
  # Allow traffic from private IP ranges
  - name: allow-private-ips
    enabled: true
    policyTypes:
      - Ingress
    ingress:
      - from:
        - ipBlock:
            cidr: 10.0.0.0/8
        - ipBlock:
            cidr: 172.16.0.0/12
        - ipBlock:
            cidr: 192.168.0.0/16
        ports:
        - protocol: TCP
          port: 8080
  
  # Allow traffic from same namespace
  - name: allow-same-namespace
    enabled: true
    policyTypes:
      - Ingress
    ingress:
      - from:
        - podSelector: {}
  
  # Restrict egress to specific services
  - name: allow-egress-database
    enabled: true
    policyTypes:
      - Egress
    egress:
      - to:
        - podSelector:
            matchLabels:
              app: postgres
        ports:
        - protocol: TCP
          port: 5432
```

#### Configuration Options:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `name` | Policy name | Required |
| `enabled` | Enable/disable this policy | `true` |
| `nameSuffix` | Custom suffix for resource name | `-{name}` |
| `podSelector` | Pod selector (defaults to app labels) | App labels |
| `labels` | Additional labels | `{}` |
| `policyTypes` | Policy types (`Ingress`, `Egress`) | Required |
| `ingress` | Ingress rules | `[]` |
| `egress` | Egress rules | `[]` |

## Usage Examples

### Zero-downtime Deployment

This values example matches the [library README](../drunk-lib/README.md#example--zero-downtime-deployment).
A library consumer includes `drunk-lib.deployment`, `drunk-lib.hpa`, `drunk-lib.service` and `drunk-lib.pdb`, or uses `drunk-lib.all`.
Use Kubernetes 1.31+, HTTP `/healthz` on `8080`, and HTTPS health endpoints on `8443`.
Tune readiness, startup and shutdown to the app; these values do not guarantee availability by themselves.

```yaml
global:
  image: example/app
  tag: "1.0.0"
podAntiAffinityPreset: soft
affinity:
  nodeAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 50
        preference:
          matchExpressions:
            - key: pool
              operator: In
              values: [apps]
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: ScheduleAnyway
podDisruptionBudget:
  enabled: true
  minAvailable: 1
  unhealthyPodEvictionPolicy: AlwaysAllow
deployment:
  enabled: true
  replicaCount: 3
  ports: {http: 8080, https: 8443}
  liveness:
    httpGet: {path: /healthz, port: https, scheme: HTTPS}
    periodSeconds: 10
    failureThreshold: 3
  readiness:
    httpGet: {path: /healthz/ready, port: https, scheme: HTTPS}
    periodSeconds: 5
    failureThreshold: 3
  startup: "/healthz"
  terminationGracePeriodSeconds: 45
  preStopSleepSeconds: 10
  minReadySeconds: 10
  progressDeadlineSeconds: 600
  revisionHistoryLimit: 5
  strategy: {type: RollingUpdate, maxSurge: 0, maxUnavailable: 1}
autoscaling:
  enabled: true
  omitReplicas: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
```

For CPU-based HPA scaling, the consumer also needs CPU requests and a metrics API.
For example, add `resources.requests.cpu: 100m` to the consumer's values.
On an existing release, initially keep `autoscaling.omitReplicas: false` and plan the later ownership change separately.

### Creating a Chart that Uses drunk-lib

#### 1. Chart.yaml

```yaml
apiVersion: v2
name: my-app
description: My application chart
type: application
version: 0.1.0
appVersion: "1.0"

dependencies:
  - name: drunk-lib
    version: "2.*.*"
    repository: "https://baoduy.github.io/drunk.charts/drunk-lib"
```

#### 2. Template Usage

**templates/deployment.yaml**
```yaml
{{ include "drunk-lib.deployment" . }}
```

**templates/service.yaml**
```yaml
{{ include "drunk-lib.service" . }}
```

**templates/configmap.yaml**
```yaml
{{ include "drunk-lib.configMap" . }}
```

#### 3. Values Configuration

```yaml
global:
  image: "myapp/image"
  tag: "v1.0.0"

deployment:
  enabled: true
  ports:
    http: 8080

configMap:
  app.properties: |
    server.port=8080
    
service:
  type: "ClusterIP"
```

### Advanced Usage: Custom Templates

You can create custom templates that extend drunk-lib templates:

```yaml
{{- define "myapp.deployment" -}}
{{- $_ := set .Values "customAnnotations" (dict "myapp.io/version" .Chart.AppVersion) -}}
{{ include "drunk-lib.deployment" . }}
{{- end }}
```

### Environment-Specific Configurations

**values-dev.yaml**
```yaml
global:
  tag: "dev"

deployment:
  replicaCount: 1

ingress:
  hosts:
    - host: "dev.myapp.example.com"
```

**values-prod.yaml**
```yaml
global:
  tag: "v1.0.0"

deployment:
  replicaCount: 3

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10

ingress:
  hosts:
    - host: "myapp.example.com"
  tls:
    - secretName: "myapp-prod-tls"
      hosts:
        - "myapp.example.com"
```

## Extending the Library

### Adding New Templates

1. Create a new template file in `templates/`:
   ```bash
   touch templates/_myresource.tpl
   ```

2. Define the named template:
   ```yaml
   {{- define "drunk-lib.myResource" -}}
   apiVersion: v1
   kind: MyResource
   metadata:
     name: {{ include "app.fullname" . }}
     labels: {{ include "app.labels" . | nindent 4 }}
   spec:
     # Your resource specification
   {{- end }}
   ```

3. Document the template in this README.

### Template Best Practices

1. **Naming**: Use the `drunk-lib.` prefix for all templates
2. **Conditionals**: Always check if features are enabled before rendering
3. **Defaults**: Provide sensible defaults in values.yaml
4. **Documentation**: Document all configuration options
5. **Testing**: Add unit tests for new templates

### Testing Templates

Use `helm template` to test template rendering:

```bash
# Test basic rendering
helm template test-release . --debug

# Test with custom values
helm template test-release . -f test-values.yaml --debug

# Test specific templates
helm template test-release . --show-only templates/deployment.yaml
```

## Contributing

### Development Setup

1. Clone the repository
2. Make changes to templates
3. Test with `helm template`
4. Update documentation
5. Submit a pull request

### Template Guidelines

- Follow existing naming conventions
- Add comprehensive configuration options
- Include proper error handling
- Document all features
- Test thoroughly

### Versioning

The library follows semantic versioning:
- **Major**: Breaking changes to template interfaces
- **Minor**: New templates or non-breaking feature additions
- **Patch**: Bug fixes and improvements

## Changelog

### v1.0.7
- Added SecretProviderClass template for Azure Key Vault
- Improved StatefulSet template
- Enhanced volume mounting options

### v1.0.6
- Added HPA template
- Improved resource management
- Bug fixes in service template

---

## Support

- **Issues**: [GitHub Issues](https://github.com/baoduy/drunk.charts/issues)
- **Documentation**: [Main Documentation](./README.md)
- **Author**: [Steven Hoang](https://drunkcoding.net)

*This library is the foundation of the drunk-app chart and enables consistent, production-ready deployments across all applications.*