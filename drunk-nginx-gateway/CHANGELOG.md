# Changelog

All notable changes to the drunk-nginx-gateway chart will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-04-29

### Added

- Initial release of drunk-nginx-gateway chart
- Vendored upstream `nginx-gateway-fabric` chart (range `2.x.x`) from
  `oci://ghcr.io/nginx/charts` as a subchart (alias `nginxGatewayFabric`)
- Gateway API v1.2.0+ CRD installation via two-phase `install.sh` (kubectl + helm)
- GatewayClass template that auto-suppresses when the NGF subchart owns the resource
- Gateway resource creation with HTTP and HTTPS listeners
- Domain-specific Gateway support for multi-domain deployments
- cert-manager ClusterIssuer + Certificate templates for automatic TLS management
- `values.local.yaml` for K3s / kind / minikube quick-start (NodePort 30080/30443)
- `build.sh`, `install.sh`, `uninstall.sh`, `verify.sh`, `test.sh` operational scripts

### Features

- Automated Gateway API CRD installation
- Default GatewayClass `nginx` with controller `gateway.nginx.org/nginx-gateway-controller`
- Multi-domain Gateway support via `domains[]`
- cert-manager integration with HTTP-01 and DNS-01 challenges
- Standard and experimental Gateway API channels supported
- NginxProxy / NginxGateway custom CRDs auto-installed by the vendored subchart

### Documentation

- README with usage examples and migration notes
- Quick start guide
- CERT-MANAGER-TESTING.md (shared with the Traefik wrapper)

## [Unreleased]

### Added

- `values.aks.yaml` for Azure AKS deployments with an internal Azure Load
  Balancer (annotation `service.beta.kubernetes.io/azure-load-balancer-internal`
  applied via NGF `nginx.service.patches[]` StrategicMerge so it survives
  NginxProxy CRD admission, with `externalTrafficPolicy: Local` and a static
  `loadBalancerIP`).
- Top-of-file YAML anchors in `values.yaml`, `values.local.yaml`, and
  `values.aks.yaml` to DRY the GatewayClass identity (`gatewayClassName`,
  `gatewayControllerName`).

### Fixed

### Planned

- Gateway API v1.3.0 / v1.4.0 default
- Examples directory with NginxProxy parametersRef wiring
- Multi-cluster Gateway support
- Prometheus metrics integration

---

For more information, visit: https://github.com/baoduy/drunk.charts
