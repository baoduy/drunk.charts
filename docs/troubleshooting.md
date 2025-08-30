# Troubleshooting Guide

This guide helps you diagnose and resolve common issues when deploying applications with the drunk-app Helm chart.

## Table of Contents

- [Common Issues](#common-issues)
- [Debugging Commands](#debugging-commands)
- [Pod Issues](#pod-issues)
- [Networking Issues](#networking-issues)
- [Storage Issues](#storage-issues)
- [Configuration Issues](#configuration-issues)
- [Performance Issues](#performance-issues)
- [Security Issues](#security-issues)

## Common Issues

### 1. Pod Not Starting

#### Symptom
```bash
$ kubectl get pods
NAME                     READY   STATUS             RESTARTS   AGE
my-app-drunk-app-xxx     0/1     CrashLoopBackOff   5          10m
```

#### Diagnosis
```bash
# Check pod events
kubectl describe pod my-app-drunk-app-xxx

# Check container logs
kubectl logs my-app-drunk-app-xxx

# Check previous container logs (if restarting)
kubectl logs my-app-drunk-app-xxx --previous
```

#### Common Causes & Solutions

**Image Pull Error**
```yaml
# Problem: Image not found
Events:
  Warning  Failed  ErrImagePull: Failed to pull image "myapp:latest"

# Solution: Check image name and tag
global:
  image: "correct-registry/myapp"
  tag: "v1.0.0"
  imagePullSecret: "registry-credentials"  # If private registry
```

**Application Error**
```bash
# Problem: Application crashes on startup
# Check application logs
kubectl logs my-app-drunk-app-xxx

# Solution: Common fixes
env:
  # Add required environment variables
  DATABASE_URL: "your-database-url"
  LOG_LEVEL: "debug"  # Enable debug logging
```

**Resource Constraints**
```yaml
# Problem: OOMKilled or CPU throttling
# Solution: Increase resource limits
resources:
  limits:
    memory: "512Mi"  # Increase from default
    cpu: "500m"
  requests:
    memory: "256Mi"
    cpu: "100m"
```

### 2. Health Check Failures

#### Symptom
```bash
$ kubectl describe pod my-app-xxx
Events:
  Warning  Unhealthy  Liveness probe failed: HTTP probe failed
```

#### Solutions

**Incorrect Health Check Paths**
```yaml
deployment:
  liveness: "/health"    # Ensure this endpoint exists
  readiness: "/ready"    # Ensure this endpoint exists
```

**Health Check Timing**
```yaml
deployment:
  livenessProbe:
    httpGet:
      path: "/health"
      port: 8080
    initialDelaySeconds: 30  # Increase startup time
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 3
  
  readinessProbe:
    httpGet:
      path: "/ready"
      port: 8080
    initialDelaySeconds: 5
    periodSeconds: 5
    timeoutSeconds: 3
```

**Wrong Port Configuration**
```yaml
deployment:
  ports:
    http: 8080  # Ensure this matches your app's port

# Health checks should use the correct port
deployment:
  livenessProbe:
    httpGet:
      port: 8080  # Match the application port
```

### 3. Service Not Accessible

#### Symptom
```bash
$ kubectl get svc
NAME               TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
my-app-drunk-app   ClusterIP   10.96.1.100    <none>        80/TCP    5m

# But connection fails
$ kubectl port-forward svc/my-app-drunk-app 8080:80
error: unable to forward port
```

#### Diagnosis & Solutions

**Port Mismatch**
```yaml
# Ensure service ports match deployment ports
deployment:
  ports:
    http: 8080

service:
  ports:
    - name: "http"
      port: 80        # External port
      targetPort: 8080  # Should match deployment.ports.http
```

**Pod Selector Issues**
```bash
# Check if service selectors match pod labels
kubectl get pods --show-labels
kubectl describe svc my-app-drunk-app

# Labels should match between service and pods
```

### 4. Ingress Not Working

#### Symptom
```bash
$ kubectl get ingress
NAME             CLASS   HOSTS              ADDRESS   PORTS   AGE
my-app-ingress   nginx   myapp.example.com           80      5m

# But external access fails
$ curl https://myapp.example.com
curl: (7) Failed to connect
```

#### Solutions

**Ingress Controller Missing**
```bash
# Check if ingress controller is running
kubectl get pods -n ingress-nginx

# Install if missing (example for nginx)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
```

**DNS Configuration**
```bash
# Check if DNS points to ingress controller
nslookup myapp.example.com

# Should point to your ingress controller's external IP
kubectl get svc -n ingress-nginx
```

**TLS Certificate Issues**
```bash
# Check certificate status
kubectl describe certificate my-app-tls

# Check cert-manager logs if using cert-manager
kubectl logs -n cert-manager -l app=cert-manager
```

**Ingress Configuration**
```yaml
ingress:
  enabled: true
  className: "nginx"  # Ensure correct ingress class
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  hosts:
    - host: "myapp.example.com"
      paths:
        - path: "/"
          pathType: "Prefix"
          port: 80  # Should match service port
  tls:
    - secretName: "myapp-tls"
      hosts:
        - "myapp.example.com"
```

## Debugging Commands

### Pod Debugging
```bash
# Get pod status
kubectl get pods -o wide

# Detailed pod information
kubectl describe pod <pod-name>

# Pod logs
kubectl logs <pod-name>
kubectl logs <pod-name> --previous
kubectl logs <pod-name> -f  # Follow logs

# Execute commands in pod
kubectl exec -it <pod-name> -- /bin/sh
kubectl exec -it <pod-name> -- curl localhost:8080/health

# Debug pod networking
kubectl exec -it <pod-name> -- netstat -ln
kubectl exec -it <pod-name> -- ps aux
```

### Resource Debugging
```bash
# Check all resources
kubectl get all -l app.kubernetes.io/name=drunk-app

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp

# Check resource usage
kubectl top pods
kubectl top nodes

# Check storage
kubectl get pvc
kubectl describe pvc <pvc-name>
```

### Configuration Debugging
```bash
# Check ConfigMaps
kubectl get configmap
kubectl describe configmap <configmap-name>

# Check Secrets (content is base64 encoded)
kubectl get secrets
kubectl describe secret <secret-name>

# View generated resources before applying
helm template my-app drunk-charts/drunk-app -f values.yaml
```

### Network Debugging
```bash
# Check services
kubectl get svc
kubectl describe svc <service-name>

# Check endpoints (should show pod IPs)
kubectl get endpoints

# Check ingress
kubectl get ingress
kubectl describe ingress <ingress-name>

# Check DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup <service-name>
```

## Pod Issues

### CrashLoopBackOff
```bash
# Check exit code and reason
kubectl describe pod <pod-name>

# Common exit codes:
# 0: Success
# 1: General error
# 125: Docker daemon error
# 126: Container command not executable
# 127: Container command not found
# 128+n: Fatal error signal "n"
```

### ImagePullBackOff
```yaml
# Solutions:
# 1. Check image exists
docker pull your-image:tag

# 2. Add image pull secret for private registries
global:
  imagePullSecret: "registry-credentials"

# 3. Create image pull secret
kubectl create secret docker-registry registry-credentials \
  --docker-server=your-registry.com \
  --docker-username=your-username \
  --docker-password=your-password \
  --docker-email=your-email@example.com
```

### Pending Pods
```bash
# Check node resources
kubectl describe nodes

# Check if nodes have required labels
kubectl get nodes --show-labels

# Common issues:
# - Insufficient CPU/Memory
# - No nodes match nodeSelector
# - Taints prevent scheduling
```

## Networking Issues

### Service Discovery
```bash
# Test service discovery within cluster
kubectl exec -it <pod-name> -- nslookup <service-name>
kubectl exec -it <pod-name> -- curl http://<service-name>

# Check if service has endpoints
kubectl get endpoints <service-name>
```

### Port Issues
```yaml
# Ensure ports are correctly configured throughout the stack
deployment:
  ports:
    http: 8080  # Application port

service:
  ports:
    - name: "http"
      port: 80        # Service port
      targetPort: 8080  # Should match deployment port

ingress:
  hosts:
    - host: "example.com"
      paths:
        - path: "/"
          port: 80  # Should match service port
```

## Storage Issues

### PVC Pending
```bash
# Check PVC status
kubectl describe pvc <pvc-name>

# Common issues:
# 1. No storage class available
kubectl get storageclass

# 2. Insufficient storage
# Check cluster storage capacity
```

### Mount Issues
```yaml
# Ensure correct mount paths and permissions
volumes:
  data:
    mountPath: "/app/data"
    size: "10Gi"
    # Ensure the path exists in container and is writable
```

## Configuration Issues

### Environment Variables Not Set
```bash
# Check if environment variables are correctly injected
kubectl exec -it <pod-name> -- env | grep <VARIABLE_NAME>

# Check ConfigMap content
kubectl get configmap <configmap-name> -o yaml

# Check Secret content
kubectl get secret <secret-name> -o yaml
```

### ConfigMap/Secret Not Found
```yaml
# Ensure ConfigMap/Secret names match
configFrom:
  - "existing-configmap-name"  # Must exist

secretFrom:
  - "existing-secret-name"     # Must exist
```

## Performance Issues

### High CPU Usage
```bash
# Check resource usage
kubectl top pods

# Check resource limits
kubectl describe pod <pod-name>

# Solutions:
# 1. Increase CPU limits
resources:
  limits:
    cpu: "1000m"  # Increase as needed

# 2. Enable auto-scaling
autoscaling:
  enabled: true
  targetCPUUtilizationPercentage: 70
```

### High Memory Usage
```yaml
# Increase memory limits
resources:
  limits:
    memory: "1Gi"
  requests:
    memory: "512Mi"

# For Java applications
env:
  JAVA_OPTS: "-Xmx512m"  # Should be less than memory limit
```

### Slow Response Times
```bash
# Check if health checks are failing
kubectl get pods

# Check application logs for errors
kubectl logs <pod-name>

# Test direct pod connection
kubectl port-forward pod/<pod-name> 8080:8080
curl http://localhost:8080
```

## Security Issues

### Pod Security Policy Violations
```bash
# Check pod security context
kubectl get pod <pod-name> -o yaml | grep -A 10 securityContext

# Common fixes:
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000

securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
```

### Secret Access Issues
```bash
# Check secret permissions
kubectl auth can-i get secrets --as=system:serviceaccount:<namespace>:<service-account>

# For Azure Key Vault integration
kubectl describe secretproviderclass <spc-name>
kubectl logs -n kube-system -l app=secrets-store-csi-driver
```

## Getting Help

### Enable Debug Logging
```yaml
# For Helm debugging
env:
  LOG_LEVEL: "debug"
  DEBUG: "true"

# Check all resources created by Helm
helm get all <release-name>
```

### Collect Diagnostic Information
```bash
#!/bin/bash
# Diagnostic script
echo "=== Pods ==="
kubectl get pods -o wide

echo "=== Events ==="
kubectl get events --sort-by=.metadata.creationTimestamp

echo "=== Logs ==="
kubectl logs -l app.kubernetes.io/name=drunk-app --tail=50

echo "=== Resources ==="
kubectl top pods
kubectl top nodes

echo "=== Configuration ==="
kubectl get configmap -o yaml
kubectl get secrets
```

### Contact Support
- **GitHub Issues**: [Report bugs](https://github.com/baoduy/drunk.charts/issues)
- **Documentation**: [Full docs](./README.md)
- **Examples**: [Configuration examples](./examples/)

---

*Remember: Most issues can be resolved by carefully checking logs and resource configurations. When in doubt, start with `kubectl describe` and `kubectl logs`.*