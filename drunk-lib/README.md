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

---

## Standalone Template Usage

`drunk-lib` partials can be included individually — you are not required to use `drunk-lib.all`. A chart that only needs a ConfigMap and a Service can call exactly those two partials.

### Minimum values per template

| Template | Required keys | Optional keys added by this feature |
|---|---|---|
| `drunk-lib.configMap` | `configMap` (map) | — |
| `drunk-lib.secrets` | `secrets` (map) | — |
| `drunk-lib.service` | `service.ports` OR `deployment.ports` | `service.enabled` (bool, default true), `service.type` (string, default ClusterIP) |
| `drunk-lib.ingress` | `ingress.enabled: true`, `ingress.hosts` | Port resolved via `drunk.utils.ingressPort`: prefers `service.ports` → `deployment.ports` → 8080 |
| `drunk-lib.hpa` | `autoscaling.enabled: true`, `autoscaling.minReplicas`, `autoscaling.maxReplicas` | `autoscaling.targetKind` (default "Deployment"), `autoscaling.targetApiVersion` (default "apps/v1") |
| `drunk-lib.cronJobs` | `cronJobs` array with `name` and `schedule` | `cronJobs[].enabled` (bool, default true — set false to skip that entry) |
| `drunk-lib.jobs` | `jobs` array with `name` | `jobs[].enabled` (bool, default true — set false to skip that entry) |
| `drunk-lib.deployment` | `deployment.enabled: true`, `global.image`, `global.tag` | all other `deployment.*` keys |
| `drunk-lib.statefulset` | `statefulset.enabled: true`, `global.image`, `global.tag` | all other `statefulset.*` keys |
| `drunk-lib.serviceAccount` | `serviceAccount.enabled: true` | `serviceAccount.name` |
| `drunk-lib.gateway` | `gateway.enabled: true` | all `gateway.*` keys |
| `drunk-lib.httpRoute` | `httpRoute.enabled: true` | all `httpRoute.*` keys |
| `drunk-lib.networkPolicies` | `networkPolicies` array | `networkPolicy` (legacy single-policy) |
| `drunk-lib.volumes` | `volumes` map | — |
| `drunk-lib.secretProvider` | `secretProvider.enabled: true` | all `secretProvider.*` keys |
| `drunk-lib.imagePullSecret` | `imageCredentials` map | — |
| `drunk-lib.tls` | `tlsSecrets` map | — |

### Shared keys (by design)

The following keys are shared across all workload templates (`deployment`, `statefulset`, `cronJobs`, `jobs`). A standalone chart that uses only one workload template simply populates only what that template reads — unused shared keys are absent and silently skipped:

- `env` — environment variables injected into all workload containers
- `volumes` — shared PVC / emptyDir mounts
- `resources` — container resource limits / requests
- `configMap` / `configFrom` — config sources mounted into all workload containers
- `secrets` / `secretFrom` — secret sources mounted into all workload containers
- `secretProvider` — CSI secret store
- `podSecurityContext` / `securityContext` — security contexts
- `serviceAccount` — service account used by all workloads
- `nodeSelector` / `affinity` / `tolerations` — scheduling constraints
- `global.*` — image, tag, imagePullPolicy, imagePullSecret, initContainer, storageClassName

### Example — ConfigMap + Ingress only (no Deployment)

```yaml
# values.yaml of the new chart
configMap:
  APP_ENV: production

service:
  ports:
    http: 8080

ingress:
  enabled: true
  hosts:
    - host: myapp.example.com
      path: /
```

```yaml
# templates/all.yaml
{{ include "drunk-lib.configMap" . }}
{{ include "drunk-lib.service" . }}
{{ include "drunk-lib.ingress" . }}
```

### Example — StatefulSet + HPA targeting StatefulSet

```yaml
global:
  image: myapp
  tag: "1.0.0"

statefulset:
  enabled: true
  replicaCount: 3
  ports:
    http: 8080

autoscaling:
  enabled: true
  targetKind: StatefulSet
  targetApiVersion: apps/v1
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
```

### Example — suppress Service in existing consumer

```yaml
# Add to your existing values — no other changes needed
service:
  enabled: false
```

---

## Non-Breaking Guarantee

Every `drunk-lib` change is regression-tested via golden-file snapshots in `drunk-lib/tests/golden/`. `bash drunk-lib/verify.sh` automatically re-renders and diffs the following stable renders after each packaging:

| Golden file | Render scenario |
|---|---|
| `drunk-app-default.yaml` | `drunk-app` with default `values.yaml` |
| `drunk-app-svc-disabled.yaml` | `drunk-app` with `service.enabled: false` |
| `drunk-app-secretprovider.yaml` | `drunk-app` with `secretProvider.enabled: true` |

`drunk-app-example.yaml` is also committed for human PR review but is **excluded from machine diff** because `_job.tpl` generates Job names with a random suffix (`randAlphaNum 5`) that changes on every render.

If you intentionally change consumer output (e.g. a format fix), update all golden files:

```bash
bash drunk-lib/snapshot.sh   # re-captures all golden files from repo root
bash drunk-lib/verify.sh     # must pass after update
git add drunk-lib/tests/golden/
git commit -m "test: update golden files for <reason>"
```
