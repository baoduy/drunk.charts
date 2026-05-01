# Drunk App Helm Chart

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/drunk-app)](https://artifacthub.io/packages/search?repo=drunk-app)

The **drunk-app** Helm chart is a production-ready framework for deploying applications on Kubernetes. Built as a thin wrapper over [`drunk-lib`](../drunk-lib), it handles Deployments, StatefulSets, CronJobs, Jobs, Ingress, Gateway API, TLS, Secrets, Volumes, and HPA from a single `values.yaml`.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+

## Installation

```bash
helm repo add drunk-charts https://baoduy.github.io/drunk.charts/drunk-app
helm repo update
helm install my-app drunk-charts/drunk-app -f my-values.yaml
```

## Minimal Configuration

```yaml
global:
  image: "myregistry/myapp"
  tag: "v1.0.0"

deployment:
  ports:
    http: 8080
  liveness: "/healthz"

volumes:
  tmp:
    mountPath: "/tmp"
    emptyDir: true
```

## Key Features

- **Deployment & StatefulSet** — choose the right workload type
- **CronJobs & Jobs** — scheduled and one-time batch tasks
- **Environment & Config** — env vars, ConfigMaps, external ConfigMap references
- **Secrets** — inline secrets, external references, CSI Secrets Store (Azure/AWS/GCP)
- **TLS** — inline base64, file-based, or CA-only certificate modes
- **Ingress & Gateway API** — classic Ingress or HTTPRoute with parentRef
- **HPA** — CPU and memory-based autoscaling
- **Network Policies** — multiple named policies with fine-grained ingress/egress rules
- **Storage** — PVC map and emptyDir volumes
- **Security** — non-root, read-only root filesystem, capability drops by default

## Built on drunk-lib

Every template in [`templates/`](templates/) is a one-line include of a `drunk-lib.<name>` named template. All rendering logic lives in `drunk-lib`.

```bash
# Refresh drunk-lib after a version bump
helm dependency update ./drunk-app
```

## Gateway API (Gateway + HTTPRoute)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `gateway.enabled` | Render the `Gateway` resource | `false` |
| `gateway.gatewayClassName` | GatewayClass to bind to | — |
| `gateway.listeners[]` | Listener specifications | `[]` |
| `httpRoute.enabled` | Render the `HTTPRoute` resource | `false` |
| `httpRoute.parentRefs[]` | Gateways to attach to | `[]` |
| `httpRoute.hostnames[]` | Hostname matches | `[]` |

## Full Documentation

See **[docs/drunk-app.md](../docs/drunk-app.md)** for the complete configuration reference — all parameters, types, defaults, and usage examples.

## Claude Code Plugin

Install the AI assistant for drunk-app to get help configuring `values.yaml`:

```bash
plugin marketplace add baoduy/drunk.charts
plugin install drunk-app
```

Then use `/drunk-app` in any Claude Code session.

## Contributing

Contributions welcome. Open a [GitHub issue](https://github.com/baoduy/drunk.charts/issues) for questions or bugs.

## License

MIT — [Steven Hoang](https://drunkcoding.net)
