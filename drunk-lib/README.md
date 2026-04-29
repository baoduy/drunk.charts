# drunk-lib — Helm Library Chart

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/drunk-app)](https://artifacthub.io/packages/search?repo=drunk-app)

`drunk-lib` is a **library Helm chart** (`type: library`) — it ships only reusable named templates, not deployable resources. Application charts add it as a dependency and pull in the resources they need.

The application chart [`drunk-app`](../drunk-app) is the canonical consumer; each `drunk-app/templates/<kind>.yaml` is a one-line wrapper that calls the matching `drunk-lib.<name>` include.

## Repository

- Source: <https://github.com/baoduy/drunk.charts>
- Hosted index: <https://baoduy.github.io/drunk.charts/drunk-lib>

## Adding the dependency

```yaml
# Chart.yaml of the consumer chart
dependencies:
  - name: drunk-lib
    version: 1.x.x
    repository: "https://baoduy.github.io/drunk.charts/drunk-lib"
```

Then `helm dependency update` and reference any of the named templates below from `<consumer>/templates/*.yaml`.

## Available templates

| Template file | Include name | Values key | Generates |
|---|---|---|---|
| `_configMap.tpl` | `drunk-lib.configMap` | `configMap`, `configFrom` | `ConfigMap` |
| `_cronjob.tpl` | `drunk-lib.cronJobs` | `cronJobs[]` | `CronJob` (one per entry) |
| `_deployment.tpl` | `drunk-lib.deployment` | `deployment`, `global`, `env`, `volumes`, `secretProvider` | `Deployment` |
| `_gateway.tpl` | `drunk-lib.gateway` | `gateway` | Gateway API `Gateway` |
| `_hpa.tpl` | `drunk-lib.hpa` | `autoscaling` | `HorizontalPodAutoscaler` |
| `_httproute.tpl` | `drunk-lib.httpRoute` | `httpRoute` | Gateway API `HTTPRoute` |
| `_imagePull-secret.tpl` | `drunk-lib.imagePullSecret` | `imageCredentials` | dockerconfig `Secret` |
| `_ingress.tpl` | `drunk-lib.ingress` | `ingress` | networking.k8s.io/v1 `Ingress` |
| `_job.tpl` | `drunk-lib.jobs` | `jobs[]` | `Job` (one per entry) |
| `_networkPolicy.tpl` | `drunk-lib.networkPolicies` | `networkPolicy`, `networkPolicies[]` | `NetworkPolicy` |
| `_secretprovider.tpl` | `drunk-lib.secretProvider` | `secretProvider` | `SecretProviderClass` (CSI Secrets Store) |
| `_secrets.tpl` | `drunk-lib.secrets` | `secrets`, `secretFrom` | `Secret` |
| `_service.tpl` | `drunk-lib.service` | `service`, `deployment.ports` | `Service` |
| `_serviceAccount.tpl` | `drunk-lib.serviceAccount` | `serviceAccount` | `ServiceAccount` |
| `_statefulset.tpl` | `drunk-lib.statefulset` | `statefulset`, `global`, `volumes` | `StatefulSet` + `volumeClaimTemplates` |
| `_tls-secrets.tpl` | `drunk-lib.tls` | `tlsSecrets{}` | `kubernetes.io/tls` `Secret` (one per key) |
| `_volumes.tpl` | `drunk-lib.volumes` | `volumes` | `PersistentVolumeClaim` (one per non-emptyDir entry) |
| `_backend-tls-policy.tpl` | `drunk-lib.backendTlsPolicy` | `backendTlsPolicy` | Gateway API `BackendTLSPolicy` |

## Aggregator

For consumers that want everything in a single line, `_helpers.tpl` defines `drunk-lib.all` which expands to every template above:

```yaml
{{ include "drunk-lib.all" . }}
```

## Naming helpers

`_helpers.tpl` exposes name templates that consumer charts can rely on:

| Helper | Returns |
|---|---|
| `app.name` | Chart name (or `nameOverride`) truncated to 63 chars |
| `app.fullname` | `<release>-<name>` (or `fullnameOverride`) |
| `app.chart` | `<chart>-<version>` |
| `app.labels` | Standard labels block (chart, name, instance, version, managed-by) |
| `app.selectorLabels` | Selector subset of labels |
| `app.serviceAccountName` | Resolved ServiceAccount name |
| `app.checksums` | `checksum/configs` and `checksum/secrets` annotations for pod restart on change |
| `app.secretProviderName` | `<spName>` — `secretProvider.name` or `<app.name>-spc` |
| `app.secretProviderVolumeName` | `<spName>-vol` — Pod volume name for the CSI Secrets Store mount |
| `app.secretProviderClassName` | `<spName>-cls` — `SecretProviderClass` resource name |

The three `secretProvider*` helpers replace the previous inline `printf "%s-spc" ...` pattern duplicated across deployment/statefulset/job/cronjob templates.

## Gateway API support

Drunk-lib supports the Kubernetes Gateway API as an alternative to traditional `Ingress`. Both `Gateway` and `HTTPRoute` are off by default.

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

## SecretProviderClass (Azure Key Vault, AWS Secrets Manager, GCP Secret Manager)

```yaml
secretProvider:
  enabled: true
  name: my-spc
  provider:
    name: azure          # azure | aws | gcp
    tenantId: "<tenant-guid>"
    vaultName: "my-keyvault"
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

When `secretObjects` is omitted, drunk-lib auto-generates a `secretObjects` mapping from `objects[]`.

## TLS secrets

```yaml
tlsSecrets:
  cloudflare:
    enabled: true
    crt: <base64-encoded PEM>   # OR crtFile: certs/cloudflare.crt
    key: <base64-encoded PEM>   # OR keyFile: certs/cloudflare.key
    ca:  <base64-encoded PEM>   # OR caFile:  certs/cloudflare-ca.crt   (optional)
```

Both `crt` and `key` are required by `kubernetes.io/tls`; the template fails fast at render time if either is missing. Use `enabled: false` to disable an entry without removing it from values.

## Testing

This repository uses [helm-unittest](https://github.com/helm-unittest/helm-unittest). Run:

```bash
./drunk-lib/verify.sh   # packages, indexes, and copies the latest .tgz to drunk-app/charts
```

After any edit inside `drunk-lib/`, `verify.sh` rebuilds the package and refreshes `drunk-app/charts/drunk-lib-<version>.tgz` so consumer rendering picks up the change.

## License

MIT — see [LICENSE](LICENSE).
