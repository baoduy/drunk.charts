# Upgrade Guide: drunk-app / drunk-lib 1.x → 2.x

For teams upgrading an existing `drunk-app` release or a chart that includes `drunk-lib`, including the Monxa platform team's `mx-apps` migration. Upgrade the chart and reconcile changed values first; enable rollout-safety features in later, separate syncs.

This guide compares the last 1.x archives in this repository (`drunk-app` **1.3.9**, with bundled `drunk-lib` **1.3.4**) with merged `dev`, including [#117](https://github.com/baoduy/drunk.charts/pull/117), [#119](https://github.com/baoduy/drunk.charts/pull/119), [#120](https://github.com/baoduy/drunk.charts/pull/120) and [#121](https://github.com/baoduy/drunk.charts/pull/121). All four PRs belong to the same unpublished patch after tag `v2.0.4`: **2.0.5 is expected**, but the publish pipeline derives the actual number from tags. Verify the published version and that it contains all four PRs before pinning it. The checked-in `Chart.yaml` version is not proof that a package has been published.

## Table of Contents

- [Breaking changes and migration hazards](#breaking-changes-and-migration-hazards)
- [2.0.4](#204)
- [Step-by-step migration](#step-by-step-migration)
- [HPA replica ownership](#hpa-replica-ownership)
- [New opt-in features](#new-opt-in-features)
- [Verification sources](#verification-sources)

## Breaking changes and migration hazards

Versions below name the first tagged release containing a correction, rather than attributing every change to 2.0.0. Some rows correct misleading defaults or make previously ignored values effective; they are still migration hazards.

| Version | Change | Who is affected | What to do |
|---------|--------|-----------------|------------|
| 2.0.3 | `drunk-app/values.yaml` became valid YAML in commit `4e583b3`; previously its malformed defaults were discarded. Defaults now apply. | Apps relying on absent chart defaults, including Job-only releases and apps with their own security or resource settings. | Compare rendered manifests. Explicitly override unwanted defaults; set `deployment.enabled: false` for Job-only releases. See the default list below. |
| 2.0.3 | The default-values key `serviceAccount.create` became `serviceAccount.enabled`. The last 1.x library already read `enabled`; `create` did nothing. | Values copied from the old app defaults that expect a ServiceAccount to be created. | Rename `create` to `enabled` when creation is intended. Verify the resulting account and pod `serviceAccountName`. |
| 2.0.3 | The default `volumes` list became a named map. The last 1.x library already ranged over map keys; this corrects the app's values shape. | Values copied from the old list example. | Use the volume name as the map key, remove `name`, and inspect mounts and PVC names before syncing. |
| 2.0.4 | `secretProvider.provider.useVMManagedIdentity: false` now renders `"false"`; the old template replaced a boolean `false` with `"true"`. | Azure consumers setting `false` but relying on node VM identity. | Set `true` (or omit the key) to keep VM identity. For workload identity, retain `false` and configure the client id, pod label and service account. |
| 2.0.4 | The unused top-level `podAnnotations` was removed from default values. It was not consumed by the workload templates. | Values copied from the top-level example or annotations expected on pods. | Move them into `deployment.podAnnotations` or `statefulset.podAnnotations`; they become effective there. |
| Rollout patch after 2.0.4 (#117) | Explicit strategy zero is retained. RollingUpdate with both `maxSurge` and `maxUnavailable` at `0` or `"0%"` now fails rendering; numeric `0` / `0` previously became `1` / `0`. | Deployments setting zero surge, especially zero/zero combinations. | Choose a valid pair, such as `0` / `1` or `1` / `0`. Plan surge capacity or temporary unavailability accordingly. |
| Rollout patch after 2.0.4 (#117), only when enabled | `autoscaling.omitReplicas: true` removes Deployment `spec.replicas` when HPA is enabled and targets Deployment. | Existing HPA-managed releases enabling the flag. | Plan the first ownership change: Helm/Argo drops the field once and Kubernetes can reset replicas to `1` until HPA scales up. Keep the default `false` during the version migration. |
| Rollout patch after 2.0.4 (#117) | Implicit HTTPRoute/Ingress backends with multiple ports now prefer a port named `http`, otherwise the alphabetically first port name. Previous selection used random map-key order. | Apps with multiple ports and no explicit route/ingress backend port. | Set an explicit backend `port`, or name the main port `http`. Review the selected Service port in both renders. |
| Patch after 2.0.4 (#119) | BackendTLSPolicy now uses the release namespace instead of `httpRoute.namespace`, is included by `drunk-lib.all`, and emits validation hostname once. | TLS routes using a different policy namespace; library consumers of the aggregate; consumers relying on the duplicate hostname's last value. | Place the policy and CA references with the target Service; review removal of the old policy. Remove a separate policy include beside `drunk-lib.all`. Set `backendTlsPolicy.hostname` or `httpRoute.tlsValidation.hostname` explicitly when required; check the `https` default Service port name. See [TLS settings](drunk-app.md#backendtlspolicy). |
| Patch after 2.0.4 (#120) | Jobs and CronJobs now inherit app `nodeSelector`, `tolerations` and only `affinity.nodeAffinity`. | Batch entries that previously ran without the app's node placement restrictions. | Review eligible nodes. Each per-entry key replaces the full app value; set `nodeSelector: {}`, `tolerations: []` and `affinity: {}` to disable each inheritance independently. App pod affinity, pod anti-affinity, the preset and topology spread are never inherited. See [batch placement](drunk-app.md#job-and-cronjob-pod-options). |
| Patch after 2.0.4 (#120) | A volume with more than one of `configMap`, `secret`, `projected`, `csi`, `emptyDir` now fails rendering, even if a key is empty or false. | Entries that combined source keys while older templates ignored all but `emptyDir`. | Keep exactly one source key per entry; remove unused keys entirely. `emptyDir: {}` still creates and mounts its PVC; use `emptyDir: true` for a plain emptyDir. |
| Patch after 2.0.4 (#120) | `configMap`, `secret`, `projected` and `csi` volume keys now select those pod sources and suppress PVC creation; non-empty emptyDir maps now pass through settings without a PVC. | Values containing formerly ignored volume source maps, or consumers introducing emptyDir settings. | Inspect PVC removals and mounts before syncing. Confirm existing source objects/CSI driver and tune `medium`/`sizeLimit`. Preserve PVC settings on entries intended for persistent storage. See [volume sources](drunk-app.md#configmap-secret-projected-and-csi-volumes). |
| Patch after 2.0.4 (#120) | `env` objects containing `valueFrom` now render a source instead of a quoted literal map. | Consumers whose env objects contain `valueFrom`; applies to all four workloads and Deployment/StatefulSet init containers. | Check each field, resource, Secret or ConfigMap reference. Use a scalar for an intentional literal value. See [environment sources](drunk-app.md#valuefrom). |
| Patch after 2.0.4 (#120) | Workload `labels`, `annotations` and `priorityClassName`, plus per-entry batch metadata, scheduling and `resources`, now take effect. Standard workload label collisions fail rendering. | Values carrying these previously ignored keys; batch resource overrides can remove app limits. | Remove unwanted keys. Use `podLabels`/`podAnnotations` for pod metadata and custom object label keys outside `app.labels`. Create the PriorityClass. Review full batch override maps; `resources: {}` clears inherited resources. |
| Patch after 2.0.4 (#119, #121), only when configured | NGINX policy flags, HTTPRoute response header filters, and HPA behavior/metrics now produce their configured output. | Values already carrying these previously ignored settings, or consumers enabling them during migration. | Leave them absent during the initial version change unless intentional. Confirm NGF/Gateway support and metrics adapters; additional HPA metrics append after CPU and memory. Follow the feature links below. |

### Defaults that now apply

The malformed 1.x app defaults also remained in the 2.0.0 archive. Tags 2.0.0–2.0.2 precede the correction; 2.0.3 contains it. An override values file was still read, so capture the values you actually supplied rather than assuming those releases deployed nothing.

With the corrected defaults and no override, a consumer now gets:

- An enabled Deployment with **1 replica**, container port `http: 8080`, and default RollingUpdate `maxSurge: 1` / `maxUnavailable: 0`.
- A **ClusterIP Service** exposing port `80` to the single HTTP container port.
- A writable `tmp` **emptyDir** mounted at `/tmp`.
- Pod user, group and filesystem group **10000**; a read-only root filesystem; all Linux capabilities dropped; privilege escalation disabled; non-root execution required.
- CPU requests and limits **100m**; memory requests and limits **128Mi**.
- No dedicated ServiceAccount and no Ingress by default. `global` is empty: consumers must still supply the application image and tag.

A library-only consumer inherits its own chart's defaults, not these `drunk-app` defaults.

## 2.0.4

`secretProvider.provider.useVMManagedIdentity: false` now takes effect. If the release actually needs VM managed identity, change it to `true` or remove the key. For workload identity, follow the runnable [app guide example](drunk-app.md#workload-identity), which sets the pod label, ServiceAccount client-id annotation and SecretProviderClass `clientID` together.

2.0.4 also adds `deployment.podLabels`, `statefulset.podLabels` and `secretProvider.provider.clientID`. Custom pod labels render as text; the selector keys `app.kubernetes.io/name` and `app.kubernetes.io/instance` are refused. Top-level `podAnnotations` was removed from defaults; use the workload-level annotation maps.

## Step-by-step migration

### 1. Move the dependency pin to 2.x

Record the existing chart version, release name, namespace and supplied values in your deployment repository. Preserve a copy of the old values for the comparison in step 3.

For a parent chart such as `mx-apps`, move each `drunk-app` or direct `drunk-lib` dependency to the verified published 2.x version containing #117, #119, #120 and #121. Preserve dependency aliases and apply the remaining steps under each alias. Do not leave the old 1.x pin in `Chart.lock` or a vendored archive: regenerate dependencies after editing `Chart.yaml`.

A dependency constraint that excludes pre-rollout versions is:

```yaml
# Chart.yaml excerpt: use drunk-lib instead for a direct library consumer.
dependencies:
  - name: drunk-app
    version: ">=2.0.5 <3.0.0"
    repository: oci://ghcr.io/baoduy
```

Once that version is published, run from the parent chart directory:

```bash
helm dependency update .
helm dependency list .
```

For an Argo CD Helm source, update its chart `targetRevision` instead. Review and commit the dependency lock/archive changes in your deployment repository before comparing manifests.

### 2. Rename values and make defaults explicit

This before/after patch corrects old copied values. For a StatefulSet, put annotations under `statefulset` instead of `deployment`.

```diff
 serviceAccount:
-  create: true
+  enabled: true
 volumes:
-  - name: tmp
+  tmp:
     mountPath: /tmp
     emptyDir: true
-podAnnotations:
-  prometheus.io/scrape: "true"
+deployment:
+  podAnnotations:
+    prometheus.io/scrape: "true"
```

The resulting values fragment is:

```yaml
serviceAccount:
  enabled: true
volumes:
  tmp:
    mountPath: /tmp
    emptyDir: true
deployment:
  podAnnotations:
    prometheus.io/scrape: "true"
```

Merge into any existing `deployment` map; do not duplicate that YAML key. Set the image explicitly, retain the existing probes and scaling settings, and choose explicit resource/security overrides where the newly active defaults differ from your release. For a Job-only app, disable Deployment explicitly.

Check Azure VM identity against the 2.0.4 note. For multi-port HTTPRoute, set `httpRoute.rules[].backendRefs[].port`; for Ingress, set `ingress.hosts[].port`. Those are **Service ports**, not necessarily container ports. The helper still prefers `service.ports` over `deployment.ports`; a single port defaults to backend `80`, and no ports to `8080`.

### 3. Render before and after, then diff

Render the actual old chart and supplied values, then the target chart and migrated values. Use the same release name, namespace and Kubernetes version for both. For a parent chart, use preserved old and updated parent-chart directories, so aliases are included.

For the repository's standalone 1.x archive and merged 2.x checkout, this local comparison avoids depending on a not-yet-published package:

```bash
helm template my-app ./drunk-app/drunk-app-1.3.9.tgz \
  --namespace apps --kube-version 1.31.0 -f values-old.yaml > before.yaml
helm template my-app ./drunk-app \
  --namespace apps --kube-version 1.31.0 -f values-new.yaml > after.yaml
diff -u before.yaml after.yaml
```

Expected differences include the corrected defaults and any intentional renamed values. Review images, replicas, strategy, pod security, resources, Service/route ports, ServiceAccounts, labels, probes, volume mounts and PVC names. Jobs have a random name suffix, so investigate that expected diff separately. A successful Helm render validates template/YAML generation, not the app's behavior or the cluster's API admission.

### 4. Run Argo CD diff before the first sync

After making the target revision available to Argo CD, compare the live application with that pending revision before syncing:

```bash
argocd app diff mx-apps --revision MIGRATION_COMMIT --refresh
```

Replace `mx-apps` and `MIGRATION_COMMIT` with the application name and revision for your configured source. For a Helm chart source, the revision is a chart version; for a Git source, use the commit. Multi-source apps need the matching source positions/revisions. The [Argo CD command reference](https://argo-cd.readthedocs.io/en/stable/user-guide/commands/argocd_app_diff/) documents those options and the nonzero exit status when differences exist.

Review the diff before the first sync. Sync the version migration with the new rollout-safety settings still absent, then check that the application's pods and traffic are healthy.

### 5. Turn on rollout-safety keys one at a time

In separate reviewed values changes and syncs:

1. Add probe maps and startup probes; verify the chosen endpoints and ports.
2. Add a termination budget and preStop sleep or a raw lifecycle hook; check that graceful shutdown finishes within the budget.
3. Add ready/progress/revision controls and a valid rollout strategy; verify a rollout using the application's traffic checks.
4. Add spreading; inspect placement and Pending pods before choosing hard anti-affinity.
5. Add a PDB that permits the intended voluntary drain at the minimum replica count.
6. If wanted, transfer Deployment replica ownership to HPA in a planned sync, as described below.

Use Kubernetes **1.30+** for native preStop sleep with `PodLifecycleSleepAction` enabled (beta/default-on in 1.30), and **1.31+** for stable `unhealthyPodEvictionPolicy`. The combined examples therefore target 1.31+. See the [lifecycle update](https://kubernetes.io/blog/2025/05/14/kubernetes-v1-33-updates-to-container-lifecycle/) and [PDB guidance](https://kubernetes.io/docs/tasks/run-application/configure-pdb/#unhealthy-pod-eviction-policy).

## HPA replica ownership

`autoscaling.omitReplicas` defaults to `false`. It removes Deployment `spec.replicas` only when `autoscaling.enabled: true` and the HPA target kind is `Deployment` (including the default target). It never removes StatefulSet replicas or HPA `minReplicas`.

For an existing release already managed by HPA, the first Helm/Argo update removing `replicas` can reset the Deployment to **1** until the HPA reconciles. Do not combine this ownership change with the first 1.x → 2.x migration. Ensure that the HPA and metrics API work, plan the first sync for that capacity dip, then verify that replicas return to the desired level. Setting HPA `minReplicas` does not eliminate the one-time defaulting window. Kubernetes describes replica-field ownership in its [HPA migration guidance](https://kubernetes.io/docs/concepts/workloads/autoscaling/horizontal-pod-autoscale/#migrating-deployments-and-statefulsets-to-horizontal-autoscaling).

## New opt-in features

- **Probe maps and startup:** `deployment` / `statefulset.liveness`, `readiness`, `startup` accept path strings or raw probe maps. [App probes](drunk-app.md#probes-and-graceful-shutdown) · [Library keys](../drunk-lib/README.md#optional-rollout-keys).
- **Graceful shutdown:** workload `terminationGracePeriodSeconds`, `preStopSleepSeconds` and raw `lifecycle`. Raw lifecycle overrides sleep, including `{}`; an explicitly supplied sleep must still be shorter than an explicitly supplied grace period. [App shutdown](drunk-app.md#probes-and-graceful-shutdown) · [Library keys](../drunk-lib/README.md#optional-rollout-keys).
- **Rollout controls:** `deployment.minReadySeconds`, `progressDeadlineSeconds`, `revisionHistoryLimit` and `statefulset.minReadySeconds`; presence checks retain zero. Strategy integers and percentages retain explicit zero; RollingUpdate zero/zero fails. [App strategy](drunk-app.md#rolling-update-strategy) · [Library keys](../drunk-lib/README.md#optional-rollout-keys).
- **HPA replica ownership:** opt-in `autoscaling.omitReplicas`. [App autoscaling](drunk-app.md#autoscaling) · [Library migration note](../drunk-lib/README.md#optional-rollout-keys).
- **Spreading:** top-level `podAntiAffinityPreset` (`""`, `soft`, `hard`; unknown values fail) and `topologySpreadConstraints` with injected selectors only when omitted. [App spreading](drunk-app.md#spreading-replicas) · [Library keys](../drunk-lib/README.md#optional-rollout-keys).
- **PDB:** `podDisruptionBudget.enabled`, exactly one of `minAvailable` / `maxUnavailable`, and `unhealthyPodEvictionPolicy`. [App PDB](drunk-app.md#poddisruptionbudget) · [Library keys](../drunk-lib/README.md#optional-rollout-keys).
- **NGINX upstream policy:** `nginxUpstreamSettingsPolicy.enabled`, `keepAlive` (`connections`, `requests`, `time`, `timeout`), `loadBalancingMethod`, `hashMethodKey`, `zoneSize`; targets this Service. [App upstream policy](drunk-app.md#nginxupstreamsettingspolicy) · [Library policies](../drunk-lib/README.md#nginx-gateway-fabric-policies).
- **NGINX client policy:** `nginxClientSettingsPolicy.enabled`, `body` (`maxSize`, `timeout`) and `keepAlive` (`requests`, `time`, `timeout.server`, `timeout.header`); targets this HTTPRoute. Both policies default off and require NGF policy CRDs/controller. [App client policy](drunk-app.md#nginxclientsettingspolicy) · [Library policies](../drunk-lib/README.md#nginx-gateway-fabric-policies).
- **Response headers:** HTTPRoute rule `ResponseHeaderModifier` filters with `responseHeaderModifier.set`, `add`, `remove`. [App headers](drunk-app.md#response-headers) · [Library headers](../drunk-lib/README.md#response-headers).
- **Backend TLS overrides:** `backendTlsPolicy.sectionName`, `hostname`, `options`, with defaults `https`, validation/first-route hostname and `{tls-verify-depth: "1"}`. Enabled HTTPRoute plus non-empty `tlsValidation` triggers the policy. [App TLS](drunk-app.md#backendtlspolicy) · [Library TLS](../drunk-lib/README.md#backend-tls-validation).
- **Environment sources:** `env.<name>.valueFrom` accepts `fieldRef`, `secretKeyRef`, `configMapKeyRef` or `resourceFieldRef`; plain values remain strings. [App env](drunk-app.md#valuefrom) · [Library sources](../drunk-lib/README.md#environment-sources-and-volume-types).
- **Volume sources and emptyDir settings:** `volumes.<name>.configMap`, `secret`, `projected`, `csi`, or non-empty `emptyDir` with `medium`/`sizeLimit`; retain `mountPath`, `subPath` and `readOnly`. [App volumes](drunk-app.md#configmap-secret-projected-and-csi-volumes) · [Library sources](../drunk-lib/README.md#environment-sources-and-volume-types).
- **Object metadata and priority:** `deployment` / `statefulset.labels`, `annotations`, `priorityClassName`; metadata is separate from pod metadata. [App object settings](drunk-app.md#object-metadata-and-priority) · [Library object settings](../drunk-lib/README.md#workload-object-metadata-and-priority).
- **Batch pod overrides:** `jobs[]` / `cronJobs[].nodeSelector`, `tolerations`, `affinity`, `podLabels`, `podAnnotations`, `resources`. Overrides are opt-in; inheritance of app node placement is the default change described above. [App batch settings](drunk-app.md#job-and-cronjob-pod-options) · [Library batch settings](../drunk-lib/README.md#job-and-cronjob-pod-options).
- **HPA behavior and metrics:** `autoscaling.behavior` and `autoscaling.metrics` pass complete specs through; metrics follow CPU and memory in supplied order. Custom/external metrics require the appropriate API adapter. [App HPA settings](drunk-app.md#behavior-and-metrics) · [Library HPA settings](../drunk-lib/README.md#optional-hpa-behavior-and-metrics).

Start with the combined [app example](drunk-app.md#zero-downtime-deployment) or [library example](drunk-lib.md#zero-downtime-deployment), which agree with the [library README example](../drunk-lib/README.md#example--zero-downtime-deployment). Tune them to the application; zero downtime depends on readiness, shutdown behavior, cluster capacity and traffic routing.

## Verification sources

The change table was checked against these repository artifacts and history:

- Archived `drunk-app-1.3.9.tgz` / `drunk-lib-1.3.4.tgz`: old defaults, map-based volume handling, `serviceAccount.enabled`, VM identity defaulting and strategy zero handling.
- Commit [`4e583b3`](https://github.com/baoduy/drunk.charts/commit/4e583b3a12adafec80e707ac12791132a5a5ab0f) and [`1b0512d`](https://github.com/baoduy/drunk.charts/commit/1b0512dc3bcb7bd5ba0555922f77c829041253a8): defaults and copied-value corrections; included in tag `v2.0.3`.
- Commit [`cac7d6d`](https://github.com/baoduy/drunk.charts/commit/cac7d6d1ed530444e5a7e4a9a5fac89cf9730e87): VM identity, pod labels, client id and top-level annotation removal; included in tag `v2.0.4`.
- [PR #117](https://github.com/baoduy/drunk.charts/pull/117): `drunk-lib.probes`, `drunk-lib.lifecycle`, `drunk-lib.podScheduling`, `drunk-lib.pdb`, Deployment replica omission/strategy, and `drunk.utils.ingressPort`.
- [PR #119](https://github.com/baoduy/drunk.charts/pull/119): NGINX policy templates, HTTPRoute response filters and BackendTLSPolicy namespace, aggregate inclusion and overrides.
- [PR #120](https://github.com/baoduy/drunk.charts/pull/120): `drunk-lib.envValue`, `volumeType`/`volumeSource`, object metadata/priority, and `jobScheduling`/`jobPodMetadata` with per-entry resources. The volume-source helper rejects multiple keys and preserves empty-map emptyDir PVCs.
- [PR #121](https://github.com/baoduy/drunk.charts/pull/121): `drunk-lib.hpa` passes through behavior and appends full metric specs after CPU and memory. Merged `dev` at commit [`2da1b3a`](https://github.com/baoduy/drunk.charts/commit/2da1b3a3a294adb1f0a975aa0c0625b0b9eea624) contains all four PRs.
- The [publish workflow](../.github/workflows/publish-oci.yml) derives package versions from tags and synchronizes chart/dependency metadata during publishing.
