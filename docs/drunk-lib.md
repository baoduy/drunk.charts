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
| **StatefulSet** | Stateful application deployment | `drunk-lib.statefulSet` |
| **Service** | Service discovery and load balancing | `drunk-lib.service` |
| **Ingress** | External access routing | `drunk-lib.ingress` |

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

### StatefulSet Template

**Template**: `drunk-lib.statefulSet`

Creates a Kubernetes StatefulSet for stateful applications.

#### Configuration:

```yaml
statefulset:
  enabled: true
  serviceName: "my-stateful-service"
  volumeClaimTemplates:
    - name: "data"
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
    - name: "http"
      port: 80
      targetPort: 8080
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
  tenantId: "your-tenant-id"
  vaultName: "your-key-vault"
  usePodIdentity: false
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
    storageClass: "fast-ssd"
    accessMode: "ReadWriteOnce"
    mountPath: "/app/data"
  logs:
    size: "5Gi"
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
      paths:
        - path: "/"
          pathType: "Prefix"
          port: 8080
  tls:
    - secretName: "myapp-tls"
      hosts:
        - "myapp.example.com"
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

## Usage Examples

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
    version: "1.0.7"
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