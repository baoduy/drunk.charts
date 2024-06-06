# Drunk Proxy Helm Chart

This Helm chart deploys the Drunk Proxy, an NGINX-based proxy, on a Kubernetes cluster using the Helm package manager.

## Prerequisites

- Kubernetes 1.20+
- Helm 3.0+

## Installing the Chart

To install the chart with the release name `drunk-nginx-proxy`:

```bash
$ helm install drunk-nginx-proxy https://baoduy.github.io/drunk.charts/drunk-nginx-proxy/
```

This command deploys Drunk Proxy on the Kubernetes cluster in the default configuration. The parameters that can be configured during installation are listed in the configuration section.

## Uninstalling the Chart

To uninstall/delete the `drunk-nginx-proxy` deployment:

```bash
$ helm delete drunk-nginx-proxy
```

This command removes all the Kubernetes components associated with the chart and deletes the release.

## Configuration

The following table lists the configurable parameters of the Drunk Proxy chart and their default values.

# Configuration Parameters for Drunk Proxy Helm Chart

| Parameter                                         | Description                                           | Default Value                                         |
|---------------------------------------------------|-------------------------------------------------------|-------------------------------------------------------|
| `nginx.enabled`                                   | Enable NGINX as the proxy                             | `true`                                                |
| `toolbox.enabled`                                 | Enable toolbox utilities                              | `true`                                                |
| `tlsSecrets.[name].enabled`                   | Enable TLS secrets for [name]                     | `true`                                                |
| `tlsSecrets.[name].crt`                       | TLS certificate for [name]                        | *certificate content*                                 |
| `tlsSecrets.[name].key`                       | TLS key for [name]                                | *key content*                                         |
| `tlsSecrets.dev-local.crt`                        | Development local TLS certificate                     | *certificate content*                                 |
| `tlsSecrets.dev-local.key`                        | Development local TLS key                             | *key content*                                         |
| `proxies.[name].ingressHost`                      | Ingress host for [name]                               |                                           |
| `proxies.[name].ingressPath`                      | Ingress path for [name]                               |                                       |
| `proxies.[name].target`                           | Target IP for [name]                                  |                                       |
| `proxies.[name].targetPort`                       | Target port for [name]                                |  443                                          |
| `proxies.[name].annotations` | Backend protocol for NGINX ingress | [HTTPS]                                    |

Note: Refer `values.test.yaml` for details

## Dependencies

Drunk Proxy depends on the `ingress-nginx` chart for setting up NGINX as a reverse proxy and load balancer. Ensure that this dependency is correctly configured in your Helm repository.

```yaml
dependencies:
  - name: ingress-nginx
    version: "4.x.x"
    repository: "https://kubernetes.github.io/ingress-nginx"
    condition: nginx.enabled
```

## Values File

You can specify a custom values file to override the default settings during the Helm install command:

```bash
$ helm install drunk-nginx-proxy -f custom-values.yaml https://baoduy.github.io/drunk.charts/drunk-nginx-proxy/
```

## Testing the Chart

To verify that the chart is configured correctly:

```shell
$ helm lint ./drunk-nginx-proxy
$ helm template test ./drunk-nginx-proxy --debug
```

This will check for syntax errors and render the templates with the provided values without actually deploying them.

For more detailed information on configuring and using this chart, refer to the official Helm documentation.