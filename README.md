# drunk.charts

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/drunk-app)](https://artifacthub.io/packages/search?repo=drunk-app)

A collection of production-ready Helm charts for deploying applications to Kubernetes.

## Charts

- **drunk-app** — main application chart
  - doc: [README.md](./drunk-app/README.md) · [Full docs](./docs/README.md)
  - repo url: [https://baoduy.github.io/drunk.charts/drunk-app](https://baoduy.github.io/drunk.charts/drunk-app)
- **drunk-lib** — reusable library chart (dependency of drunk-app)
  - doc: [README.md](./drunk-lib/README.md)
  - repo url: [https://baoduy.github.io/drunk.charts/drunk-lib](https://baoduy.github.io/drunk.charts/drunk-lib)
- **drunk-nginx-gateway** — Nginx gateway chart
  - repo url: [https://baoduy.github.io/drunk.charts/drunk-nginx-gateway](https://baoduy.github.io/drunk.charts/drunk-nginx-gateway)
- **drunk-traefik-gateway** — Traefik gateway chart
  - repo url: [https://baoduy.github.io/drunk.charts/drunk-traefik-gateway](https://baoduy.github.io/drunk.charts/drunk-traefik-gateway)
- **drunk-squid-basic-auth** — Squid proxy with basic auth
  - repo url: [https://baoduy.github.io/drunk.charts/drunk-squid-basic-auth](https://baoduy.github.io/drunk.charts/drunk-squid-basic-auth)

## Quick Start

```bash
helm repo add drunk-charts https://baoduy.github.io/drunk.charts/drunk-app
helm repo update
helm install my-app drunk-charts/drunk-app -f my-values.yaml
```

## Claude Code Plugin

An AI assistant plugin is available to help configure `values.yaml` for drunk-app inside Claude Code.

**Install the plugin:**

```bash
claude plugin marketplace add baoduy/drunk.charts --scope project
claude plugin install drunk-app --scope project
```

**Install the SKILL to your local project:**

After installing the plugin, copy the `SKILL.md` file into your project so Claude Code can discover it locally:

```bash
mkdir -p .claude/skills
cp "$(plugin path drunk-app)/skills/drunk-app/SKILL.md" .claude/skills/drunk-app.md
```

Alternatively, you can manually download the skill file:

```bash
mkdir -p .claude/skills
curl -sL https://raw.githubusercontent.com/baoduy/drunk.charts/main/plugins/drunk-app/skills/drunk-app/SKILL.md -o .claude/skills/drunk-app.md
```

> **Note:** The `.claude/skills/` directory must exist in your project root for Claude Code to detect the skill. Commit this file to your repository so all team members benefit from the AI assistant.

Then use `/drunk-app` in any Claude Code session to get contextual help with chart configuration.

## Testing the Helm Charts

Charts are tested with [helm-unittest](https://github.com/helm-unittest/helm-unittest).

**Install the plugin:**

```bash
helm plugin install https://github.com/helm-unittest/helm-unittest.git
```

**Run tests:**

```bash
helm unittest -f 'tests/*.yaml' ./drunk-app
helm unittest -f 'tests/*.yaml' ./drunk-lib
```

Or use the provided test scripts:

```bash
./drunk-app/test.sh
./drunk-lib/verify.sh
```
