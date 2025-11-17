# Changelog

All notable changes to the drunk-k8s-gateway chart will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-11-17

### Added

- Initial release of drunk-k8s-gateway chart
- Support for Gateway API v1.2.0 CRD installation
- GatewayClass resource creation
- Gateway resource creation with HTTP and HTTPS listeners
- Domain-specific Gateway support for multi-domain deployments
- cert-manager ClusterIssuer integration for automatic TLS management
- Automated CRD installation scripts (`install-crds.sh`, `uninstall-crds.sh`)
- Comprehensive documentation and examples
- Build, test, and verification scripts
- Example values files for common scenarios:
  - Minimal configuration
  - Basic Gateway setup
  - Domain-specific Gateway (drunk.dev)
  - cert-manager integration
  - Multi-domain setup
  - Production-ready configuration
- Integration with drunk-lib for consistency
- Support for both standard and experimental Gateway API channels
- Customizable GatewayClass parameters
- Namespace-scoped and cluster-scoped allowedRoutes configurations

### Features

- ✅ Automated Gateway API CRD installation
- ✅ Flexible GatewayClass configuration
- ✅ Multi-domain Gateway support
- ✅ cert-manager integration with HTTP-01 and DNS-01 challenges
- ✅ Compatible with NGINX Gateway Fabric, Istio, and other controllers
- ✅ Comprehensive verification and testing scripts

### Documentation

- Complete README with usage examples
- Quick start guide
- Example configurations for various scenarios
- Integration guide with drunk-app chart
- Troubleshooting section

## [Unreleased]

### Planned Features

- Support for Gateway API v1.3.0
- Advanced traffic splitting examples
- Gateway policies and filters
- Multi-cluster Gateway support
- Prometheus metrics integration
- More Gateway controller examples

---

For more information, visit: https://github.com/baoduy/drunk.charts
