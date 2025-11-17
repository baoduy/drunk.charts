# drunk-k8s-gateway

Kubernetes Gateway API CRDs and cluster-level Gateway resources for drunk.charts

## Overview

The `drunk-k8s-gateway` chart automates the installation and configuration of:

- **Gateway API CRDs** - Core custom resource definitions for Gateway API
- **GatewayClass** - Defines which Gateway controller implementation to use
- **Gateway Resources** - Shared network entry points for applications
- **cert-manager Integration** - Automatic TLS certificate management

This chart reuses [drunk-lib](../drunk-lib) to maintain consistency across the drunk.charts ecosystem.

## Features

- ✅ Automated Gateway API CRD installation
- ✅ Configurable GatewayClass resources
- ✅ Multi-domain Gateway support
- ✅ Integrated cert-manager ClusterIssuer configuration
- ✅ Support for both standard and experimental Gateway API features
- ✅ NGINX Gateway Fabric, Istio, and other controller compatibility

## Prerequisites

- Kubernetes 1.25+ cluster
- kubectl configured to access your cluster
- Helm 3.8+
- (Optional) cert-manager for automatic TLS certificate management
- A Gateway controller implementation (NGINX Gateway Fabric, Istio, etc.)

## Installation

### Quick Start

```bash
# Install CRDs first
./scripts/install-crds.sh

# Install the chart with default settings
helm install gateway drunk-charts/drunk-k8s-gateway

# Or install from local directory
helm install gateway . -n gateway-system --create-namespace
```

### Step-by-Step Installation

#### 1. Build the Chart (For Local Development)

If you're working with the chart locally, build it first to download Gateway API CRDs:

```bash
# Build the chart (downloads Gateway API CRDs automatically)
./build.sh

# This will:
# - Download Gateway API CRDs to templates/gateway-api-crds.yaml
# - Update chart dependencies
# - Package the chart
```

**Note:** Pre-built charts from the Helm repository already include the CRDs.

#### 2. Install Gateway API CRDs

The Gateway API CRDs are now included in the chart and will be installed automatically.

**Option A: Install with Helm (Recommended)**

```bash
# CRDs are included in the chart
helm install gateway drunk-charts/drunk-k8s-gateway \
  -n gateway-system \
  --create-namespace
```

**Option B: Install CRDs separately (if needed)**

If you prefer to install CRDs separately or need to update them independently:

```bash
# Using the provided script
cd scripts
chmod +x install-crds.sh
./install-crds.sh

# Or manually with kubectl
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml

# For experimental features (GRPC, TCP, TLS, UDP routes)
./install-crds.sh --channel experimental
```

Verify installation:

```bash
kubectl get crd | grep gateway
```

Expected output:

```
gatewayclasses.gateway.networking.k8s.io
gateways.gateway.networking.k8s.io
httproutes.gateway.networking.k8s.io
referencegrants.gateway.networking.k8s.io
```

#### 3. Install Gateway Controller

Choose and install a Gateway controller implementation. You now have two options for **NGINX Gateway Fabric**:

### Option A: Use Vendored Subchart (Helm Dependency)

This chart vendors the official [`nginx-gateway-fabric` Helm chart](https://github.com/nginx/nginx-gateway-fabric) (version `2.2.1`). Enable it via values to install the controller and data plane alongside your Gateway resources.

Minimal values enabling the subchart (disables duplicate parent `GatewayClass`):

```yaml
gatewayClass:
  enabled: false # Let the subchart create the GatewayClass

nginxGatewayFabric:
  enabled: true # Condition that pulls in the dependency

nginx-gateway-fabric: # Configuration for the child chart
  nginxGateway:
    gatewayClassName: nginx
  nginx:
    service:
      type: NodePort # For kind/minikube; use LoadBalancer in cloud
```

Install with the above saved as `values-ngf.yaml`:

```bash
helm upgrade --install gateway ./drunk-k8s-gateway \
  -n drunk-gateway --create-namespace \
  -f values-ngf.yaml
```

You can override any upstream chart setting under the `nginx-gateway-fabric:` key. For example to set replicas:

```bash
helm upgrade --install gateway ./drunk-k8s-gateway \
  -n drunk-gateway --create-namespace \
  --set gatewayClass.enabled=false \
  --set nginxGatewayFabric.enabled=true \
  --set nginx-gateway-fabric.nginxGateway.replicas=2 \
  --set nginx-gateway-fabric.nginx.replicas=2
```

Experimental Gateway API support (requires installing experimental CRDs beforehand):

```bash
--set nginx-gateway-fabric.nginxGateway.gwAPIExperimentalFeatures.enable=true
```

### Option B: Install NGINX Gateway Fabric Separately

If you prefer independent lifecycle management, install the controller directly from the upstream OCI registry:

```bash
helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
  --version 2.2.1 \
  --create-namespace -n nginx-gateway
```

Or (legacy manifest method):

```bash
kubectl apply -f https://github.com/nginxinc/nginx-gateway-fabric/releases/latest/download/nginx-gateway.yaml
```

### Other Controllers

**Istio:**

```bash
istioctl install --set profile=default
```

**Other implementations:** See [Gateway API Implementations](https://gateway-api.sigs.k8s.io/implementations/)

#### 4. (Optional) Install cert-manager

You have two options to install cert-manager:

**Option A: Install as a dependency (Recommended)**

cert-manager can be installed automatically with this chart:

```bash
# Install drunk-k8s-gateway with cert-manager
helm install gateway drunk-charts/drunk-k8s-gateway \
  --set certManager.install=true \
  --set certManager.installCRDs=true \
  -n gateway-system \
  --create-namespace

# Verify cert-manager installation
kubectl get pods -n cert-manager
```

**Option B: Install separately**

Install cert-manager independently before this chart:

```bash
# Install cert-manager using Helm
helm install cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --version v1.19.1 \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true

# Verify installation
kubectl get pods -n cert-manager
```

For more information: [cert-manager documentation](https://cert-manager.io/docs/installation/helm/)

#### 5. Install drunk-k8s-gateway Chart

```bash
# Create a values file
cat > values-production.yaml << EOF
gatewayClass:
  enabled: true
  name: nginx
  controllerName: gateway.nginx.org/nginx-gateway-controller

gateway:
  enabled: true
  name: shared-gateway
  gatewayClassName: nginx
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      hostname: "*"
      allowedRoutes:
        namespaces:
          from: All
    - name: https
      protocol: HTTPS
      port: 443
      hostname: "*"
      tls:
        mode: Terminate
        certificateRefs:
          - kind: Secret
            name: wildcard-tls
      allowedRoutes:
        namespaces:
          from: All
EOF

# Install the chart
helm install gateway drunk-charts/drunk-k8s-gateway \
  -f values-production.yaml \
  -n gateway-system \
  --create-namespace
```

## Configuration

### Basic Configuration

| Parameter                           | Description                                  | Default                                      |
| ----------------------------------- | -------------------------------------------- | -------------------------------------------- |
| `gatewayAPI.version`                | Gateway API version embedded at build        | `v1.2.0`                                     |
| `gatewayAPI.channel`                | Installation channel (standard/experimental) | `standard`                                   |
| `gatewayClass.enabled`              | Create GatewayClass resource                 | `true`                                       |
| `gatewayClass.name`                 | Name of the GatewayClass                     | `nginx`                                      |
| `gatewayClass.controllerName`       | Controller identifier                        | `gateway.nginx.org/nginx-gateway-controller` |
| `gateway.enabled`                   | Create default Gateway                       | `false`                                      |
| `gateway.name`                      | Name of the Gateway                          | `shared-gateway`                             |
| `gateway.gatewayClassName`          | GatewayClass to use                          | `nginx`                                      |
| `certManager.enabled`               | Install cert-manager as dependency           | `false`                                      |
| `certManager.installCRDs`           | Install cert-manager CRDs                    | `true`                                       |
| `certManager.clusterIssuersEnabled` | Create ClusterIssuers (ACME)                 | `false`                                      |

### Dealing with Existing Gateway API CRDs

If Gateway API CRDs were installed previously (manually or by another chart), `helm install` may fail with an ownership error similar to:

```
Error: Unable to continue with install: CustomResourceDefinition "gatewayclasses.gateway.networking.k8s.io" ... exists and cannot be imported ... missing key "app.kubernetes.io/managed-by" ... missing key "meta.helm.sh/release-name"
```

Options to resolve:

1. Adopt existing CRDs into this release (recommended when versions match):
   ```bash
   ./scripts/adopt-crds.sh gateway drunk-gateway
   helm upgrade --install gateway ./drunk-k8s-gateway \
     -n drunk-gateway --create-namespace -f values.local.yaml
   ```
2. Skip CRDs during install (if you are sure they are present and correct):
   ```bash
   helm install gateway ./drunk-k8s-gateway --skip-crds \
     -n drunk-gateway --create-namespace -f values.local.yaml
   ```
3. Remove and reinstall CRDs (clean slate):
   ```bash
   kubectl delete crd gatewayclasses.gateway.networking.k8s.io \
     gateways.gateway.networking.k8s.io httproutes.gateway.networking.k8s.io \
     tcproutes.gateway.networking.k8s.io tlsroutes.gateway.networking.k8s.io \
     udproutes.gateway.networking.k8s.io grpcroutes.gateway.networking.k8s.io \
     referencegrants.gateway.networking.k8s.io
   helm upgrade --install gateway ./drunk-k8s-gateway \
     -n drunk-gateway --create-namespace -f values.local.yaml
   ```

Adoption simply adds Helm ownership annotations:
`meta.helm.sh/release-name`, `meta.helm.sh/release-namespace` and label `app.kubernetes.io/managed-by=Helm`.

### Domain-Specific Gateway Example

Create a Gateway specifically for your domain (e.g., `drunk.dev`):

```yaml
# values-drunk-dev.yaml
gatewayClass:
  enabled: true
  name: nginx
  controllerName: gateway.nginx.org/nginx-gateway-controller

domains:
  - name: drunk-dev
    enabled: true
    gatewayClassName: nginx
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
    listeners:
      - name: http
        protocol: HTTP
        port: 80
        hostname: "*.drunk.dev"
        allowedRoutes:
          namespaces:
            from: Same
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
```

Install:

```bash
helm install drunk-gateway drunk-charts/drunk-k8s-gateway \
  -f values-drunk-dev.yaml \
  -n default
```

### cert-manager Integration

**Prerequisites:** Ensure cert-manager is installed (see Step 3 above).

Automatically create ClusterIssuers for TLS certificate management:

```yaml
# values-with-certmanager.yaml
certManager:
  enabled: true
  clusterIssuers:
    - name: letsencrypt-prod
      email: admin@drunk.dev
      server: https://acme-v02.api.letsencrypt.org/directory
      privateKeySecretRef:
        name: letsencrypt-prod-key
      solvers:
        - http01:
            gatewayHTTPRoute:
              parentRefs:
                - kind: Gateway
                  name: shared-gateway
                  namespace: default

    - name: letsencrypt-staging
      email: admin@drunk.dev
      server: https://acme-staging-v02.api.letsencrypt.org/directory
      privateKeySecretRef:
        name: letsencrypt-staging-key
      solvers:
        - http01:
            gatewayHTTPRoute:
              parentRefs:
                - kind: Gateway
                  name: shared-gateway
                  namespace: default

gateway:
  enabled: true
  name: shared-gateway
  gatewayClassName: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  listeners:
    - name: https
      protocol: HTTPS
      port: 443
      hostname: "*.drunk.dev"
      tls:
        mode: Terminate
        certificateRefs:
          - kind: Secret
            name: drunk-dev-tls
```

For wildcard certificates, use DNS-01 challenge:

```yaml
certManager:
  enabled: true
  clusterIssuers:
    - name: letsencrypt-prod
      email: admin@drunk.dev
      server: https://acme-v02.api.letsencrypt.org/directory
      privateKeySecretRef:
        name: letsencrypt-prod-key
      solvers:
        - dns01:
            cloudflare:
              apiTokenSecretRef:
                name: cloudflare-api-token
                key: api-token
          selector:
            dnsZones:
              - "drunk.dev"
```

#### Installing cert-manager

If you haven't installed cert-manager yet, use Helm:

```bash
# Install cert-manager with CRDs
helm install cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --version v1.19.1 \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true

# Verify the installation
kubectl get pods -n cert-manager
kubectl get crd | grep cert-manager
```

For more information and configuration options:

- [cert-manager Helm Installation](https://cert-manager.io/docs/installation/helm/)
- [cert-manager Gateway API Support](https://cert-manager.io/docs/usage/gateway/)

## Usage Examples

### Example 1: Simple HTTP Gateway

```yaml
gateway:
  enabled: true
  name: http-gateway
  gatewayClassName: nginx
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      hostname: "*"
      allowedRoutes:
        namespaces:
          from: All
```

### Example 2: Multi-Domain Production Gateway

```yaml
domains:
  - name: production
    enabled: true
    gatewayClassName: nginx
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
    listeners:
      - name: https-prod
        protocol: HTTPS
        port: 443
        hostname: "*.prod.example.com"
        tls:
          mode: Terminate
          certificateRefs:
            - name: prod-tls

  - name: staging
    enabled: true
    gatewayClassName: nginx
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-staging
    listeners:
      - name: https-staging
        protocol: HTTPS
        port: 8443
        hostname: "*.staging.example.com"
        tls:
          mode: Terminate
          certificateRefs:
            - name: staging-tls
```

### Example 3: Using the Gateway with Applications

Once your Gateway is deployed, use it with drunk-app:

```yaml
# Application values
httpRoute:
  enabled: true
  parentRefs:
    - name: shared-gateway
      namespace: default
  hostnames:
    - myapp.drunk.dev
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: myapp-service
          port: 80
```

Deploy:

```bash
helm install myapp drunk-charts/drunk-app \
  --set httpRoute.enabled=true \
  --set httpRoute.parentRefs[0].name=shared-gateway
```

## Verification

### Check GatewayClass

```bash
kubectl get gatewayclass
kubectl describe gatewayclass nginx
```

### Check Gateway Status

```bash
kubectl get gateway -A
kubectl describe gateway shared-gateway
```

Expected status:

```yaml
status:
  conditions:
    - type: Programmed
      status: "True"
  addresses:
    - type: IPAddress
      value: "10.96.100.100"
```

### Get Gateway Address

```bash
kubectl get gateway shared-gateway -o jsonpath='{.status.addresses[0].value}'
```

### Test Gateway

```bash
GATEWAY_IP=$(kubectl get gateway shared-gateway -o jsonpath='{.status.addresses[0].value}')
curl -H "Host: myapp.drunk.dev" http://$GATEWAY_IP/
```

## Upgrading

### Upgrade Gateway API CRDs

```bash
# Check current version
kubectl get crd gateways.gateway.networking.k8s.io -o jsonpath='{.metadata.labels.gateway\.networking\.k8s\.io/bundle-version}'

# Upgrade to new version
./scripts/install-crds.sh --version v1.2.0
```

### Upgrade Chart

```bash
helm upgrade gateway drunk-charts/drunk-k8s-gateway \
  -f values-production.yaml \
  --reuse-values
```

## Uninstallation

### Uninstall Chart

```bash
helm uninstall gateway -n gateway-system
```

### Remove CRDs

**Warning:** This will delete ALL Gateway API resources (Gateways, HTTPRoutes, etc.)

```bash
./scripts/uninstall-crds.sh
```

## Troubleshooting

### Gateway Not Ready

**Symptom:** Gateway shows `Programmed: False`

**Solutions:**

```bash
# Check Gateway events
kubectl describe gateway <gateway-name>

# Check controller logs
kubectl logs -n gateway-system -l app=gateway-controller

# Verify GatewayClass exists
kubectl get gatewayclass
```

### TLS Certificate Issues

**Symptom:** HTTPS not working or certificate errors

**Solutions:**

```bash
# Check if secret exists
kubectl get secret <tls-secret-name>

# If using cert-manager, check Certificate
kubectl get certificate
kubectl describe certificate <cert-name>

# Check ClusterIssuer
kubectl get clusterissuer
kubectl describe clusterissuer <issuer-name>
```

### HTTPRoute Not Attaching

**Symptom:** HTTPRoute shows no parent

**Solutions:**

```bash
# Verify Gateway name and namespace
kubectl get gateway -A

# Check allowed routes in Gateway
kubectl get gateway <gateway-name> -o yaml | grep -A 10 allowedRoutes

# Verify HTTPRoute parent references
kubectl describe httproute <route-name>
```

## Advanced Configuration

### Custom GatewayClass Parameters

```yaml
gatewayClass:
  enabled: true
  name: nginx-custom
  controllerName: gateway.nginx.org/nginx-gateway-controller
  parametersRef:
    group: gateway.nginx.org
    kind: NginxProxy
    name: nginx-proxy-config
```

### Multiple GatewayClasses

Deploy separate charts for different controllers:

```bash
# NGINX Gateway
helm install nginx-gateway drunk-charts/drunk-k8s-gateway \
  --set gatewayClass.name=nginx \
  --set gatewayClass.controllerName=gateway.nginx.org/nginx-gateway-controller

# Istio Gateway
helm install istio-gateway drunk-charts/drunk-k8s-gateway \
  --set gatewayClass.name=istio \
  --set gatewayClass.controllerName=istio.io/gateway-controller
```

## Integration with drunk-app

This chart is designed to work seamlessly with [drunk-app](../drunk-app):

1. Deploy shared Gateway with drunk-k8s-gateway
2. Deploy applications with drunk-app using HTTPRoute
3. Applications reference the shared Gateway via `parentRefs`

Example workflow:

```bash
# 1. Deploy Gateway infrastructure
helm install gateway drunk-charts/drunk-k8s-gateway -f gateway-values.yaml

# 2. Deploy application with HTTPRoute
helm install myapp drunk-charts/drunk-app \
  --set httpRoute.enabled=true \
  --set httpRoute.parentRefs[0].name=shared-gateway \
  --set httpRoute.hostnames[0]=myapp.drunk.dev
```

## Resources

- [Gateway API Documentation](https://gateway-api.sigs.k8s.io/)
- [NGINX Gateway Fabric](https://docs.nginx.com/nginx-gateway-fabric/)
- [cert-manager Gateway API Support](https://cert-manager.io/docs/usage/gateway/)
- [drunk-lib Documentation](../drunk-lib.md)
- [Migration from Ingress Guide](../docs/nginx-to-gateway-migration.md)

## Contributing

Contributions are welcome! Please see the main [drunk.charts repository](https://github.com/baoduy/drunk.charts) for contribution guidelines.

## License

This chart is part of the drunk.charts project and follows the same license.

## Author

- **Duy Bao (baoduy)**
- Email: baoduy2412@gmail.com
- Repository: https://github.com/baoduy/drunk.charts
