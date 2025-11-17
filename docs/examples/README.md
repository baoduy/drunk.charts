# Configuration Examples

This directory contains real-world configuration examples for the drunk-app Helm chart. Each example demonstrates specific use cases and deployment patterns.

## Example Categories

### Basic Deployments
- **[Simple Web App](./simple-web-app.yaml)** - Basic web application deployment
- **[API Service](./api-service.yaml)** - RESTful API service with database
- **[Gateway API](./gateway-api.yaml)** - Modern routing with Kubernetes Gateway API
- **[Static Website](./static-website.yaml)** - Static website with CDN

### Advanced Configurations
- **[Microservice](./microservice.yaml)** - Microservice with full observability
- **[Background Worker](./background-worker.yaml)** - Background job processor
- **[Scheduled Jobs](./scheduled-jobs.yaml)** - CronJob-based application

### Production Patterns
- **[High Availability](./high-availability.yaml)** - HA setup with auto-scaling
- **[Multi-Environment](./multi-environment/)** - Dev/staging/production configs
- **[Security Hardened](./security-hardened.yaml)** - Security-focused deployment
- **[Network Policy](./network-policy.yaml)** - Network segmentation and security policies

### Integration Examples
- **[Azure Key Vault](./azure-key-vault.yaml)** - Azure Key Vault secrets integration
- **[Database Integration](./database-integration.yaml)** - App with PostgreSQL database
- **[Monitoring Setup](./monitoring.yaml)** - Prometheus/Grafana integration

## Usage

Each example includes:
- Complete values.yaml configuration
- Explanation of key settings
- Deployment instructions
- Customization notes

### Using an Example

1. Copy the example configuration:
   ```bash
   curl -O https://raw.githubusercontent.com/baoduy/drunk.charts/main/docs/examples/simple-web-app.yaml
   ```

2. Customize for your environment:
   ```bash
   # Edit the configuration
   nano simple-web-app.yaml
   ```

3. Deploy your application:
   ```bash
   helm install my-app drunk-charts/drunk-app -f simple-web-app.yaml
   ```

### Combining Examples

You can combine configurations from multiple examples:

```bash
# Use multiple values files
helm install my-app drunk-charts/drunk-app \
  -f base-config.yaml \
  -f security-hardened.yaml \
  -f monitoring.yaml
```

## Contributing Examples

Have a great configuration you'd like to share? Please contribute!

1. Create a new YAML file with your configuration
2. Add documentation explaining the use case
3. Test the configuration thoroughly
4. Submit a pull request

See our [Development Guide](../development.md) for details on contributing.

---

*These examples are maintained by the community and represent real-world usage patterns.*