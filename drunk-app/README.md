# Drunk App Helm Chart Template

This Helm chart deploys the Drunk Test App on a [Kubernetes](http://kubernetes.io) cluster using the [Helm](https://helm.sh) package manager.

## Prerequisites

- Kubernetes 1.12+
- Helm 3.0+

## Installing the Chart

To install the chart with the release name `my-release`:

```bash
$ helm install my-release path_to_chart/drunk-test-app
```

The command deploys Drunk Test App on the Kubernetes cluster in the default configuration. The [configuration](#configuration) section lists the parameters that can be configured during installation.

## Uninstalling the Chart

To uninstall/delete the `my-release` deployment:

```bash
$ helm delete my-release
```

The command removes all the Kubernetes components associated with the chart and deletes the release.

## Configuration

The following table lists the configurable parameters of the Drunk Test App chart and their default values.

| Parameter                | Description             | Default     |
| ------------------------ | ----------------------- |-------------|
| `global.image`           | Drunk Test App image    | ``          |
| `global.tag`             | Image tag               | `latest`    |
| `global.imagePullPolicy` | Image pull policy       | `Always`    |
| `global.port`            | Drunk Test App port     | `8080`      |
| `global.replicaCount`    | Number of nodes         | `1`         |
| `service.type`           | Kubernetes Service type | `ClusterIP` |
| `resources`              | CPU/Memory resource requests/limits | `{}`        |

Specify each parameter using the `--set key=value[,key=value]` argument to `helm install`. For example,

```bash
$ helm install my-release --set global.tag=latest path_to_chart/drunk-test-app
```

Alternatively, a YAML file that specifies the values for the parameters can be provided while installing the chart. For example,

```bash
$ helm install my-release -f values.yaml path_to_chart/drunk-test-app
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