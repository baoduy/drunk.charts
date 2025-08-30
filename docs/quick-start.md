# Quick Start Guide

Get your application deployed to Kubernetes in just a few minutes with the drunk-app Helm chart.

## Prerequisites

- Kubernetes cluster (v1.19+)
- Helm 3.0+
- Docker image of your application

## 🚀 5-Minute Deployment

### 1. Add the Helm Repository

```bash
helm repo add drunk-charts https://baoduy.github.io/drunk.charts/drunk-app
helm repo update
```

### 2. Create Your Values File

Create a `my-app-values.yaml` file with your application configuration:

```yaml
# my-app-values.yaml
global:
  image: "your-registry/your-app"
  tag: "v1.0.0"
  imagePullPolicy: "IfNotPresent"

# Basic deployment configuration
deployment:
  enabled: true
  ports:
    http: 8080
  replicaCount: 2

# Environment variables
env:
  NODE_ENV: "production"
  DATABASE_URL: "your-database-connection"

# Ingress for external access
ingress:
  enabled: true
  hosts:
    - host: "myapp.example.com"
      paths:
        - path: "/"
          pathType: "Prefix"
  tls:
    - secretName: "myapp-tls"
      hosts:
        - "myapp.example.com"
```

### 3. Deploy Your Application

```bash
helm install my-app drunk-charts/drunk-app -f my-app-values.yaml
```

### 4. Verify Deployment

```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/name=my-app

# Check service
kubectl get svc -l app.kubernetes.io/name=my-app

# Check ingress (if enabled)
kubectl get ingress
```

## 🔧 Common Configurations

### Database Connection with Secrets

```yaml
# Store sensitive data in Kubernetes secrets
secrets:
  DATABASE_PASSWORD: "your-secret-password"
  API_KEY: "your-api-key"

# Reference existing secrets
secretFrom:
  - "external-database-secret"
```

### Auto-scaling

```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
```

### Health Checks

```yaml
deployment:
  liveness: "/health"
  readiness: "/ready"
  ports:
    http: 8080
```

### Persistent Storage

```yaml
volumes:
  data:
    mountPath: "/app/data"
    size: "10Gi"
    storageClass: "standard"
```

## 🎯 Next Steps

- **[Complete Configuration Guide](./drunk-app.md)** - Learn about all available options
- **[Configuration Examples](./examples/)** - See real-world examples
- **[Troubleshooting Guide](./troubleshooting.md)** - Common issues and solutions

## 💡 Pro Tips

1. **Use Helm diff**: Install the `helm-diff` plugin to preview changes before applying
2. **Environment-specific values**: Create separate values files for different environments
3. **GitOps**: Store your values files in version control alongside your application code
4. **Resource limits**: Always set resource requests and limits for production deployments

## 🔄 Upgrading Your Application

```bash
# Upgrade with new image tag
helm upgrade my-app drunk-charts/drunk-app -f my-app-values.yaml --set global.tag=v1.1.0

# Rollback if needed
helm rollback my-app 1
```

---

Need help? Check our [full documentation](./README.md) or [open an issue](https://github.com/baoduy/drunk.charts/issues).