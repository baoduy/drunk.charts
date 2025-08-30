# Architecture Overview

This document provides a comprehensive overview of the Drunk Charts architecture, explaining how the components work together to provide a powerful, flexible Helm chart solution.

## System Architecture

### High-Level Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Developer     │    │  Application    │    │  Kubernetes     │
│                 │    │     Code        │    │   Cluster       │
│  - values.yaml  │────▶  - Dockerfile   │────▶ - Deployments  │
│  - helm install │    │  - Config       │    │ - Services      │
│                 │    │                 │    │ - Ingress       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Drunk Charts System                         │
│                                                                 │
│  ┌─────────────────┐           ┌─────────────────────────────┐  │
│  │   drunk-app     │           │        drunk-lib            │  │
│  │                 │           │                             │  │
│  │  Application    │    uses   │     Library Chart           │  │
│  │    Chart        │◄──────────│                             │  │
│  │                 │           │  - Reusable Templates       │  │
│  │ - Chart.yaml    │           │  - Helper Functions         │  │
│  │ - values.yaml   │           │  - Best Practices           │  │
│  │ - templates/    │           │  - Production Ready         │  │
│  └─────────────────┘           └─────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Chart Relationships

### Dependency Structure

```
drunk-app (Application Chart)
├── Chart.yaml
│   └── dependencies:
│       └── drunk-lib: "1.x.x"  # Library Chart Dependency
├── values.yaml                 # Default configuration
├── templates/
│   ├── deployment.yaml         # {{ include "drunk-lib.deployment" . }}
│   ├── service.yaml           # {{ include "drunk-lib.service" . }}
│   ├── configmap.yaml         # {{ include "drunk-lib.configMap" . }}
│   └── ...                    # All templates include drunk-lib templates
└── charts/
    └── drunk-lib/              # Downloaded dependency

drunk-lib (Library Chart)
├── Chart.yaml (type: library)
├── values.yaml                 # Default template values
└── templates/
    ├── _helpers.tpl           # Common helper functions
    ├── _deployment.tpl        # Deployment template logic
    ├── _service.tpl          # Service template logic
    ├── _configmap.tpl        # ConfigMap template logic
    └── ...                   # All Kubernetes resource templates
```

### Template Flow

1. **User Installation**: `helm install myapp drunk-app`
2. **Dependency Resolution**: Helm downloads drunk-lib as dependency
3. **Template Processing**: drunk-app templates call drunk-lib templates
4. **Resource Generation**: drunk-lib generates Kubernetes resources
5. **Deployment**: Resources are applied to the cluster

```
User Values
    │
    ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   drunk-app     │────▶│   drunk-lib     │────▶│  Kubernetes     │
│   templates     │     │   templates     │     │   Resources     │
│                 │     │                 │     │                 │
│ deployment.yaml │     │ _deployment.tpl │     │ Deployment      │
│ service.yaml    │     │ _service.tpl    │     │ Service         │
│ configmap.yaml  │     │ _configmap.tpl  │     │ ConfigMap       │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

## Component Architecture

### drunk-lib (Library Chart)

The core library providing reusable templates and functions.

#### Template Categories

**Core Resources**
- `_deployment.tpl` - Application deployment logic
- `_statefulset.tpl` - Stateful application support
- `_service.tpl` - Service discovery and networking

**Configuration Management**
- `_configmap.tpl` - Application configuration
- `_secrets.tpl` - Sensitive data management
- `_secretprovider.tpl` - Azure Key Vault integration

**Storage & Persistence**
- `_volumes.tpl` - Persistent volume claims
- Volume mounting logic in deployments

**Batch Processing**
- `_cronjob.tpl` - Scheduled job execution
- `_job.tpl` - One-time task execution

**Networking & Access**
- `_ingress.tpl` - External access routing
- `_service.tpl` - Internal service discovery

**Scaling & Operations**
- `_hpa.tpl` - Horizontal pod autoscaling
- `_serviceaccount.tpl` - Pod identity management

#### Helper Functions

```yaml
# Standard Kubernetes labels
{{ include "app.labels" . }}

# Application naming
{{ include "app.name" . }}
{{ include "app.fullname" . }}

# Selector labels for pod matching
{{ include "app.selectorLabels" . }}

# Checksum generation for config changes
{{ include "app.checksums" . }}
```

### drunk-app (Application Chart)

The user-facing chart that provides a simple interface to the powerful drunk-lib templates.

#### Design Principles

1. **Simplicity**: Easy-to-use interface for complex functionality
2. **Convention over Configuration**: Sensible defaults for common use cases
3. **Flexibility**: Full access to underlying drunk-lib capabilities
4. **Production Ready**: Built-in best practices and security

#### Template Strategy

Each drunk-app template is minimal and delegates to drunk-lib:

```yaml
# drunk-app/templates/deployment.yaml
{{ include "drunk-lib.deployment" . }}

# drunk-app/templates/service.yaml
{{ include "drunk-lib.service" . }}
```

This approach provides:
- **Consistency**: All charts using drunk-lib behave similarly
- **Maintainability**: Updates to drunk-lib benefit all charts
- **Flexibility**: Charts can override or extend templates as needed

## Configuration Architecture

### Values Hierarchy

```yaml
# Global settings (affect all resources)
global:
  image: "myapp/image"
  tag: "v1.0.0"
  imagePullPolicy: "IfNotPresent"

# Resource-specific settings
deployment:
  enabled: true
  replicaCount: 2
  
service:
  type: "ClusterIP"
  
ingress:
  enabled: true
  hosts: [...]

# Feature toggles
autoscaling:
  enabled: false
  
cronJobs: []
jobs: []
```

### Configuration Patterns

**Feature Flags**
```yaml
# Enable/disable entire resource categories
deployment:
  enabled: true    # Creates Deployment

statefulset:
  enabled: false   # Skips StatefulSet

ingress:
  enabled: true    # Creates Ingress
```

**Resource Templates**
```yaml
# Array-based resources
cronJobs:
  - name: "backup"
    schedule: "0 2 * * *"
  - name: "cleanup"
    schedule: "0 4 * * 0"

jobs:
  - name: "migration"
    command: ["/migrate.sh"]
```

**Conditional Logic**
```yaml
{{- if .Values.deployment.enabled }}
# Render deployment
{{- end }}

{{- range .Values.cronJobs }}
# Render each cronjob
{{- end }}
```

## Resource Generation Flow

### Template Processing Pipeline

1. **Values Merging**
   - Default values from drunk-lib
   - Default values from drunk-app
   - User-provided values
   - Command-line overrides

2. **Template Rendering**
   - drunk-app templates include drunk-lib templates
   - Helper functions generate labels, names, etc.
   - Conditional logic determines which resources to create

3. **Resource Creation**
   - Kubernetes resources are generated
   - Resources are validated by Kubernetes API
   - Resources are applied to the cluster

### Example Flow

```
User Input:
  global.image: "myapp:v1.0.0"
  deployment.replicaCount: 3

    ↓

Values Processing:
  Merges with defaults
  Validates configuration

    ↓

Template Rendering:
  {{ include "drunk-lib.deployment" . }}
  - Reads .Values.deployment
  - Reads .Values.global
  - Generates Kubernetes Deployment YAML

    ↓

Kubernetes Resources:
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: myapp
    labels: { ... }
  spec:
    replicas: 3
    template:
      spec:
        containers:
        - image: myapp:v1.0.0
```

## Security Architecture

### Built-in Security Features

**Pod Security**
```yaml
# Default security contexts
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000

securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop: ["ALL"]
```

**Secret Management**
- Kubernetes Secrets for sensitive data
- Azure Key Vault integration via CSI driver
- External secret references

**Network Security**
- Service-to-service communication
- Ingress TLS termination
- Network policies (when configured)

### Secret Provider Architecture

```
Azure Key Vault
      │
      │ Secrets Store CSI Driver
      │
      ▼
SecretProviderClass ────▶ Pod Volume Mount
      │                      │
      │                      ▼
      └────▶ Kubernetes Secret (optional)
```

## Scaling Architecture

### Horizontal Scaling

```yaml
# HPA Configuration
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

# Resource requests (required for HPA)
resources:
  requests:
    cpu: 100m
    memory: 128Mi
```

### Vertical Scaling

```yaml
# Resource limits and requests
resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 100m
    memory: 128Mi
```

## Storage Architecture

### Persistent Storage

```yaml
volumes:
  data:
    size: "10Gi"
    storageClass: "fast-ssd"
    mountPath: "/app/data"
    
  # Creates PVC and mounts to pod
```

### Ephemeral Storage

```yaml
volumes:
  tmp:
    mountPath: "/tmp"
    emptyDir: true
    
  cache:
    mountPath: "/cache"
    emptyDir: true
    size: "1Gi"  # Size limit
```

## Extensibility Architecture

### Creating Custom Charts

```yaml
# Custom chart using drunk-lib
dependencies:
  - name: drunk-lib
    version: "1.x.x"
    repository: "https://baoduy.github.io/drunk.charts/drunk-lib"

# Custom templates can extend drunk-lib
{{- define "mychart.custom-deployment" -}}
{{- $_ := set .Values "customField" "value" -}}
{{ include "drunk-lib.deployment" . }}
{{- end }}
```

### Template Customization

1. **Include Pattern**: Use drunk-lib templates directly
2. **Wrapper Pattern**: Create custom templates that call drunk-lib
3. **Extension Pattern**: Add custom resources alongside drunk-lib

## Monitoring and Observability

### Built-in Features

- **Health Checks**: Liveness and readiness probes
- **Resource Metrics**: CPU and memory usage for HPA
- **Labels**: Consistent labeling for monitoring tools

### Integration Points

```yaml
# Prometheus metrics
deployment:
  ports:
    metrics: 9090
    
# Custom annotations for monitoring
deployment:
  podAnnotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "9090"
```

## Best Practices

### Chart Development

1. **Use drunk-lib**: Leverage the library for consistency
2. **Minimal Templates**: Keep application chart templates simple
3. **Sensible Defaults**: Provide good defaults in values.yaml
4. **Documentation**: Document all configuration options

### Configuration Management

1. **Environment Files**: Use separate values files per environment
2. **Secret Management**: Use external secret management systems
3. **Version Control**: Store values files with application code
4. **GitOps**: Integrate with GitOps workflows

### Security

1. **Least Privilege**: Use minimal required permissions
2. **Secret Rotation**: Implement secret rotation strategies
3. **Network Policies**: Implement network segmentation
4. **Image Security**: Use trusted base images and scan for vulnerabilities

---

This architecture enables **drunk-app** to provide a simple interface while **drunk-lib** handles the complexity of production-ready Kubernetes deployments. The separation of concerns allows for easy maintenance, consistent behavior, and flexible customization.