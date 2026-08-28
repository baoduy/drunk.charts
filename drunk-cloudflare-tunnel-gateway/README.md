# drunk-cloudflare-tunnel-gateway

A Helm chart that wraps the [cloudflare-tunnel-gateway-controller](https://github.com/lexfrei/cloudflare-tunnel-gateway-controller)
subchart and renders per-domain Gateway API `Gateway` resources, so services
behind a Cloudflare Tunnel can be exposed via standard `HTTPRoute` objects.

## Overview

This chart's Gateways are backed by a Cloudflare Tunnel, not a cloud
LoadBalancer. The `cloudflare-tunnel-gateway-controller` runs an in-process
`cloudflared` data plane that dials **out** from the cluster to Cloudflare's
edge and registers the routes described by your Gateway API resources.
Because Cloudflare terminates TLS at its edge, there is:

- **No LoadBalancer Service** and no public IP to allocate — the tunnel
  dials outbound, so nothing needs to be reachable from the internet.
- **No cert-manager / in-cluster TLS** — listeners in this chart are plain
  `HTTP`, and Cloudflare handles certificates for you at the edge.

The controller watches `GatewayClass`/`Gateway`/`HTTPRoute` objects with its
own `GatewayClassName` (`cloudflare-tunnel` by default) and reconciles them
into the Cloudflare Tunnel's ingress configuration.

## Prerequisites

- A Cloudflare account with Zero Trust enabled.
- A Cloudflare Tunnel already created (Zero Trust → Networks → Tunnels),
  and its **Tunnel ID**.
- A Cloudflare API token with permission to manage the tunnel's
  configuration.
- `helm`, `kubectl`, and `curl` available locally.
- Gateway API CRDs installed in the cluster — this chart targets
  **v1.6.1**. They are installed via `kubectl` (see `install.sh`) rather
  than as Helm chart CRDs, to avoid Helm's 3MB CRD annotation limit.

## Secrets

This chart **references** two Kubernetes Secrets by name — it does not
create them. Create both in the target namespace before (or immediately
after) installing, or the controller will not become healthy:

```bash
kubectl create secret generic cloudflare-credentials \
  -n cloudflare-tunnel-system --from-literal=api-token=YOUR_API_TOKEN

kubectl create secret generic cloudflare-tunnel-token \
  -n cloudflare-tunnel-system --from-literal=tunnel-token=YOUR_TUNNEL_TOKEN
```

- `cloudflare-credentials` (key `api-token`) — used by the controller to
  manage the tunnel's configuration via the Cloudflare API.
- `cloudflare-tunnel-token` (key `tunnel-token`) — the tunnel's connector
  token, used by the in-process `cloudflared` data plane to establish the
  tunnel connection.

Both Secret names are configurable via
`cloudflareTunnel.gatewayClassConfig.cloudflareCredentialsSecretRef.name`
and `cloudflareTunnel.proxy.tunnelTokenSecretRef.name` if you need to point
at existing Secrets with different names.

## Install

Using the install script (recommended — it also installs the Gateway API
CRDs and warns if the two Secrets above are missing):

```bash
cd drunk-cloudflare-tunnel-gateway
./install.sh
```

Environment variables override the script's defaults:

| Variable | Default | Purpose |
|---|---|---|
| `RELEASE_NAME` | `cf-tunnel` | Helm release name |
| `NAMESPACE` | `cloudflare-tunnel-system` | Target namespace |
| `VALUES_FILE` | `values.example.yaml` | Values file to install with |
| `GATEWAY_API_VERSION` | `v1.6.1` | Gateway API CRD version |
| `SKIP_CRDS` | `false` | Skip Gateway API CRD installation |
| `FORCE_REINSTALL_CRDS` | `false` | Delete and reinstall Gateway API CRDs |

Or install directly with `helm`:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/standard-install.yaml
helm dependency build drunk-cloudflare-tunnel-gateway
helm upgrade --install cf-tunnel drunk-cloudflare-tunnel-gateway \
  --namespace cloudflare-tunnel-system --create-namespace \
  -f drunk-cloudflare-tunnel-gateway/values.example.yaml
```

Copy `values.example.yaml` and set `cloudflareTunnel.gatewayClassConfig.tunnelID`
to your real Cloudflare Tunnel ID before installing for anything beyond a
smoke test.

## Configuration

| Key | Description |
|---|---|
| `domains[]` | List of domain Gateways to render. Each entry needs `name`, `enabled`, `gatewayClassName`, and `listeners[]` (Gateway API listener objects: `name`, `protocol`, `port`, `hostname`, optional `allowedRoutes`). One `Gateway` named `<name>-gateway` is rendered per enabled entry. |
| `routeAccess` | Default `allowedRoutes.namespaces` applied to any listener that omits its own. `mode: Same` restricts routes to the Gateway's namespace, `mode: All` allows routes from any namespace, `mode: List` selects namespaces labeled `routeAccess.labelKey: routeAccess.labelValue`. |
| `cloudflareTunnel.*` | Passthrough values to the vendored `cloudflare-tunnel-gateway-controller` subchart (aliased `cloudflareTunnel`). Key fields: `gatewayClassConfig.tunnelID` (required — your Cloudflare Tunnel ID), `gatewayClassConfig.cloudflareCredentialsSecretRef.name`, `proxy.tunnelTokenSecretRef.name`, `controller.gatewayClassName` / `controller.controllerName`. See the subchart's own values for the full set of passthrough options. |
| `namespace` | Namespace the `Gateway` resources are rendered into. Empty (default) uses the release namespace. |
| `gatewayAPI.version` / `gatewayAPI.channel` | Informational — which Gateway API CRD release `install.sh` / the README instructions target. |

## Authoring HTTPRoutes

Point each `HTTPRoute`'s `parentRefs` at the domain Gateway
(`<domain-name>-gateway`) rendered by this chart:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-app
  namespace: my-app-ns
spec:
  parentRefs:
    - name: drunk-dev-gateway
      namespace: cloudflare-tunnel-system
  hostnames:
    - "myapp.drunk.dev"
  rules:
    - backendRefs:
        - name: my-app-service
          port: 80
```

The route's namespace must be allowed by the Gateway's listener
(`allowedRoutes`, driven by `routeAccess` unless the listener sets its own).

## ⚠️ Exclusive tunnel ownership

The `cloudflare-tunnel-gateway-controller` takes **exclusive ownership** of
the Cloudflare Tunnel's ingress configuration: it reconciles the tunnel to
match exactly what your Gateway API resources describe, and removes any
ingress rules it did not create. Do not point `cloudflareTunnel.gatewayClassConfig.tunnelID`
at a tunnel that is also managed by `cloudflared` config files, the
Cloudflare dashboard, or another controller — those rules will be deleted.

## Uninstall

```bash
./uninstall.sh
```

By default (`RELEASE_NAME=cf-tunnel`, `NAMESPACE=cloudflare-tunnel-system`)
this removes only the Helm release. Gateway API CRDs are **not** deleted
unless you opt in with `DELETE_CRDS=true`, in which case the script prompts
for confirmation unless you also pass `FORCE=true`:

```bash
DELETE_CRDS=true ./uninstall.sh
```

⚠️ Gateway API CRDs are shared cluster-wide infrastructure — other Gateway
API implementations or gateways in the cluster may depend on them. Only set
`DELETE_CRDS=true` if you are sure no other Gateway/HTTPRoute resources in
the cluster still need them.

The namespace is deleted by default (`DELETE_NAMESPACE=true`) once its
resources are removed; set `DELETE_NAMESPACE=false` to keep it. The two
referenced Secrets (`cloudflare-credentials`, `cloudflare-tunnel-token`)
were never created by this chart and are left in place; delete them
manually with `kubectl delete secret` if desired.
