# Migration Guide: Nginx Ingress to Kubernetes Gateway API

This guide provides a detailed step-by-step process for migrating from traditional nginx Ingress to Kubernetes Gateway API using drunk-lib and drunk-app charts.

## Table of Contents

- [Overview](#overview)
- [Key Concepts](#key-concepts)
- [Step 1: Install Gateway API CRDs](#step-1-install-gateway-api-crds)
- [Step 2: Define GatewayClass](#step-2-define-gatewayclass)
- [Step 3: Create Gateway with drunk.dev Domain](#step-3-create-gateway-with-drunkdev-domain)
- [Step 4: Configure HTTPRoutes](#step-4-configure-httproutes)
- [Step 5: Side-by-Side Migration](#step-5-side-by-side-migration)
- [Step 6: Verification and Testing](#step-6-verification-and-testing)
- [Step 7: Complete Migration](#step-7-complete-migration)
- [Comparison Table](#comparison-table)
- [Troubleshooting](#troubleshooting)

## Overview

The Kubernetes Gateway API is the next generation of Ingress, offering:
- **Better role separation**: Platform teams manage Gateways, app teams manage Routes
- **More expressive**: Advanced routing with headers, query params, methods
- **Extensible**: Pluggable filters and custom resources
- **Standardized**: Consistent API across different implementations

## Key Concepts

### GatewayClass
Defines the controller implementation (like nginx, Istio, Envoy). Typically managed by cluster administrators.

### Gateway
Represents a network entry point (like a LoadBalancer). Defines listeners for protocols, ports, and hostnames.

### HTTPRoute
Defines how HTTP traffic from Gateway listeners routes to backend Services. Replaces Ingress.

### Comparison to Traditional Ingress

| Traditional Ingress | Gateway API |
|---------------------|-------------|
| IngressClass | GatewayClass |
| Ingress | Gateway + HTTPRoute |
| Single resource | Separated concerns |
| Limited routing | Advanced routing features |

## Step 1: Install Gateway API CRDs

First, install the Gateway API Custom Resource Definitions in your cluster:

```bash
# Install Gateway API CRDs (standard channel)
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml

# Verify installation
kubectl get crd | grep gateway
```

Expected output:
```
gatewayclasses.gateway.networking.k8s.io
gateways.gateway.networking.k8s.io
httproutes.gateway.networking.k8s.io
referencegrants.gateway.networking.k8s.io
```

## Step 2: Define GatewayClass

The GatewayClass is typically provided by your Gateway controller. Here are examples for popular controllers:

### Option A: NGINX Gateway Fabric (Recommended for nginx users)

```bash
# Install NGINX Gateway Fabric
kubectl apply -f https://github.com/nginxinc/nginx-gateway-fabric/releases/latest/download/nginx-gateway.yaml

# Verify GatewayClass
kubectl get gatewayclass
```

The default GatewayClass created is `nginx`.

### Option B: Custom GatewayClass Definition

If you need to create a custom GatewayClass:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: nginx
spec:
  controllerName: gateway.nginx.org/nginx-gateway-controller
  # Optional: Add parameters reference
  # parametersRef:
  #   group: gateway.nginx.org
  #   kind: NginxProxy
  #   name: nginx-proxy-config
```

Apply it:
```bash
kubectl apply -f gatewayclass.yaml
```

### Option C: Istio Gateway

```bash
# Install Istio
istioctl install --set profile=default

# GatewayClass is automatically created as 'istio'
kubectl get gatewayclass
```

## Step 3: Create Gateway with drunk.dev Domain

Now configure your drunk-app chart to create a Gateway for the `drunk.dev` domain.

### Step 3.1: Prepare TLS Certificate

First, create or obtain a TLS certificate for `*.drunk.dev`:

```bash
# Option 1: Using cert-manager (recommended)
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: drunk-dev-tls
  namespace: default
spec:
  secretName: drunk-dev-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - "*.drunk.dev"
    - "drunk.dev"
EOF

# Option 2: Using existing certificate
kubectl create secret tls drunk-dev-tls \
  --cert=path/to/cert.pem \
  --key=path/to/key.pem \
  -n default
```

### Step 3.2: Configure Gateway in values.yaml

Create a values file for your Gateway configuration:

```yaml
# values-gateway-drunk-dev.yaml

# Gateway configuration for drunk.dev domain
gateway:
  enabled: true
  gatewayClassName: "nginx"  # Use the GatewayClass from Step 2
  
  annotations:
    # Optional: Customize your gateway
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  
  listeners:
    # HTTP listener on port 80
    - name: http
      protocol: HTTP
      port: 80
      hostname: "*.drunk.dev"
      # Allow routes from same namespace
      allowedRoutes:
        namespaces:
          from: Same
    
    # HTTPS listener on port 443
    - name: https
      protocol: HTTPS
      port: 443
      hostname: "*.drunk.dev"
      tls:
        mode: Terminate
        certificateRefs:
          - kind: Secret
            name: drunk-dev-tls
      allowedRoutes:
        namespaces:
          from: Same

# Service configuration (required for HTTPRoute backend)
service:
  type: ClusterIP
  ports:
    - name: http
      port: 80
      targetPort: 8080
```

### Step 3.3: Deploy Gateway

```bash
# Install the Gateway
helm install my-gateway drunk-charts/drunk-app -f values-gateway-drunk-dev.yaml

# Verify Gateway is ready
kubectl get gateway
kubectl describe gateway my-gateway-drunk-app
```

Expected status:
```
NAME                  CLASS   ADDRESS         PROGRAMMED   AGE
my-gateway-drunk-app  nginx   10.96.100.100   True         1m
```

## Step 4: Configure HTTPRoutes

Now configure HTTPRoutes to direct traffic from the Gateway to your services.

### Step 4.1: Basic HTTPRoute Configuration

```yaml
# values-httproute-myapp.yaml

# HTTPRoute configuration
httpRoute:
  enabled: true
  
  # Reference the Gateway created in Step 3
  parentRefs:
    - name: my-gateway-drunk-app  # Name of your Gateway
      namespace: default           # Gateway namespace
      sectionName: https          # Optional: specific listener
  
  # Hostnames for this application
  hostnames:
    - "myapp.drunk.dev"
  
  # Routing rules
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: myapp-service
          port: 80
```

### Step 4.2: Advanced HTTPRoute with Multiple Paths

```yaml
httpRoute:
  enabled: true
  
  parentRefs:
    - name: my-gateway-drunk-app
  
  hostnames:
    - "api.drunk.dev"
  
  rules:
    # API v1 traffic
    - matches:
        - path:
            type: PathPrefix
            value: /api/v1
      backendRefs:
        - name: api-v1-service
          port: 8080
    
    # API v2 traffic
    - matches:
        - path:
            type: PathPrefix
            value: /api/v2
      backendRefs:
        - name: api-v2-service
          port: 8080
    
    # Admin traffic with header matching
    - matches:
        - path:
            type: PathPrefix
            value: /admin
          headers:
            - type: Exact
              name: X-Admin-Key
              value: secret-admin-key
      backendRefs:
        - name: admin-service
          port: 9090
```

### Step 4.3: Deploy HTTPRoute

```bash
# Deploy your application with HTTPRoute
helm install myapp drunk-charts/drunk-app \
  -f values-gateway-drunk-dev.yaml \
  -f values-httproute-myapp.yaml

# Verify HTTPRoute
kubectl get httproute
kubectl describe httproute myapp-drunk-app
```

## Step 5: Side-by-Side Migration

Run both Ingress and Gateway API in parallel during migration:

### Step 5.1: Current Nginx Ingress Configuration

```yaml
# Your existing ingress configuration
ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
  hosts:
    - host: "myapp.drunk.dev"
      path: "/"
      port: 80
  tls: myapp-tls
```

### Step 5.2: Parallel Configuration

```yaml
# values-migration.yaml - Run both together

# Keep existing Ingress enabled
ingress:
  enabled: true
  className: "nginx"
  hosts:
    - host: "myapp.drunk.dev"
      path: "/"
      port: 80
  tls: myapp-tls

# Add new Gateway API configuration
gateway:
  enabled: true
  gatewayClassName: "nginx"
  listeners:
    - name: https
      protocol: HTTPS
      port: 443
      hostname: "*.drunk.dev"
      tls:
        mode: Terminate
        certificateRefs:
          - name: drunk-dev-tls

httpRoute:
  enabled: true
  hostnames:
    - "myapp.drunk.dev"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: myapp-service
          port: 80
```

Deploy with:
```bash
helm upgrade myapp drunk-charts/drunk-app -f values-migration.yaml
```

### Step 5.3: Test Gateway API

```bash
# Get Gateway address
GATEWAY_IP=$(kubectl get gateway my-gateway-drunk-app -o jsonpath='{.status.addresses[0].value}')

# Test HTTPRoute (replace with your actual hostname)
curl -H "Host: myapp.drunk.dev" http://$GATEWAY_IP/

# Test HTTPS
curl -H "Host: myapp.drunk.dev" https://$GATEWAY_IP/ -k
```

## Step 6: Verification and Testing

### Step 6.1: Check Resource Status

```bash
# Check Gateway
kubectl get gateway -o wide
kubectl describe gateway my-gateway-drunk-app

# Check HTTPRoute
kubectl get httproute -o wide
kubectl describe httproute myapp-drunk-app

# Check backend service
kubectl get svc myapp-service
```

### Step 6.2: Verify Routing

```bash
# Test different routes
curl -v https://myapp.drunk.dev/
curl -v https://api.drunk.dev/api/v1/status
curl -v https://api.drunk.dev/api/v2/health

# Check Gateway logs
kubectl logs -n gateway-system -l app=gateway-controller --tail=100
```

### Step 6.3: Monitor Traffic

```bash
# Watch HTTPRoute status
kubectl get httproute -w

# Check events
kubectl get events --sort-by='.lastTimestamp' | grep -i gateway
```

## Step 7: Complete Migration

Once Gateway API is verified and working:

### Step 7.1: Disable Ingress

```yaml
# values-gateway-only.yaml

# Disable old Ingress
ingress:
  enabled: false

# Keep Gateway API enabled
gateway:
  enabled: true
  gatewayClassName: "nginx"
  listeners:
    - name: https
      protocol: HTTPS
      port: 443
      hostname: "*.drunk.dev"
      tls:
        mode: Terminate
        certificateRefs:
          - name: drunk-dev-tls

httpRoute:
  enabled: true
  hostnames:
    - "myapp.drunk.dev"
  rules:
    - backendRefs:
        - name: myapp-service
          port: 80
```

### Step 7.2: Apply Changes

```bash
# Update to Gateway-only configuration
helm upgrade myapp drunk-charts/drunk-app -f values-gateway-only.yaml

# Verify Ingress is removed
kubectl get ingress
```

### Step 7.3: Cleanup

```bash
# Remove old IngressClass if no longer needed
kubectl get ingressclass
# kubectl delete ingressclass nginx

# Verify only Gateway resources exist
kubectl get gateway,httproute
```

## Comparison Table

### Ingress vs Gateway API Configuration

| Feature | Nginx Ingress | Gateway API |
|---------|--------------|-------------|
| **Controller** | IngressClass: nginx | GatewayClass: nginx |
| **Entry Point** | Ingress resource | Gateway resource |
| **Routing** | Ingress spec | HTTPRoute resource |
| **Domain** | `spec.rules[].host` | Gateway: `listeners[].hostname`<br>HTTPRoute: `hostnames[]` |
| **TLS** | `spec.tls[]` | Gateway: `listeners[].tls` |
| **Path Matching** | `paths[].path` | HTTPRoute: `rules[].matches[].path` |
| **Backend** | `backend.service` | HTTPRoute: `backendRefs[]` |
| **Annotations** | `metadata.annotations` | Separate filter resources |

### Example Comparison

**Nginx Ingress:**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - myapp.drunk.dev
      secretName: myapp-tls
  rules:
    - host: myapp.drunk.dev
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: myapp
                port:
                  number: 80
```

**Gateway API Equivalent:**
```yaml
# Gateway (shared by multiple apps)
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: drunk-dev-gateway
spec:
  gatewayClassName: nginx
  listeners:
    - name: https
      protocol: HTTPS
      port: 443
      hostname: "*.drunk.dev"
      tls:
        mode: Terminate
        certificateRefs:
          - name: drunk-dev-tls
---
# HTTPRoute (per application)
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: myapp
spec:
  parentRefs:
    - name: drunk-dev-gateway
  hostnames:
    - myapp.drunk.dev
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: myapp
          port: 80
```

## Troubleshooting

### Gateway Not Ready

**Symptom:** Gateway status shows `Programmed: False`

**Solutions:**
```bash
# Check Gateway events
kubectl describe gateway my-gateway-drunk-app

# Check controller logs
kubectl logs -n gateway-system -l app=gateway-controller

# Verify GatewayClass exists
kubectl get gatewayclass

# Check if TLS secret exists
kubectl get secret drunk-dev-tls
```

### HTTPRoute Not Attaching to Gateway

**Symptom:** HTTPRoute status shows no parent

**Solutions:**
```bash
# Verify Gateway name and namespace match
kubectl get gateway -A

# Check HTTPRoute parent references
kubectl get httproute myapp-drunk-app -o yaml | grep -A 5 parentRefs

# Verify allowed routes in Gateway
kubectl get gateway my-gateway-drunk-app -o yaml | grep -A 10 allowedRoutes
```

### Certificate Issues

**Symptom:** HTTPS not working or certificate errors

**Solutions:**
```bash
# Check if certificate secret exists
kubectl get secret drunk-dev-tls

# Verify certificate in Gateway
kubectl get gateway my-gateway-drunk-app -o yaml | grep -A 5 certificateRefs

# Check cert-manager if using it
kubectl get certificate drunk-dev-tls
kubectl describe certificate drunk-dev-tls
```

### No Traffic Routing to Backend

**Symptom:** 404 or connection errors

**Solutions:**
```bash
# Verify backend service exists
kubectl get svc myapp-service

# Check HTTPRoute backend references
kubectl get httproute myapp-drunk-app -o yaml | grep -A 5 backendRefs

# Test service directly
kubectl port-forward svc/myapp-service 8080:80
curl http://localhost:8080/

# Check HTTPRoute status
kubectl describe httproute myapp-drunk-app
```

### Common Migration Issues

#### Issue: Multiple Gateways Conflict

**Solution:** Use unique listener names and ports, or separate by namespace:
```yaml
gateway:
  listeners:
    - name: https-prod
      port: 443
    - name: https-staging  
      port: 8443
```

#### Issue: Path Matching Differences

Nginx Ingress uses `/` by default as `Prefix`, Gateway API is explicit:
```yaml
# Gateway API - be explicit
rules:
  - matches:
      - path:
          type: PathPrefix  # or Exact
          value: /
```

#### Issue: Backend Service Not Found

Ensure service names match:
```yaml
# HTTPRoute must reference actual service name
backendRefs:
  - name: myapp-service  # Must match: kubectl get svc
    port: 80
```

## Best Practices

1. **Gateway Reuse**: Create one Gateway per domain/environment, share across applications
2. **Namespace Organization**: Keep Gateway in infrastructure namespace, HTTPRoutes with apps
3. **TLS Management**: Use cert-manager for automatic certificate management
4. **Testing**: Always test Gateway API in staging before production migration
5. **Monitoring**: Monitor Gateway and HTTPRoute status during migration
6. **Rollback Plan**: Keep Ingress configuration for quick rollback if needed

## Additional Resources

- [Kubernetes Gateway API Documentation](https://gateway-api.sigs.k8s.io/)
- [NGINX Gateway Fabric](https://docs.nginx.com/nginx-gateway-fabric/)
- [Gateway API Examples](../examples/gateway-api.yaml)
- [drunk-lib Gateway Templates](../drunk-lib.md#gateway-api-support)

## Summary

The migration from nginx Ingress to Gateway API involves:

1. ✅ Install Gateway API CRDs
2. ✅ Choose/configure GatewayClass (nginx)
3. ✅ Create Gateway with drunk.dev domain and TLS
4. ✅ Configure HTTPRoutes for applications
5. ✅ Run both systems in parallel for testing
6. ✅ Verify routing and traffic
7. ✅ Complete migration by disabling Ingress

The Gateway API provides better separation of concerns, more expressive routing, and improved extensibility while maintaining compatibility with your existing nginx-based infrastructure.
