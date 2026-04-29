# Testing cert-manager with drunk-k8s-gateway

This guide shows how to test HTTPS/TLS with self-signed certificates using cert-manager in your K3s cluster.

## Prerequisites

- K3s cluster running in VM
- kubectl configured to access the cluster
- drunk-k8s-gateway chart deployed with `values.local.yaml`
- Host file DNS configured for `*.dev.local` pointing to your VM IP

## What's Been Configured

### 1. Self-Signed ClusterIssuer

The chart will create a `selfsigned-issuer` ClusterIssuer:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
```

### 2. Certificate Resource

A Certificate will be automatically created for the HTTPS listener:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: drunk-dev-tls
  namespace: default
spec:
  secretName: drunk-dev-tls
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
  dnsNames:
    - "*.dev.local"
```

### 3. Gateway HTTPS Listener

The Gateway includes an HTTPS listener using the certificate:

```yaml
listeners:
  - name: https
    hostname: "*.dev.local"
    port: 443
    protocol: HTTPS
    tls:
      mode: Terminate
      certificateRefs:
        - kind: Secret
          name: drunk-dev-tls
```

## Deployment Steps

1. **Deploy/Upgrade the chart:**

   ```bash
   cd /Users/steven/_CODE/GIT/drunk.charts/drunk-k8s-gateway
   helm upgrade --install drunk-k8s-gateway . -f values.local.yaml
   ```

2. **Verify ClusterIssuer is ready:**

   ```bash
   kubectl get clusterissuer selfsigned-issuer
   kubectl describe clusterissuer selfsigned-issuer
   ```

   Expected output shows `Ready=True`

3. **Check Certificate status:**

   ```bash
   kubectl get certificate drunk-dev-tls
   kubectl describe certificate drunk-dev-tls
   ```

   Wait for status `Ready=True`. cert-manager will automatically create the TLS secret.

4. **Verify the TLS secret was created:**

   ```bash
   kubectl get secret drunk-dev-tls
   kubectl describe secret drunk-dev-tls
   ```

   Should show `type: kubernetes.io/tls` with `tls.crt` and `tls.key` data fields.

5. **Check Gateway status:**

   ```bash
   kubectl get gateway drunk-dev-gateway
   kubectl describe gateway drunk-dev-gateway
   ```

   The HTTPS listener should show `Programmed=True` and `ResolvedRefs=True`.

## Testing HTTPS

### 1. Deploy a sample application

Use the drunk-sample or any HTTPRoute-compatible app:

```bash
cd /Users/steven/_CODE/GIT/drunk.charts/drunk-sample
helm upgrade --install drunk-sample ../drunk-app -f values.yaml
```

Make sure your app's HTTPRoute specifies:

```yaml
spec:
  parentRefs:
    - name: drunk-dev-gateway
      namespace: default
  hostnames:
    - "sample.dev.local"
```

### 2. Test with curl

```bash
# Test HTTPS (will show self-signed cert warning)
curl -k https://sample.dev.local

# View certificate details
curl -vk https://sample.dev.local 2>&1 | grep -A 10 "Server certificate"
```

The `-k` flag bypasses certificate verification (needed for self-signed certs).

### 3. Test with browser

1. Add to your `/etc/hosts`:

   ```
   <VM_IP>  sample.dev.local
   ```

2. Navigate to `https://sample.dev.local`

3. You'll see a security warning about the self-signed certificate:

   - **Chrome/Edge**: "Your connection is not private" → Click "Advanced" → "Proceed to sample.dev.local"
   - **Firefox**: "Warning: Potential Security Risk" → Click "Advanced" → "Accept the Risk and Continue"
   - **Safari**: "This Connection Is Not Private" → Click "Show Details" → "visit this website"

4. Once accepted, you'll see the app over HTTPS

## Troubleshooting

### Certificate not created

```bash
# Check cert-manager logs
kubectl logs -n cert-manager deploy/cert-manager -f

# Check Certificate events
kubectl describe certificate drunk-dev-tls
```

### Gateway listener not ready

```bash
# Check Gateway events
kubectl describe gateway drunk-dev-gateway

# Check if secret exists and is referenced correctly
kubectl get secret drunk-dev-tls -o yaml
```

### HTTPS returns 404

- Verify HTTPRoute is created: `kubectl get httproute`
- Check HTTPRoute parentRefs match gateway name
- Verify hostname matches pattern: `*.dev.local`

## Production Use

For production, replace the self-signed issuer with Let's Encrypt ACME:

```yaml
certManager:
  clusterIssuersEnabled: true
  clusterIssuers:
    - name: "letsencrypt-prod"
      spec:
        acme:
          server: https://acme-v02.api.letsencrypt.org/directory
          email: your-email@example.com
          privateKeySecretRef:
            name: letsencrypt-prod
          solvers:
            - http01:
                gatewayHTTPRoute:
                  parentRefs:
                    - name: drunk-dev-gateway
                      namespace: default
```

Then update the Gateway annotation:

```yaml
annotations:
  cert-manager.io/cluster-issuer: letsencrypt-prod
```
