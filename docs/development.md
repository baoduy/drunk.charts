# Development Guide

This guide provides everything you need to know to contribute to and extend the Drunk Charts project. Whether you're fixing bugs, adding features, or creating new charts, this guide will help you get started.

## Table of Contents

- [Getting Started](#getting-started)
- [Development Environment](#development-environment)  
- [Project Structure](#project-structure)
- [Development Workflow](#development-workflow)
- [Testing](#testing)
- [Contributing Guidelines](#contributing-guidelines)
- [Release Process](#release-process)
- [Best Practices](#best-practices)

## Getting Started

### Prerequisites

- **Git**: Version control
- **Helm**: 3.0+ for chart development and testing
- **Kubernetes**: Local cluster (minikube, kind, Docker Desktop) for testing
- **Docker**: For building and testing container images
- **Text Editor**: VS Code with Helm/YAML extensions recommended

### Clone the Repository

```bash
git clone https://github.com/baoduy/drunk.charts.git
cd drunk.charts
```

### Repository Structure

```
drunk.charts/
├── README.md                    # Main project documentation
├── docs/                        # Comprehensive documentation
│   ├── README.md               # Documentation index
│   ├── quick-start.md          # Quick start guide
│   ├── drunk-app.md            # drunk-app chart documentation
│   ├── drunk-lib.md            # drunk-lib library documentation
│   ├── architecture.md         # Architecture overview
│   ├── development.md          # This file
│   └── examples/               # Configuration examples
├── drunk-app/                   # Application chart
│   ├── Chart.yaml              # Chart metadata
│   ├── values.yaml             # Default values
│   ├── templates/              # Chart templates
│   ├── tests/                  # Chart tests
│   └── README.md               # Chart-specific docs
├── drunk-lib/                   # Library chart  
│   ├── Chart.yaml              # Chart metadata (type: library)
│   ├── values.yaml             # Default template values
│   └── templates/              # Reusable template library
└── .github/                     # GitHub workflows and templates
    └── workflows/              # CI/CD automation
```

## Development Environment

### Local Setup

1. **Install Dependencies**
   ```bash
   # Install Helm
   curl https://get.helm.sh/helm-v3.12.0-linux-amd64.tar.gz | tar xz
   sudo mv linux-amd64/helm /usr/local/bin/

   # Install helm-unittest plugin for testing
   helm plugin install https://github.com/helm-unittest/helm-unittest
   
   # Install Kubernetes cluster (choose one)
   # Docker Desktop, minikube, or kind
   ```

2. **Verify Setup**
   ```bash
   helm version
   kubectl cluster-info
   helm unittest --help
   ```

### IDE Configuration

#### VS Code Extensions

```json
{
  "recommendations": [
    "ms-kubernetes-tools.vscode-kubernetes-tools",
    "redhat.vscode-yaml",
    "tim-koike.helm-intellisense"
  ]
}
```

#### VS Code Settings

```json
{
  "yaml.schemas": {
    "https://json.schemastore.org/chart.json": "Chart.yaml",
    "https://json.schemastore.org/helmfile.json": "helmfile.yaml"
  },
  "files.associations": {
    "*.tpl": "yaml"
  }
}
```

## Project Structure

### Chart Organization

#### drunk-lib (Library Chart)

```
drunk-lib/
├── Chart.yaml                 # type: library, version, dependencies
├── values.yaml               # Default configuration for templates
└── templates/
    ├── _helpers.tpl          # Common helper functions
    ├── _deployment.tpl       # Deployment template
    ├── _service.tpl          # Service template
    ├── _configmap.tpl        # ConfigMap template
    ├── _secrets.tpl          # Secret template
    ├── _ingress.tpl          # Ingress template
    ├── _volumes.tpl          # PVC template
    ├── _cronjob.tpl          # CronJob template
    ├── _job.tpl              # Job template
    ├── _hpa.tpl              # HPA template
    ├── _serviceaccount.tpl   # ServiceAccount template
    ├── _secretprovider.tpl   # SecretProviderClass template
    └── _tls-secrets.tpl      # TLS Secret template
```

#### drunk-app (Application Chart)

```
drunk-app/
├── Chart.yaml                # Depends on drunk-lib
├── values.yaml              # User-facing configuration
├── templates/               # Thin wrappers around drunk-lib
│   ├── deployment.yaml      # {{ include "drunk-lib.deployment" . }}
│   ├── service.yaml         # {{ include "drunk-lib.service" . }}
│   └── ...                  # One file per resource type
├── tests/                   # Unit tests
│   └── deployment_test.yaml
└── values.example.yaml         # Test configuration
```

### Template Naming Conventions

- **Library templates**: `_templatename.tpl` (underscore prefix)
- **Named templates**: `drunk-lib.resourceType` (e.g., `drunk-lib.deployment`)
- **Application templates**: `resourcetype.yaml` (e.g., `deployment.yaml`)

## Development Workflow

### 1. Setting Up a Feature Branch

```bash
# Create feature branch
git checkout -b feature/my-new-feature

# Or for bug fixes
git checkout -b fix/issue-description
```

### 2. Making Changes

#### Adding New Template to drunk-lib

1. Create template file:
   ```bash
   touch drunk-lib/templates/_newresource.tpl
   ```

2. Implement template:
   ```yaml
   {{- define "drunk-lib.newResource" -}}
   {{- if .Values.newResource.enabled }}
   ---
   apiVersion: v1
   kind: NewResource
   metadata:
     name: {{ include "app.fullname" . }}
     labels: {{ include "app.labels" . | nindent 4 }}
   spec:
     # Resource specification
   {{- end }}
   {{- end }}
   ```

3. Add to drunk-app:
   ```yaml
   # drunk-app/templates/newresource.yaml
   {{ include "drunk-lib.newResource" . }}
   ```

4. Update default values:
   ```yaml
   # drunk-lib/values.yaml
   newResource:
     enabled: false
     # ... configuration options
   ```

#### Modifying Existing Templates

1. Identify the template in drunk-lib
2. Make changes while maintaining backward compatibility
3. Update tests
4. Update documentation

### 3. Testing Changes

```bash
# Test template rendering
helm template test-release drunk-app/ --debug

# Test with custom values
helm template test-release drunk-app/ -f test-values.yaml

# Run unit tests
helm unittest drunk-app/

# Test specific templates
helm template test-release drunk-app/ --show-only templates/deployment.yaml
```

### 4. Updating Documentation

- Update relevant `.md` files in `docs/`
- Update chart README files if needed
- Add examples for new features
- Update configuration reference tables

## Testing

### Unit Testing with helm-unittest

Tests are located in `tests/` directories and use the helm-unittest plugin.

#### Example Test Structure

```yaml
# drunk-app/tests/deployment_test.yaml
suite: test deployment
templates:
  - deployment.yaml
tests:
  - it: should create deployment with default values
    asserts:
      - isKind:
          of: Deployment
      - equal:
          path: metadata.name
          value: RELEASE-NAME-drunk-app
      - equal:
          path: spec.replicas
          value: 1

  - it: should set custom replica count
    set:
      deployment.replicaCount: 3
    asserts:
      - equal:
          path: spec.replicas
          value: 3
```

#### Running Tests

```bash
# Run all tests
helm unittest drunk-app/

# Run specific test
helm unittest drunk-app/tests/deployment_test.yaml

# Run tests with verbose output
helm unittest drunk-app/ -v
```

### Integration Testing

#### Local Kubernetes Testing

```bash
# Install chart in local cluster
helm install test-release drunk-app/ -f test-values.yaml

# Verify deployment
kubectl get all -l app.kubernetes.io/name=drunk-app

# Test application functionality
kubectl port-forward svc/test-release-drunk-app 8080:80

# Cleanup
helm uninstall test-release
```

#### Test Values

Create comprehensive test values in `values.example.yaml`:

```yaml
global:
  image: "nginx"
  tag: "1.21"

deployment:
  enabled: true
  replicaCount: 2
  ports:
    http: 80

service:
  type: ClusterIP

ingress:
  enabled: true
  hosts:
    - host: test.example.com
      paths:
        - path: /
          pathType: Prefix

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

### Automated Testing

The project uses GitHub Actions for CI/CD:

```yaml
# .github/workflows/test.yml
name: Test Charts
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Set up Helm
        uses: azure/setup-helm@v3
      - name: Run chart tests
        run: |
          helm unittest drunk-app/
          helm unittest drunk-lib/
```

## Contributing Guidelines

### Code Style

#### YAML Formatting

- Use 2 spaces for indentation
- Keep lines under 120 characters
- Use meaningful variable names
- Add comments for complex logic

#### Template Best Practices

```yaml
# Good: Clear conditionals
{{- if .Values.ingress.enabled }}
# Template content
{{- end }}

# Good: Proper indentation
labels:
  {{- include "app.labels" . | nindent 4 }}

# Good: Safe value access
{{- with .Values.resources }}
resources:
  {{- toYaml . | nindent 2 }}
{{- end }}
```

#### Helper Function Guidelines

```yaml
# Good: Reusable helper
{{- define "app.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

# Usage
name: {{ include "app.fullname" . }}
```

### Pull Request Process

1. **Create Feature Branch**
   ```bash
   git checkout -b feature/description
   ```

2. **Make Changes**
   - Follow coding standards
   - Add/update tests
   - Update documentation

3. **Test Locally**
   ```bash
   helm unittest drunk-app/
   helm template test drunk-app/ --debug
   ```

4. **Submit PR**
   - Write clear commit messages
   - Reference related issues
   - Include testing instructions

5. **Review Process**
   - Automated tests must pass
   - Code review by maintainers
   - Documentation review

### Commit Message Format

```
type(scope): short description

Detailed description if needed

Fixes #123
```

Types: `feat`, `fix`, `docs`, `test`, `refactor`, `style`, `chore`

Examples:
```
feat(drunk-lib): add StatefulSet template support

Add comprehensive StatefulSet template with volume claim templates
and proper pod management policies.

Fixes #45
```

## Release Process

### Version Management

Both charts follow semantic versioning:

- **Major**: Breaking changes (e.g., 1.0.0 → 2.0.0)
- **Minor**: New features, backward compatible (e.g., 1.0.0 → 1.1.0)  
- **Patch**: Bug fixes (e.g., 1.0.0 → 1.0.1)

### Release Steps

1. **Update Chart Versions**
   ```yaml
   # drunk-lib/Chart.yaml
   version: 1.0.8  # Increment version
   
   # drunk-app/Chart.yaml  
   version: 1.2.7  # Increment version
   dependencies:
     - name: drunk-lib
       version: 1.0.8  # Update dependency
   ```

2. **Update Dependency**
   ```bash
   cd drunk-app/
   helm dependency update
   ```

3. **Test Release**
   ```bash
   helm package drunk-lib/
   helm package drunk-app/
   ```

4. **Create Release**
   - Create Git tag: `git tag v1.2.7`
   - Push tag: `git push origin v1.2.7`
   - GitHub Actions will automatically build and publish

### Automated Release

The project uses GitHub Actions for automated releases:

```yaml
# .github/workflows/release.yml
name: Release Charts
on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v3
      - name: Package and Release
        run: |
          helm package drunk-lib/
          helm package drunk-app/
          # Upload to GitHub Releases
```

## Best Practices

### Template Development

1. **Defensive Programming**
   ```yaml
   # Check for required values
   {{- if not .Values.global.image }}
   {{- fail "global.image is required" }}
   {{- end }}
   
   # Safe value access
   {{- with .Values.optional.setting }}
   setting: {{ . }}
   {{- end }}
   ```

2. **Resource Naming**
   ```yaml
   # Use consistent naming helpers
   name: {{ include "app.fullname" . }}
   labels: {{ include "app.labels" . | nindent 4 }}
   ```

3. **Configuration Validation**
   ```yaml
   # Validate mutually exclusive options
   {{- if and .Values.deployment.enabled .Values.statefulset.enabled }}
   {{- fail "Cannot enable both deployment and statefulset" }}
   {{- end }}
   ```

### Documentation Standards

1. **Template Documentation**
   - Document all configuration options
   - Provide examples for complex features
   - Explain default behaviors

2. **Code Comments**
   ```yaml
   {{/*
   Generate the full name for the application.
   Truncates at 63 chars due to Kubernetes naming limits.
   */}}
   {{- define "app.fullname" -}}
   ```

3. **Change Documentation**
   - Update relevant docs with changes
   - Add migration notes for breaking changes
   - Include examples for new features

### Security Considerations

1. **Default Security**
   ```yaml
   # Always include security contexts
   securityContext:
     allowPrivilegeEscalation: false
     readOnlyRootFilesystem: true
     runAsNonRoot: true
   ```

2. **Secret Handling**
   ```yaml
   # Never expose secrets in logs
   {{- if .Values.secrets }}
   # Create secret without logging values
   {{- end }}
   ```

3. **Resource Limits**
   ```yaml
   # Always set resource limits
   resources:
     limits:
       cpu: {{ .Values.resources.limits.cpu | default "500m" }}
       memory: {{ .Values.resources.limits.memory | default "512Mi" }}
   ```

### Performance Optimization

1. **Conditional Rendering**
   ```yaml
   # Only render when needed
   {{- if .Values.feature.enabled }}
   # Resource definition
   {{- end }}
   ```

2. **Template Caching**
   - Use `helm template --debug` to check rendering performance
   - Minimize complex loops in templates
   - Cache repeated calculations in variables

### Troubleshooting Development Issues

#### Common Problems

1. **Template Syntax Errors**
   ```bash
   # Debug template rendering
   helm template test drunk-app/ --debug
   ```

2. **Value Access Issues**
   ```bash
   # Check available values
   helm template test drunk-app/ --debug | grep -A 10 "VALUES:"
   ```

3. **Dependency Issues**
   ```bash
   # Update dependencies
   helm dependency update drunk-app/
   
   # Check dependency status
   helm dependency list drunk-app/
   ```

4. **Test Failures**
   ```bash
   # Run tests with verbose output
   helm unittest drunk-app/ -v
   
   # Test specific template
   helm unittest drunk-app/tests/deployment_test.yaml -v
   ```

## Getting Help

- **Documentation**: Start with the [main docs](./README.md)
- **Issues**: [GitHub Issues](https://github.com/baoduy/drunk.charts/issues)
- **Discussions**: [GitHub Discussions](https://github.com/baoduy/drunk.charts/discussions)
- **Author**: [Steven Hoang](https://drunkcoding.net)

---

*Happy coding! 🍻 Your contributions help make Kubernetes deployments easier for everyone.*