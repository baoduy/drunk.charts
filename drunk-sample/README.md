# drunk-sample

Sample application for testing the drunk-k8s-gateway chart.

This deploys a Microsoft .NET sample application using the drunk-app chart with Gateway API HTTPRoute configuration.

## Prerequisites

- Kubernetes cluster (minikube, kind, k3d, or any cluster)
- Gateway API CRDs installed
- drunk-k8s-gateway deployed with drunk-dev-gateway
- drunk-app chart available in parent directory

## Quick Start

```bash
# 1. Deploy the sample application
cd drunk-sample
./deploy.sh

# 2. Add hostname to /etc/hosts
echo "127.0.0.1 dotnet-sample.dev.local" | sudo tee -a /etc/hosts

# 3. Test the application
# Option A: Using minikube tunnel (in separate terminal)
minikube tunnel
curl http://dotnet-sample.dev.local

# Option B: Using port-forward
kubectl port-forward -n drunk-gateway svc/drunk-dev-gateway-http 8080:80
curl http://dotnet-sample.dev.local:8080
```

## Configuration

The sample app is configured in `values.yaml`:

- **Image**: `mcr.microsoft.com/dotnet/samples:aspnetapp`
- **Service**: ClusterIP on port 8080
- **HTTPRoute**: Routes `dotnet-sample.dev.local` to the Gateway
- **Namespace**: `drunk-dev-apps`

## Verify Deployment

```bash
# Check pods
kubectl get pods -n drunk-dev-apps

# Check service
kubectl get svc -n drunk-dev-apps

# Check HTTPRoute
kubectl get httproute -n drunk-dev-apps
kubectl describe httproute dotnet-sample -n drunk-dev-apps

# View logs
kubectl logs -n drunk-dev-apps -l app=dotnet-sample --tail=50 -f
```

## Cleanup

```bash
./uninstall.sh

# Optionally delete the namespace
kubectl delete namespace drunk-dev-apps
```

## Customization

Edit `values.yaml` to customize:

- Application name and namespace
- Docker image and tag
- Resource limits
- Hostname routing
- Gateway reference
