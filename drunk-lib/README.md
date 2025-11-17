# Drunk-lib Helm Chart Library

Welcome to the **Drunk-lib** Helm chart library. This project serves as a collection of reusable Helm chart templates to streamline the development and deployment of Kubernetes applications.

## Table of Contents

- [Drunk-lib Helm Chart Library](#drunk-lib-helm-chart-library)
  - [Table of Contents](#table-of-contents)
  - [Introduction](#introduction)
    - [SecretProvider (Azure Key Vault)](#secretprovider-azure-key-vault)
  - [Reference](#reference)
  - [Contributing](#contributing)
  - [License](#license)

## Introduction

The **Drunk-lib** Helm chart library is designed to provide a set of standardized, optimized, and reusable templates that can be utilized across multiple projects and environments. Whether you're deploying a microservice or a complex application stack, Drunk-lib offers flexibility and efficiency.

### Gateway API Support

Drunk-lib provides modern Kubernetes Gateway API templates as an alternative to traditional Ingress resources. The Gateway API offers more advanced traffic management capabilities and better role separation between platform and application teams.

#### Gateway Resource

Creates a Gateway resource that defines network entry points for your cluster.

- Template: `templates/_gateway.tpl` (named template `drunk-lib.gateway`)
- Values key: `gateway`

Minimal values example (disabled by default):

```yaml
gateway:
  enabled: true
  gatewayClassName: nginx
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      hostname: "*.example.com"
    - name: https
      protocol: HTTPS
      port: 443
      hostname: "*.example.com"
      tls:
        mode: Terminate
        certificateRefs:
          - name: example-tls
```

#### HTTPRoute Resource

Creates an HTTPRoute resource that defines how HTTP/HTTPS traffic is routed to services.

- Template: `templates/_httproute.tpl` (named template `drunk-lib.httpRoute`)
- Values key: `httpRoute`

Minimal values example (disabled by default):

```yaml
httpRoute:
  enabled: true
  hostnames:
    - "myapp.example.com"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: myapp-service
          port: 80
```

Advanced example with filters:

```yaml
httpRoute:
  enabled: true
  hostnames:
    - "myapp.example.com"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /api
      filters:
        - type: RequestHeaderModifier
          requestHeaderModifier:
            add:
              - name: X-Custom-Header
                value: custom-value
      backendRefs:
        - name: api-service
          port: 8080
          weight: 80
        - name: api-service-canary
          port: 8080
          weight: 20
```

Include in a consuming chart template with:

```
{{ include "drunk-lib.gateway" . }}
{{ include "drunk-lib.httpRoute" . }}
```

### SecretProvider (Azure Key Vault)

Drunk-lib provides a reusable template to render a `secretProviderClass` for the Secrets Store CSI Driver with Azure Key Vault provider.

- Template: `templates/_secretprovider.tpl` (named template `drunk-lib.secretProvider`)
- Values key: `secretProvider`

Minimal values example (disabled by default):

```
secretProvider:
  enabled: true
  name: my-spc
  tenantId: "<tenant-guid>"
  vaultName: "my-keyvault"
  usePodIdentity: false
  useWorkloadIdentity: true
  objects:
    - objectName: my-secret
      objectType: secret
  secretObjects:
    - secretName: my-k8s-secret
      type: Opaque
      data:
        - key: MY_ENV
          objectName: my-secret
```

Include in a consuming chart template with:

```
{{ include "drunk-lib.secretProvider" . }}
```

## Reference

- Gateway API: https://gateway-api.sigs.k8s.io/
- Azure Key Vault Secrets Store CSI Driver: https://azure.github.io/secrets-store-csi-driver-provider-azure/docs/getting-started/usage/

## Contributing

We welcome contributions to the **Drunk-lib** Helm chart library. If you'd like to contribute, please fork the repository and submit a pull request. Ensure your code adheres to the style and conventions used throughout the project.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
