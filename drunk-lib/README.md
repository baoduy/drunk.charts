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
    version: 2.x.x
    repository: oci://ghcr.io/baoduy          # OCI (how drunk-app consumes it)
    # or: repository: "https://baoduy.github.io/drunk.charts/drunk-lib"
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
| `_pdb.tpl` | `drunk-lib.pdb` | `podDisruptionBudget` | `policy/v1` `PodDisruptionBudget` |
| `_secretprovider.tpl` | `drunk-lib.secretProvider` | `secretProvider` | `SecretProviderClass` (CSI Secrets Store) |
| `_secrets.tpl` | `drunk-lib.secrets` | `secrets`, `secretFrom` | `Secret` |
| `_service.tpl` | `drunk-lib.service` | `service`, `deployment.ports` | `Service` |
| `_serviceAccount.tpl` | `drunk-lib.serviceAccount` | `serviceAccount` | `ServiceAccount` |
| `_statefulset.tpl` | `drunk-lib.statefulset` | `statefulset`, `global`, `volumes` | `StatefulSet` + `volumeClaimTemplates` |
| `_tls-secrets.tpl` | `drunk-lib.tls` | `tlsSecrets{}` | `kubernetes.io/tls` `Secret` (one per key) |
| `_volumes.tpl` | `drunk-lib.volumes` | `volumes` | `PersistentVolumeClaim` (one per entry without a non-PVC source) |
| `_backend-tls-policy.tpl` | `drunk-lib.backendTlsPolicy` | `httpRoute.tlsValidation`, `backendTlsPolicy` | Gateway API `BackendTLSPolicy` |
| `_nginx-upstream-settings-policy.tpl` | `drunk-lib.nginxUpstreamSettingsPolicy` | `nginxUpstreamSettingsPolicy` | NGINX `UpstreamSettingsPolicy` |
| `_nginx-client-settings-policy.tpl` | `drunk-lib.nginxClientSettingsPolicy` | `nginxClientSettingsPolicy` | NGINX `ClientSettingsPolicy` |

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

### Response headers

HTTPRoute rule filters accept `ResponseHeaderModifier` with optional `set`, `add`, and `remove` lists, matching `RequestHeaderModifier`:

```yaml
httpRoute:
  enabled: true
  rules:
    - filters:
        - type: ResponseHeaderModifier
          responseHeaderModifier:
            set:
              - name: Strict-Transport-Security
                value: "max-age=31536000; includeSubDomains"
            add:
              - name: X-Content-Type-Options
                value: nosniff
            remove: [Server]
```

### NGINX Gateway Fabric policies

These optional policies use `gateway.nginx.org/v1alpha1` and require the [NGF 2.5.1 policy CRDs](https://github.com/nginx/nginx-gateway-fabric/blob/v2.5.1/deploy/crds.yaml).
Omitting either block, or setting its `enabled` flag to `false`, renders nothing.
Enable the chart's Service for the upstream policy and `httpRoute.enabled` for the client policy.
Both policy namespaces are the release namespace; targets use `app.fullname` and cannot be overridden.
`UpstreamSettingsPolicy.spec.targetRefs` is a list pointing at this chart's Service.
`ClientSettingsPolicy.spec.targetRef` is a single reference pointing at this chart's HTTPRoute.
All omitted settings retain controller defaults.

```yaml
nginxUpstreamSettingsPolicy:
  enabled: true
  keepAlive:
    connections: 32
    requests: 1000
    time: "1h"
    timeout: "60s"
  loadBalancingMethod: "hash consistent"
  hashMethodKey: "$request_uri"
  zoneSize: "1m"
nginxClientSettingsPolicy:
  enabled: true
  body: {maxSize: "10m", timeout: "30s"}
  keepAlive:
    requests: 1000
    time: "1h"
    timeout: {server: "75s", header: "60s"}
```

| Key | Default | Meaning |
|---|---|---|
| `nginxUpstreamSettingsPolicy.enabled` | `false` | Render an upstream policy targeting this Service. |
| `nginxUpstreamSettingsPolicy.keepAlive.connections` | omitted | Integer idle connection count; `0` disables upstream keep-alive. |
| `nginxUpstreamSettingsPolicy.keepAlive.requests` | omitted | Integer request count per connection. |
| `nginxUpstreamSettingsPolicy.keepAlive.time` | omitted | String duration, such as `1h`. |
| `nginxUpstreamSettingsPolicy.keepAlive.timeout` | omitted | String idle duration, such as `60s`. |
| `nginxUpstreamSettingsPolicy.loadBalancingMethod` | omitted | NGF load balancing method, such as `least_conn` or `hash consistent`. |
| `nginxUpstreamSettingsPolicy.hashMethodKey` | omitted | NGINX variable; required for `hash` and `hash consistent`. |
| `nginxUpstreamSettingsPolicy.zoneSize` | omitted | String size, such as `1m`. |
| `nginxClientSettingsPolicy.enabled` | `false` | Render a client policy targeting this HTTPRoute. |
| `nginxClientSettingsPolicy.body.maxSize` | omitted | String request body size, such as `10m`; `"0"` disables the limit. |
| `nginxClientSettingsPolicy.body.timeout` | omitted | String request body read duration. |
| `nginxClientSettingsPolicy.keepAlive.requests` | omitted | Integer request count per connection. |
| `nginxClientSettingsPolicy.keepAlive.time` | omitted | String connection duration. |
| `nginxClientSettingsPolicy.keepAlive.timeout.server` | omitted | String idle duration; `"0"` disables client keep-alive. |
| `nginxClientSettingsPolicy.keepAlive.timeout.header` | omitted | String response header duration; requires `server`. |

### Backend TLS validation

A `BackendTLSPolicy` renders only when `httpRoute.enabled` is true and `httpRoute.tlsValidation` is non-empty.
It targets this chart's Service and now always uses the release namespace, ignoring `httpRoute.namespace`.
This corrects policies previously rendered outside the Service's namespace.
The same policy is included by `drunk-lib.all` and by the `drunk-app` wrapper.

```yaml
httpRoute:
  enabled: true
  hostnames: ["app.example.com"]
  tlsValidation:
    caCertificateRefs:
      - group: ""
        kind: ConfigMap
        name: backend-ca
backendTlsPolicy:
  sectionName: https
  hostname: "backend.example.com"
  options: {tls-verify-depth: "3"}
```

| Key | Default | Meaning |
|---|---|---|
| `backendTlsPolicy.sectionName` | `https` | Service port name targeted by the policy. |
| `backendTlsPolicy.hostname` | `httpRoute.tlsValidation.hostname`, then the first `httpRoute.hostnames` entry | TLS certificate hostname; override when the backend name differs from the route. |
| `backendTlsPolicy.options` | `{tls-verify-depth: "1"}` | Complete options map; an explicit `{}` clears the default. Keep option values as strings. |

`httpRoute.tlsValidation` still passes validation settings through, including `caCertificateRefs` and `wellKnownCACertificates`.
The hostname renders once; `backendTlsPolicy.hostname` takes precedence over a hostname inside `tlsValidation`.

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
    crt: <base64-encoded PEM>   # OR crtFile: certs/cloudflare.crt (raw PEM file, auto-encoded)
    key: <base64-encoded PEM>   # OR keyFile: certs/cloudflare.key (raw PEM file, auto-encoded)
    ca:  <base64-encoded PEM>   # OR caFile:  certs/cloudflare-ca.crt (raw PEM file, auto-encoded, optional)
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
| `drunk-lib.service` | `service.ports` OR `deployment.ports` | `service.enabled` (bool, default true), `service.type` (string, default ClusterIP), `service.annotations` (map), `service.loadBalancerIP` (string — static IP, e.g. AKS fixed private IP), `service.port` (int — exposed port for the single-port case, default 80) |
| `drunk-lib.ingress` | `ingress.enabled: true`, `ingress.hosts` | Port resolved via `drunk.utils.ingressPort`: prefers `service.ports` → `deployment.ports`; one port maps to `80`, no ports to `8080`; multiple ports prefer `http`, else the alphabetically first name |
| `drunk-lib.hpa` | `autoscaling.enabled: true`, `autoscaling.minReplicas`, `autoscaling.maxReplicas` | `autoscaling.targetKind` (default "Deployment"), `autoscaling.targetApiVersion` (default "apps/v1"), `autoscaling.targetCPUUtilizationPercentage`, `autoscaling.targetMemoryUtilizationPercentage`, `autoscaling.behavior` (optional map, passed through without defaults), `autoscaling.metrics` (optional list of full autoscaling/v2 metric specs, appended after CPU and memory entries in the supplied order) |
| `drunk-lib.cronJobs` | `cronJobs` array with `name` and `schedule` | `cronJobs[].enabled` (bool, default true — set false to skip that entry) |
| `drunk-lib.jobs` | `jobs` array with `name` | `jobs[].enabled` (bool, default true — set false to skip that entry) |
| `drunk-lib.deployment` | `deployment.enabled: true`, `global.image`, `global.tag` | `liveness`, `readiness`, `startup` (string or probe map); `lifecycle`, `preStopSleepSeconds`, `terminationGracePeriodSeconds`, `minReadySeconds`, `progressDeadlineSeconds`, `revisionHistoryLimit`, `strategy`; `autoscaling.omitReplicas`; shared scheduling keys below; existing `deployment.*` keys |
| `drunk-lib.statefulset` | `statefulset.enabled: true`, `global.image`, `global.tag` | `liveness`, `readiness`, `startup` (string or probe map); `lifecycle`, `preStopSleepSeconds`, `terminationGracePeriodSeconds`, `minReadySeconds`; shared scheduling keys below; existing `statefulset.*` keys |
| `drunk-lib.pdb` | `podDisruptionBudget.enabled: true`, an enabled Deployment or StatefulSet, exactly one of `minAvailable` / `maxUnavailable` | `unhealthyPodEvictionPolicy` (default `AlwaysAllow`) |
| `drunk-lib.serviceAccount` | `serviceAccount.enabled: true` | `serviceAccount.name` |
| `drunk-lib.gateway` | `gateway.enabled: true` | all `gateway.*` keys |
| `drunk-lib.httpRoute` | `httpRoute.enabled: true` | all `httpRoute.*` keys |
| `drunk-lib.networkPolicies` | `networkPolicies` array | `networkPolicy` (legacy single-policy) |
| `drunk-lib.volumes` | `volumes` map | — |
| `drunk-lib.secretProvider` | `secretProvider.enabled: true` | all `secretProvider.*` keys |
| `drunk-lib.imagePullSecret` | `imageCredentials` map | — |
| `drunk-lib.tls` | `tlsSecrets` map | — |

### Optional HPA behavior and metrics

`autoscaling.behavior` passes through to `spec.behavior`, including `scaleUp` and `scaleDown` policies, stabilization windows, and `selectPolicy`.
When omitted or empty, it adds no behavior key or defaults.
`autoscaling.metrics` accepts full `autoscaling/v2` metric specs (`Pods`, `Object`, `External`, `ContainerResource`, or `Resource`).
Entries follow any CPU and memory utilization entries in the supplied order, and work without either utilization target.
Omitting both new keys preserves the existing output, including the bare `metrics:` key when no utilization target is set.
`Pods`, `Object`, and `External` metrics require a metrics adapter in the cluster, such as Prometheus Adapter or KEDA.
Commented examples are provided in `drunk-app/values.yaml`.

### Optional rollout keys

The probe and shutdown keys belong under `deployment` or `statefulset`. The scheduling keys below are top-level. All features are opt-in.

| Key | Behavior when set |
|---|---|
| `deployment.liveness`, `statefulset.liveness` | A string keeps the legacy HTTP probe with port `http`, delay `60`, period `300`. A map passes through unchanged. |
| `deployment.readiness`, `statefulset.readiness` | A string keeps the legacy HTTP probe on port `http`. A map passes through unchanged. |
| `deployment.startup`, `statefulset.startup` | A string probes the path on port `http` with period `5`, failure threshold `30`. A map passes through unchanged. |
| `deployment.lifecycle`, `statefulset.lifecycle` | Raw main-container lifecycle, including `{}`, overrides convenience sleep. |
| `deployment.preStopSleepSeconds`, `statefulset.preStopSleepSeconds` | Native `preStop.sleep.seconds`; no shell or container sleep binary needed. |
| `deployment.terminationGracePeriodSeconds`, `statefulset.terminationGracePeriodSeconds` | Pod termination budget; must exceed `preStopSleepSeconds` when both are set, even with a raw lifecycle override. |
| `deployment.minReadySeconds`, `statefulset.minReadySeconds` | Workload ready interval; presence checks retain `0`. |
| `deployment.progressDeadlineSeconds`, `deployment.revisionHistoryLimit` | Optional Deployment spec fields; presence checks retain `0`. |
| `deployment.strategy.maxSurge`, `deployment.strategy.maxUnavailable` | Retain explicit `0` or percentages; absent keys default to `1` / `0`. Both cannot be zero for RollingUpdate. `Recreate` emits no rollingUpdate block or comment. |
| `autoscaling.omitReplicas` | Default `false`; omits Deployment `spec.replicas` only with an enabled HPA targeting Deployment (including an unset targetKind). StatefulSet replicas remain. HPA `minReplicas` remains. |
| `podAntiAffinityPreset` | Default `""`; `soft` uses preferred anti-affinity, weight `100`; `hard` uses required anti-affinity. Both use hostname topology and this chart's selector labels. Unknown presets fail with the allowed values. |
| `topologySpreadConstraints` | Default absent; list of raw constraints. Missing `labelSelector` receives this chart's selector labels. Explicit selectors remain unchanged. |
| `podDisruptionBudget.enabled` | Default `false`; emits a budget only for an enabled Deployment or StatefulSet. Also included by `drunk-lib.all`. |
| `podDisruptionBudget.minAvailable`, `podDisruptionBudget.maxUnavailable` | Set exactly one, integer or percentage. An integer minAvailable at least equal to the effective replica count fails when autoscaling is disabled. Replica count defaults to `1`. |
| `podDisruptionBudget.unhealthyPodEvictionPolicy` | Default `AlwaysAllow` when enabled; raw policy override supported. |

**Migration for `autoscaling.omitReplicas`:** On an existing release that already has an HPA, turning this flag on makes Helm/Argo drop the replicas field once. Kubernetes then defaults replicas to `1` until the HPA scales back up. Plan the first sync accordingly. Making this flag the default later would be a breaking change and is outside this patch.

Probe maps support `httpGet` (including `scheme: HTTPS`), `tcpSocket`, `exec`, and `grpc`, plus all Kubernetes probe timings. Shutdown hooks apply only to the main container, never init containers, Jobs, or CronJobs.

The anti-affinity preset preserves user affinity such as `nodeAffinity`. An explicit `affinity.podAntiAffinity` wins, including an empty map. Share one YAML anchor across aliased sub-charts: injected selectors use each alias's own `app.kubernetes.io/name`.

Use Kubernetes **1.30+** for the [native sleep lifecycle action](https://kubernetes.io/blog/2025/05/14/kubernetes-v1-33-updates-to-container-lifecycle/), and **1.31+** for stable [unhealthyPodEvictionPolicy](https://kubernetes.io/docs/tasks/run-application/configure-pdb/#unhealthy-pod-eviction-policy). Earlier clusters retain their existing behavior when these features are absent.

### Example — Zero-downtime Deployment

```yaml
global:
  image: example/app
  tag: "1.0.0"
podAntiAffinityPreset: soft
affinity:
  nodeAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 50
        preference:
          matchExpressions:
            - key: pool
              operator: In
              values: [apps]
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: ScheduleAnyway
podDisruptionBudget:
  enabled: true
  minAvailable: 1
  unhealthyPodEvictionPolicy: AlwaysAllow
deployment:
  enabled: true
  replicaCount: 3
  ports: {http: 8080, https: 8443}
  liveness:
    httpGet: {path: /healthz, port: https, scheme: HTTPS}
    periodSeconds: 10
    failureThreshold: 3
  readiness:
    httpGet: {path: /healthz/ready, port: https, scheme: HTTPS}
    periodSeconds: 5
    failureThreshold: 3
  startup: "/healthz"
  terminationGracePeriodSeconds: 45
  preStopSleepSeconds: 10
  minReadySeconds: 10
  progressDeadlineSeconds: 600
  revisionHistoryLimit: 5
  strategy: {type: RollingUpdate, maxSurge: 0, maxUnavailable: 1}
autoscaling:
  enabled: true
  omitReplicas: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
```

Readiness must reflect whether the app can serve traffic. Tune shutdown, startup, and rollout timing for the application. The first HPA migration still needs the sync planning described above.

### Shared keys (by design)

The following keys are shared across all workload templates (`deployment`, `statefulset`, `cronJobs`, `jobs`). A standalone chart that uses only one workload template simply populates only what that template reads — unused shared keys are absent and silently skipped:

- `env` — plain strings or `valueFrom` references injected into all workload containers, including init containers
- `volumes` — shared PVC, emptyDir, ConfigMap, Secret, projected or CSI mounts
- `resources` — container resource limits / requests; Jobs and CronJobs may replace them per entry
- `configMap` / `configFrom` — config sources mounted into all workload containers
- `secrets` / `secretFrom` — secret sources mounted into all workload containers
- `secretProvider` — CSI secret store
- `podSecurityContext` / `securityContext` — security contexts
- `serviceAccount` — service account used by all workloads
- `nodeSelector` / `affinity` / `tolerations` — app scheduling; Jobs and CronJobs inherit only node placement, as described below
- `global.*` — image, tag, imagePullPolicy, imagePullSecret, initContainer, storageClassName

### Environment sources and volume types

`env` remains a name-to-value map. Plain values keep their existing quoted string rendering.
An entry containing `valueFrom` passes the complete Kubernetes source through instead of rendering `value`.
This works on Deployment and StatefulSet main and init containers, Jobs, and CronJobs.

```yaml
env:
  LOG_LEVEL: info
  POD_NAME:
    valueFrom: {fieldRef: {fieldPath: metadata.name}}
  POD_NAMESPACE:
    valueFrom: {fieldRef: {fieldPath: metadata.namespace}}
  PASSWORD:
    valueFrom: {secretKeyRef: {name: credentials, key: password}}
  MODE:
    valueFrom: {configMapKeyRef: {name: settings, key: mode}}
  CPU_LIMIT:
    valueFrom: {resourceFieldRef: {resource: limits.cpu, divisor: 1m}}
```

Each `volumes` entry retains `mountPath`, optional `subPath`, and `readOnly` (default `false`).
Choose one source key: `configMap`, `secret`, `projected`, `csi`, or `emptyDir`; multiple source keys fail rendering.
ConfigMap, Secret, projected and CSI source maps pass through unchanged on all 4 workloads and never create a PVC.
`emptyDir: true` still renders `emptyDir: {}`. A non-empty `emptyDir` map passes through `medium` and/or `sizeLimit` and creates no PVC.
`emptyDir: {}` retains the existing PVC and its pod mount. An entry with no source key, or `emptyDir: false`, also keeps the existing PVC behavior and storage settings.
These volume options also apply to existing Deployment and StatefulSet init-container mounts.

```yaml
volumes:
  settings:
    mountPath: /etc/app/app.conf
    subPath: app.conf
    readOnly: true
    configMap: {name: settings, items: [{key: app.conf, path: app.conf}]}
  credentials:
    mountPath: /etc/credentials
    readOnly: true
    secret: {secretName: credentials}
  combined:
    mountPath: /etc/combined
    readOnly: true
    projected:
      sources: [{configMap: {name: settings}}, {secret: {name: credentials}}]
  external:
    mountPath: /mnt/external
    readOnly: true
    csi: {driver: example.csi.k8s.io, readOnly: true, volumeAttributes: {bucket: files}}
  scratch:
    mountPath: /scratch
    emptyDir: {medium: Memory, sizeLimit: 64Mi}
```

### Workload object metadata and priority

| Key | Default | Behavior |
|---|---|---|
| `deployment.labels`, `statefulset.labels` | omitted | Extra labels on the workload object; standard label keys cause a clear render error. |
| `deployment.annotations`, `statefulset.annotations` | omitted | Annotations on the workload object, such as `reloader.stakater.com/auto: "true"`. |
| `deployment.priorityClassName`, `statefulset.priorityClassName` | omitted | Priority class on the workload's pod spec. |

Custom labels and annotations render as strings. Standard labels always remain present.
Object metadata is separate from existing `podLabels` and `podAnnotations` on each workload.
`priorityClassName` is supported only on Deployment and StatefulSet pods.

### Job and CronJob pod options

Jobs and CronJobs now inherit the app's node scheduling by default: top-level `nodeSelector`, `tolerations`, and `affinity.nodeAffinity`.
They never inherit `affinity.podAffinity`, `affinity.podAntiAffinity`, `podAntiAffinityPreset`, or `topologySpreadConstraints`.
Those app-pod rules could otherwise prevent a Job from scheduling alongside the app.

| Per-entry key on `jobs[]` or `cronJobs[]` | Default | Behavior |
|---|---|---|
| `nodeSelector` | App's `nodeSelector` | Replaces the complete map; `{}` disables inheritance. |
| `tolerations` | App's `tolerations` | Replaces the complete list; `[]` disables inheritance. |
| `affinity` | App's `affinity.nodeAffinity` only | Replaces the complete affinity map and renders as written, including explicit pod affinity; `{}` disables inheritance. |
| `podLabels` | omitted | Labels on this Job's pod template. |
| `podAnnotations` | omitted | Annotations on this Job's pod template. |
| `resources` | App's `resources` | Replaces the complete resources map; `{}` clears it. |

No pod metadata renders unless an entry supplies non-empty labels or annotations.
Job names retain their random suffix. All per-entry overrides are independent and never merge with the app's value.

```yaml
jobs:
  - name: migrate
    podLabels: {task: migration}
    podAnnotations: {tracking: migration}
    resources: {requests: {cpu: 250m, memory: 256Mi}}
    nodeSelector: {pool: batch}
    tolerations: [{key: batch, operator: Exists}]
    affinity: {} # Disable app node-affinity inheritance for this entry.
cronJobs:
  - name: report
    schedule: "0 2 * * *"
    nodeSelector: {} # Disable each inherited scheduling key separately.
    tolerations: []
    affinity: {}
```

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

### Example — Azure AKS internal LoadBalancer with a fixed private IP

```yaml
service:
  type: LoadBalancer
  loadBalancerIP: 192.168.123.222   # static private IP in your AKS subnet
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-internal: "true"
  ports:
    http: 8080
```

`annotations` and `loadBalancerIP` are both optional and render nothing when omitted, so existing consumers are unaffected. The same keys work for any cloud provider that honours `spec.loadBalancerIP` / provider annotations.

### Example — suppress Service in existing consumer

```yaml
# Add to your existing values — no other changes needed
service:
  enabled: false
```

---

## Non-Breaking Guarantee

Every `drunk-lib` change is regression-tested via golden-file snapshots in `drunk-lib/tests/golden/`. `bash drunk-lib/verify.sh` automatically re-renders and diffs the following stable renders after each packaging:

The approved scheduling fix above changes existing Jobs and CronJobs when app node scheduling is set.
Use the per-entry empty values above to retain their previous scheduling behavior.
The machine-diffed scenarios contain no Jobs or CronJobs and stay unchanged.

| Golden file | Render scenario |
|---|---|
| `drunk-app-default.yaml` | `drunk-app` with default `values.yaml` |
| `drunk-app-svc-disabled.yaml` | `drunk-app` with `service.enabled: false` |
| `drunk-app-secretprovider.yaml` | `drunk-app` with `secretProvider.enabled: true` |
| `drunk-app-tls-secrets.yaml` | Inline TLS cert/key/CA |
| `drunk-app-rollout.yaml` | Opt-in F1–F6 Deployment |
| `drunk-app-statefulset-rollout.yaml` | Opt-in F1, F2, F5, F6 StatefulSet |

`drunk-app-example.yaml` is also committed for human PR review but is **excluded from machine diff** because `_job.tpl` generates Job names with a random suffix (`randAlphaNum 5`) that changes on every render.

If you intentionally change consumer output (e.g. a format fix), update all golden files:

```bash
bash drunk-lib/snapshot.sh   # re-captures all golden files from repo root
bash drunk-lib/verify.sh     # must pass after update
git add drunk-lib/tests/golden/
git commit -m "test: update golden files for <reason>"
```
