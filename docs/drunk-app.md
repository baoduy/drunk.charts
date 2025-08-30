# Drunk App Chart - Complete Guide

The **drunk-app** Helm chart provides a robust and flexible framework for deploying applications on Kubernetes clusters. Built on top of the **drunk-lib** library chart, it offers a comprehensive set of features for production-ready deployments.

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Configuration Reference](#configuration-reference)
- [Usage Examples](#usage-examples)
- [Advanced Features](#advanced-features)
- [Troubleshooting](#troubleshooting)

## Overview

### Key Features

- 🚀 **Simplified Deployment**: Deploy complex applications with minimal configuration
- ⚙️ **Flexible Configuration**: Fine-tune every aspect of your deployment
- 📈 **Auto-scaling**: Built-in horizontal pod autoscaler support
- 🔒 **Security**: Integrated secrets management and TLS configuration
- ⏰ **Job Scheduling**: Support for CronJobs and one-time Jobs
- 🌐 **Ingress Management**: Complete external access configuration
- 💾 **Storage**: Flexible persistent and ephemeral storage options

### Architecture

The drunk-app chart leverages the **drunk-lib** library chart for all its core templates, providing:
- Consistent deployment patterns
- Reusable components
- Best practices built-in
- Easy maintenance and updates

## Installation

### Prerequisites

- Kubernetes 1.19+
- Helm 3.0+

### Add Repository

```bash
helm repo add drunk-charts https://baoduy.github.io/drunk.charts/drunk-app
helm repo update
```

### Basic Installation

```bash
helm install my-app drunk-charts/drunk-app
```

### Installation with Custom Values

```bash
helm install my-app drunk-charts/drunk-app -f my-values.yaml
```

## Configuration Reference

### Global Settings

Global settings that affect all resources in the deployment.

| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `global.image` | Docker image repository | `""` | ✅ |
| `global.tag` | Docker image tag | `"latest"` | ❌ |
| `global.imagePullPolicy` | Image pull policy | `"IfNotPresent"` | ❌ |
| `global.imagePullSecret` | Image pull secret name | `""` | ❌ |
| `global.storageClassName` | Default storage class | `""` | ❌ |

#### Init Container

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.initContainer.image` | Init container image | `""` |
| `global.initContainer.command` | Init container command | `[]` |

### Application Configuration

#### Basic Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `nameOverride` | Override application name | `""` |
| `fullnameOverride` | Override full resource names | `""` |

#### Deployment Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `deployment.enabled` | Enable main deployment | `true` |
| `deployment.replicaCount` | Number of replicas | `1` |
| `deployment.command` | Override container command | `[]` |
| `deployment.args` | Container arguments | `[]` |
| `deployment.podAnnotations` | Pod annotations | `{}` |

#### Ports Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `deployment.ports.http` | HTTP port | `8080` |
| `deployment.ports.https` | HTTPS port | `8443` |
| `deployment.ports.tcp` | TCP port | `9090` |

#### Health Checks

| Parameter | Description | Default |
|-----------|-------------|---------|
| `deployment.liveness` | Liveness probe path | `""` |
| `deployment.readiness` | Readiness probe path | `""` |
| `deployment.livenessProbe` | Custom liveness probe | `{}` |
| `deployment.readinessProbe` | Custom readiness probe | `{}` |

### Environment Configuration

#### Environment Variables

```yaml
env:
  NODE_ENV: "production"
  DATABASE_URL: "postgresql://..."
  LOG_LEVEL: "info"
```

#### ConfigMap

```yaml
configMap:
  app.properties: |
    debug=false
    timeout=30
  config.json: |
    {"feature": "enabled"}
```

#### External ConfigMaps

```yaml
configFrom:
  - "shared-config"
  - "environment-config"
```

### Secrets Management

#### Inline Secrets

```yaml
secrets:
  DATABASE_PASSWORD: "secret-password"
  API_KEY: "your-api-key"
  JWT_SECRET: "jwt-signing-secret"
```

#### External Secrets

```yaml
secretFrom:
  - "database-credentials"
  - "external-api-keys"
```

#### Azure Key Vault Integration

```yaml
secretProvider:
  enabled: true
  name: "my-key-vault"
  tenantId: "your-tenant-id"
  vaultName: "your-vault-name"
  useWorkloadIdentity: true
  objects:
    - objectName: "database-password"
      objectType: "secret"
  secretObjects:
    - secretName: "app-secrets"
      type: "Opaque"
      data:
        - key: "DATABASE_PASSWORD"
          objectName: "database-password"
```

### Storage Configuration

#### Persistent Volumes

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
```

#### Ephemeral Storage

```yaml
volumes:
  tmp:
    mountPath: "/tmp"
    emptyDir: true
  cache:
    mountPath: "/app/cache"
    emptyDir: true
    size: "1Gi"  # Optional size limit
```

### Networking Configuration

#### Service Configuration

```yaml
service:
  type: "ClusterIP"  # ClusterIP, NodePort, LoadBalancer
  ports:
    - name: "http"
      port: 80
      targetPort: 8080
    - name: "metrics"
      port: 9090
      targetPort: 9090
```

#### Ingress Configuration

```yaml
ingress:
  enabled: true
  className: "nginx"
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: "/"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
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

### Auto-scaling Configuration

```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
    scaleUp:
      stabilizationWindowSeconds: 60
```

### Jobs and CronJobs

#### CronJobs

```yaml
cronJobs:
  - name: "backup"
    schedule: "0 2 * * *"  # Daily at 2 AM
    command: ["/app/backup.sh"]
    restartPolicy: "OnFailure"
    concurrencyPolicy: "Forbid"
  - name: "cleanup"
    schedule: "0 4 * * 0"  # Weekly on Sunday at 4 AM
    command: ["/app/cleanup.sh"]
```

#### One-time Jobs

```yaml
jobs:
  - name: "migration"
    command: ["/app/migrate.sh"]
    args: ["--force"]
    restartPolicy: "Never"
  - name: "init-data"
    command: ["/app/seed.sh"]
```

### Security Configuration

#### Pod Security Context

```yaml
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000

securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
```

#### Service Account

```yaml
serviceAccount:
  create: true
  name: "my-app-sa"
  annotations:
    iam.gke.io/gcp-service-account: "my-app@project.iam.gserviceaccount.com"
```

### Resource Management

```yaml
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"
```

### Node Scheduling

```yaml
nodeSelector:
  kubernetes.io/arch: "amd64"
  node-pool: "application"

tolerations:
  - key: "node-pool"
    operator: "Equal"
    value: "application"
    effect: "NoSchedule"

affinity:
  nodeAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        preference:
          matchExpressions:
            - key: "node-type"
              operator: "In"
              values: ["high-memory"]
```

## Usage Examples

### Simple Web Application

```yaml
global:
  image: "nginx"
  tag: "1.21"

deployment:
  ports:
    http: 80

ingress:
  enabled: true
  hosts:
    - host: "www.example.com"
      paths:
        - path: "/"
          pathType: "Prefix"
```

### Microservice with Database

```yaml
global:
  image: "myapp/api"
  tag: "v1.2.3"

env:
  NODE_ENV: "production"
  PORT: "8080"

secrets:
  DATABASE_PASSWORD: "secret123"

deployment:
  ports:
    http: 8080
  liveness: "/health"
  readiness: "/ready"

volumes:
  data:
    size: "20Gi"
    mountPath: "/app/data"

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
```

### Batch Processing Application

```yaml
global:
  image: "myapp/processor"
  tag: "latest"

# Disable main deployment for cron-only app
deployment:
  enabled: false

cronJobs:
  - name: "daily-process"
    schedule: "0 1 * * *"
    command: ["/app/process.sh"]
    restartPolicy: "OnFailure"

volumes:
  workspace:
    size: "50Gi"
    mountPath: "/workspace"
```

## Advanced Features

### StatefulSet Deployment

```yaml
statefulset:
  enabled: true
  serviceName: "my-stateful-app"
  volumeClaimTemplates:
    - name: "data"
      storage: "10Gi"
      storageClassName: "fast-ssd"
      accessModes: ["ReadWriteOnce"]
```

### Multiple Container Deployment

```yaml
# Use initContainer for setup
global:
  initContainer:
    image: "myapp/init"
    command: ["/setup.sh"]

# Main container configuration
global:
  image: "myapp/main"

# Additional containers via sidecar pattern
# (handled through custom templates)
```

### TLS Certificate Management

```yaml
tlsSecrets:
  myapp-tls:
    enabled: true
    crt: |
      -----BEGIN CERTIFICATE-----
      ...
      -----END CERTIFICATE-----
    key: |
      -----BEGIN PRIVATE KEY-----
      ...
      -----END PRIVATE KEY-----
```

## Troubleshooting

### Common Issues

#### Pod Not Starting

1. Check image name and tag:
   ```bash
   kubectl describe pod <pod-name>
   ```

2. Verify image pull secrets:
   ```bash
   kubectl get secret <imagePullSecret-name> -o yaml
   ```

#### Configuration Issues

1. Check ConfigMap creation:
   ```bash
   kubectl get configmap -l app.kubernetes.io/name=<app-name>
   ```

2. Validate environment variables:
   ```bash
   kubectl exec <pod-name> -- env
   ```

#### Ingress Not Working

1. Check ingress configuration:
   ```bash
   kubectl describe ingress <ingress-name>
   ```

2. Verify ingress controller logs:
   ```bash
   kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
   ```

### Debug Commands

```bash
# Check all resources
kubectl get all -l app.kubernetes.io/name=<app-name>

# View pod logs
kubectl logs -f <pod-name>

# Debug pod issues
kubectl describe pod <pod-name>

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp
```

## Support

- **Documentation**: [docs/README.md](./README.md)
- **Issues**: [GitHub Issues](https://github.com/baoduy/drunk.charts/issues)
- **Author**: [Steven Hoang](https://drunkcoding.net)

---

*For more examples and advanced configurations, see the [examples directory](./examples/).*