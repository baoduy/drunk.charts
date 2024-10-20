# Drunk App Helm Chart

The Drunk App Helm Chart provides a robust and flexible framework for deploying the App on Kubernetes clusters. This chart allows users to easily manage, configure, and scale applications using the Helm package manager, streamlining the deployment process and facilitating the integration of essential application components such as container images, environment variables, secrets, and persistent storage.

## Key Features

- **Simplified Deployment**: Quickly deploy complex applications with customizable configurations tailored to specific environments using Helm.
- **Flexible Configuration**: Fine-tune application settings including image repositories, environment variables, secrets, and more through an organized set of parameters.

- **Automatic Scaling**: Enable horizontal pod autoscaling to dynamically adjust the number of running pods based on resource utilization.

- **Integrated Security**: Leverage Kubernetes secrets and TLS configurations to securely manage sensitive information and encrypted communications.

- **Job Scheduling**: Streamline recurring tasks with CronJobs and batch processing workflows with Jobs, integrated directly into your Kubernetes environment.

- **Comprehensive Ingress Management**: Configure external access to your application using Kubernetes ingress resources, complete with TLS support and multiple host routing options.

Perfectly suited for both development and production environments, this Helm chart ensures that deploying the Drunk Test App is seamless, repeatable, and efficient while maintaining a high degree of customization. Whether you're setting up a simple app or managing a complex microservices architecture.

## Installation

To install the chart with the release name `drunk-app`, follow these steps:

1. Add the Helm repository (if needed):

   ```bash
   helm repo add drunk-app https://baoduy.github.io/drunk.charts/drunk-app
   helm repo update
   ```

2. Install the chart:
   ```bash
   helm install drunk-app drunk-app/drunk-app
   ```

### General

These parameters are overarching settings that impact the entire deployment.

| Parameter      | Description                           | Default          |
| -------------- | ------------------------------------- | ---------------- |
| `nameOverride` | Overrides the name of the application | `drunk-test-app` |

### Image Credentials

Credentials for accessing the Docker registry.

| Parameter                   | Description                        | Default                  |
| --------------------------- | ---------------------------------- | ------------------------ |
| `imageCredentials.name`     | Name of the Docker registry secret | `drunkcoding-acr-secret` |
| `imageCredentials.registry` | URL of the Docker registry         | `drunkcoding.net`        |
| `imageCredentials.username` | Username for Docker registry       | `drunk`                  |
| `imageCredentials.password` | Password for Docker registry       | `coding`                 |

### Global

Settings applicable to all deployed containers and resources.

| Parameter                      | Description                                  | Default                               |
| ------------------------------ | -------------------------------------------- | ------------------------------------- |
| `global.image`                 | Docker image to use                          | `baoduy2412/astro-blog`               |
| `global.tag`                   | Docker image tag                             | `latest`                              |
| `global.imagePullPolicy`       | Image pull policy                            | `IfNotPresent`                        |
| `global.storageClassName`      | Default storage class for persistent volumes | `111`                                 |
| `global.imagePullSecret`       | Secret for pulling images                    | `drunkcoding-acr-secret`              |
| `global.initContainer.image`   | Initial setup container image                | `baoduy2412/astro-blog`               |
| `global.initContainer.command` | Command for init container                   | `['sh', '-c', 'echo Init complete;']` |

### Environment Variables

Variables set via ConfigMap for application configuration.

| Parameter  | Description            | Default       |
| ---------- | ---------------------- | ------------- |
| `env.env1` | Environment variable 1 | `hello`       |
| `env.env2` | Environment variable 2 | `drunkcoding` |

### ConfigMap

Configuration through Kubernetes ConfigMap.

| Parameter         | Description                              | Default                  |
| ----------------- | ---------------------------------------- | ------------------------ |
| `configMap.hello` | Sample ConfigMap entry                   | `1`                      |
| `configFrom`      | Additional configs from external sources | `[name_of_other_config]` |

### Secrets

Sensitive information such as passwords or connection strings.

| Parameter                  | Description                              | Default                  |
| -------------------------- | ---------------------------------------- | ------------------------ |
| `secrets.connectionString` | Example connection string                | `"ABC"`                  |
| `secretFrom`               | Additional secrets from external sources | `[name_of_other_secret]` |

### TLS Secrets

Configuration for TLS certificates.

| Parameter                       | Description                      | Default                 |
| ------------------------------- | -------------------------------- | ----------------------- |
| `tlsSecrets.cloudflare.enabled` | Whether to enable Cloudflare TLS | `true`                  |
| `tlsSecrets.cloudflare.crt`     | TLS certificate                  | (truncated certificate) |
| `tlsSecrets.cloudflare.key`     | TLS key                          | (truncated key)         |

### Deployment

Deployment-related configurations for the application.

| Parameter                   | Description                                | Default                |
| --------------------------- | ------------------------------------------ | ---------------------- |
| `deployment.enabled`        | Enable or disable deployment               | `true`                 |
| `deployment.ports.http`     | HTTP port                                  | `8080`                 |
| `deployment.ports.tcp`      | TCP port                                   | `9090`                 |
| `deployment.liveness`       | Liveness endpoint                          | `/healthz`             |
| `deployment.args`           | Command-line arguments for the application | (multiple args)        |
| `deployment.podAnnotations` | Annotations for the pod                    | `testMe: drunk-coding` |

### CronJobs

Scheduled jobs run at regular intervals.

| Parameter                  | Description                     | Default                        |
| -------------------------- | ------------------------------- | ------------------------------ |
| `cronJobs[].name`          | CronJob name                    | `drunk-cjob-1`, `drunk-cjob-2` |
| `cronJobs[].schedule`      | CronJob schedule format         | `"* 0 * * *"`                  |
| `cronJobs[].args`          | Arguments passed to the CronJob | `hello`                        |
| `cronJobs[].command`       | Commands for the CronJob        | `hello-1`, `hello-2`           |
| `cronJobs[].restartPolicy` | Restart policy (if set)         | `Always`                       |

### Jobs

One-time tasks executed as batch jobs.

| Parameter              | Description                 | Default                      |
| ---------------------- | --------------------------- | ---------------------------- |
| `jobs[].name`          | Job name                    | `drunk-job-1`, `drunk-job-2` |
| `jobs[].args`          | Arguments passed to the Job | `hello`                      |
| `jobs[].command`       | Commands for the Job        | `hello-1`, `hello-2`         |
| `jobs[].restartPolicy` | Restart policy (if set)     | `Always`                     |

### Volumes

Persistent and ephemeral storage settings.

| Parameter                           | Description                             | Default         |
| ----------------------------------- | --------------------------------------- | --------------- |
| `volumes.data-vol.size`             | Size of the volume                      | `2Gi`           |
| `volumes.data-vol.storageClassName` | Storage class for the volume            | `abc`           |
| `volumes.data-vol.accessMode`       | Access mode for the volume              | `ReadWriteOnce` |
| `volumes.data-vol.mountPath`        | Mount path for the volume               | `/data`         |
| `volumes.data-vol.subPath`          | Subpath within the volume               | `abc.dev`       |
| `volumes.data-vol.readOnly`         | Whether the volume is read-only         | `false`         |
| `volumes.other-vol`                 | Additional volume similar to `data-vol` | (similar setup) |
| `volumes.tmp.mountPath`             | Mount path for temporary storage        | `/tmp`          |
| `volumes.tmp.emptyDir`              | Use EmptyDir for `/tmp` storage         | `true`          |

### Ingress

Settings for managing external access to the application.

| Parameter           | Description               | Default                                                                                            |
| ------------------- | ------------------------- | -------------------------------------------------------------------------------------------------- |
| `ingress.enabled`   | Enable ingress            | `true`                                                                                             |
| `ingress.className` | Class name for ingress    | `nginx`                                                                                            |
| `ingress.hosts`     | Hosts for ingress routing | `[{"host": "hello.drunkcoding.net", "port": 8080}, {"host": "api.drunkcoding.net", "port": 9090}]` |
| `ingress.tls`       | TLS configuration         | `chart-example-tls`                                                                                |

### Usage

Please refer the file [`values.test.yaml`](values.test.yaml) for details.

## Contributing

Contributions are welcome!. For any questions or issues, please open an issue in the project's GitHub repository.

## License

This project is licensed under the MIT License.

### Thanks

[Steven Hoang](https://drunkcoding.net)
