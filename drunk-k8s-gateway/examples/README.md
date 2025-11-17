# Example Values Files

This directory contains example values files for different deployment scenarios.

## Files

- `minimal.yaml` - Minimal configuration with just GatewayClass
- `basic-gateway.yaml` - Basic Gateway with HTTP and HTTPS listeners
- `drunk-dev-domain.yaml` - Domain-specific Gateway for drunk.dev
- `with-certmanager.yaml` - Configuration with cert-manager integration
- `multi-domain.yaml` - Multiple domain-specific Gateways
- `production.yaml` - Production-ready configuration

## Usage

```bash
# Install with example values
helm install gateway drunk-charts/drunk-k8s-gateway -f examples/<file>.yaml

# Or from local directory
helm install gateway . -f examples/<file>.yaml -n gateway-system --create-namespace
```

## Customization

Copy any example file and modify it for your needs:

```bash
cp examples/basic-gateway.yaml my-values.yaml
# Edit my-values.yaml
helm install gateway drunk-charts/drunk-k8s-gateway -f my-values.yaml
```
