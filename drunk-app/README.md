# Drunk App Helm Chart Template

This Helm chart deploys the Drunk Test App on a [Kubernetes](http://kubernetes.io) cluster using the [Helm](https://helm.sh) package manager.

## Prerequisites

- Kubernetes 1.12+
- Helm 3.0+

## Installing the Chart

To install the chart with the release name `drunk-app`:

```bash
$ helm install drunk-app https://baoduy.github.io/hbd.charts/drunk-app/
```

The command deploys Drunk Test App on the Kubernetes cluster in the default configuration. The [configuration](#configuration) section lists the parameters that can be configured during installation.

## Uninstalling the Chart

To uninstall/delete the `drunk-app` deployment:

```bash
$ helm delete drunk-app
```

The command removes all the Kubernetes components associated with the chart and deletes the release.

## Configuration

The following table lists the configurable parameters of the Drunk Test App chart and their default values.

| Parameter                         | Description                                      | Default                        |
|-----------------------------------|--------------------------------------------------|--------------------------------|
| `nameOverride`                    | Override the app name                            | `drunk-test-app`               |
| `global.image`                    | Global image for the application                 | `baoduy2412/astro-blog`        |
| `global.tag`                      | Global image tag                                 | `latest`                       |
| `global.imagePullPolicy`          | Image pull policy                                | `IfNotPresent`                 |
| `global.port`                     | Application port                                 | `8080`                         |
| `global.replicaCount`             | Number of replicas                               | `1`                            |
| `global.liveness`                 | Liveness probe endpoint                          | `/healthz`                     |
| `configMap.hello`                 | Sample configMap entry                           | `1`                            |
| `secrets.connectionString`        | Connection string (use external secret)          | `ABC`                          |
| `deploymentEnabled`               | Enable deployment of the pod                     | `true`                         |
| `cronJobs`                        | Configuration for cron jobs                      | See values.yaml                |
| `jobs`                            | Configuration for jobs                           | See values.yaml                |
| `serviceAccount.create`           | Specifies whether a service account should be created | `true`                     |
| `podSecurityContext`              | Security context for the pod                     | `{fsGroup: 10000, runAsUser: 10000, runAsGroup: 10000}` |
| `securityContext`                 | Security settings for containers in the pod      | See values.yaml                |
| `service.type`                    | Kubernetes Service type                          | `ClusterIP`                    |
| `ingress.enabled`                 | Enable ingress controller resource               | `true`                         |
| `resources`                       | CPU/Memory resource requests/limits              | `{}`                           |
| `autoscaling.enabled`             | Enable horizontal pod autoscaler                 | `false`                        |

## Customizing the Chart Before Installing

To configure the chart with custom values:



Specify each parameter using the `--set key=value[,key=value]` argument to `helm install`. For example,

```bash
$ helm install drunk-app --set global.tag=latest https://baoduy.github.io/hbd.charts/drunk-app/
```

Alternatively, a YAML file that specifies the values for the parameters can be provided while installing the chart. For example,

```bash
$ helm install drunk-app -f values.yaml https://baoduy.github.io/hbd.charts/drunk-app/
```

> **Tip**: You can use the default [values.yaml](values.yaml)

## CronJobs

The chart includes support for scheduling CronJobs. Here are the configurable parameters:

| Parameter                | Description             | Default        |
| ------------------------ | ----------------------- | -------------- |
| `cronJobs[].name`        | Name of the CronJob     | `` |
| `cronJobs[].schedule`    | Schedule of the CronJob | ``    |
| `cronJobs[].command`     | Command of the CronJob  | ``        |

## Jobs

The chart also includes support for running Jobs. Here are the configurable parameters:

| Parameter                | Description             | Default        |
| ------------------------ | ----------------------- | -------------- |
| `jobs[].name`            | Name of the Job         | ``  |
| `jobs[].command`         | Command of the Job      | ``        |

## Service Account

The chart creates a service account for the application. Here are the configurable parameters:

| Parameter                | Description             | Default        |
| ------------------------ | ----------------------- | -------------- |
| `serviceAccount.create`  | Whether to create a service account | `true` |
| `serviceAccount.annotations` | Annotations to add to the service account | `{}` |

## Ingress

The chart configures Ingress for the application. Here are the configurable parameters:

| Parameter                | Description             | Default        |
| ------------------------ | ----------------------- | -------------- |
| `ingress.enabled`        | Whether to enable ingress | `false` |
| `ingress.annotations`    | Annotations to add to the ingress | `{kubernetes.io/ingress.class: nginx}` |
| `ingress.hosts`          | List of hosts for ingress | `[{host: hello.drunkcoding.net}]` |
| `ingress.tls`            | TLS settings for ingress | `chart-example-tls` |

## Resources

The chart allows you to specify resource requests and limits for the application. Here are the configurable parameters:

| Parameter                | Description             | Default        |
| ------------------------ | ----------------------- | -------------- |
| `resources.limits.cpu`   | CPU limit | `100m` |
| `resources.limits.memory`| Memory limit | `128Mi` |
| `resources.requests.cpu` | CPU request | `100m` |
| `resources.requests.memory` | Memory request | `128Mi` |


# Contribution

## How to run unit test

- install helm unit test plugin refer [here](https://github.com/helm-unittest/helm-unittest) for details:
```shell
helm plugin install https://github.com/helm-unittest/helm-unittest
```

- add test file `$ChartFolder/tests/name_test.yaml`
```yaml
suite: test configMap
templates:
  - configMap.yaml
tests:
  - it: should enabled when
    set:
      configMap:
        key: "hello"
    asserts:
      - isKind:
          of: ConfigMap
      - matchRegex:
          path: metadata.name
          pattern: drunk-app
      - equal:
          path: data.key
          value: "hello"
```

- run unit-tests
```shell
helm unittest ./

### Chart [ drunk-app ] ./

Charts:      1 passed, 1 total
Test Suites: 0 passed, 0 total
Tests:       0 passed, 0 total
Snapshot:    0 passed, 0 total
Time:        1.563896ms
```