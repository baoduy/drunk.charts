# Drunk App Template Helm Chart

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

| Parameter                | Description             | Default        |
| ------------------------ | ----------------------- | -------------- |
| `global.image`           | Drunk Test App image    | `baoduy2412/astro-blog` |
| `global.tag`             | Image tag               | `latest`       |
| `global.imagePullPolicy` | Image pull policy       | `IfNotPresent` |
| `global.port`            | Drunk Test App port     | `8080`         |
| `global.replicaCount`    | Number of nodes         | `1`            |
| `service.type`           | Kubernetes Service type | `ClusterIP`    |
| `resources`              | CPU/Memory resource requests/limits | `{}` |

Specify each parameter using the `--set key=value[,key=value]` argument to `helm install`. For example,

```bash
$ helm install my-release --set global.tag=latest drunk-app/drunk-app
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
| `cronJobs[].name`        | Name of the CronJob     | `drunk-cjob-1` |
| `cronJobs[].schedule`    | Schedule of the CronJob | `* 0 * * *`    |
| `cronJobs[].command`     | Command of the CronJob  | `hello`        |

## Jobs

The chart also includes support for running Jobs. Here are the configurable parameters:

| Parameter                | Description             | Default        |
| ------------------------ | ----------------------- | -------------- |
| `jobs[].name`            | Name of the Job         | `drunk-job-1`  |
| `jobs[].command`         | Command of the Job      | `hello`        |

Please replace `drunk-app/drunk-app` with the actual path to your chart. Also, you might want to update the `Prerequisites` section according to your needs.