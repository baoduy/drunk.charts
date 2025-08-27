# Drunk-lib Helm Chart Library

Welcome to the **Drunk-lib** Helm chart library. This project serves as a collection of reusable Helm chart templates to streamline the development and deployment of Kubernetes applications.

## Table of Contents

- [Drunk-lib Helm Chart Library](#drunk-lib-helm-chart-library)
  - [Table of Contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Contributing](#contributing)
  - [License](#license)

## Introduction

The **Drunk-lib** Helm chart library is designed to provide a set of standardized, optimized, and reusable templates that can be utilized across multiple projects and environments. Whether you're deploying a microservice or a complex application stack, Drunk-lib offers flexibility and efficiency.

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

## Contributing

We welcome contributions to the **Drunk-lib** Helm chart library. If you'd like to contribute, please fork the repository and submit a pull request. Ensure your code adheres to the style and conventions used throughout the project.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
