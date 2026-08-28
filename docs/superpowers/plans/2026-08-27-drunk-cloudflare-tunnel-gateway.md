# drunk-cloudflare-tunnel-gateway Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a lean Helm application chart `drunk-cloudflare-tunnel-gateway` that vendors the `cloudflare-tunnel-gateway-controller` subchart and renders per-domain Gateway API `Gateway` resources for exposing services through a Cloudflare Tunnel.

**Architecture:** Wrapper chart pattern identical to `drunk-nginx-gateway` but tunnel-flavored: the upstream controller is a Chart.yaml dependency (alias `cloudflareTunnel`) that creates its own GatewayClass; this chart adds only the `domains[]` → `Gateway` templating, `routeAccess` fallback, helpers, NOTES, and build/install/verify scripts. No cert-manager, no LoadBalancer, no GatewayClass template, no in-cluster TLS (Cloudflare terminates TLS at its edge; the tunnel dials outbound).

**Tech Stack:** Helm 3 (repo pins v3.17.3), Gateway API v1.6.1, YAML. No unit-test framework — "tests" are `helm lint` / `helm template` render assertions and `verify.sh`, exactly as in the sibling charts.

**Spec:** `docs/superpowers/specs/2026-08-27-drunk-cloudflare-tunnel-gateway-design.md`

## Global Constraints

- Chart name is exactly `drunk-cloudflare-tunnel-gateway`; chart `version: 1.0.0`.
- Helm template naming prefix stays `gateway.*` for helpers (ported from the nginx chart), matching the sibling chart's `_helpers.tpl` defines.
- Vendored subchart: name `cloudflare-tunnel-gateway-controller`, repository `oci://ghcr.io/lexfrei/charts`, alias `cloudflareTunnel`, version range `1.x.x`, `condition: cloudflareTunnel.enabled`.
- Upstream GatewayClass name is `cloudflare-tunnel`; controllerName is `cf.k8s.lex.la/tunnel-controller`. The subchart creates the GatewayClass — this chart MUST NOT contain a `gatewayclass.yaml` template.
- Required subchart values: `gatewayClassConfig.create: true`, `gatewayClassConfig.tunnelID` (empty default, user-set), `gatewayClassConfig.cloudflareCredentialsSecretRef.name` (Secret key `api-token`), `proxy.tunnelTokenSecretRef.name` (Secret key `tunnel-token`).
- Secrets are referenced by name only — NO credential values anywhere in the chart or example files.
- Gateway API CRDs installed out-of-band (v1.6.1, `standard` channel) via `install.sh`, same two-phase pattern as `drunk-nginx-gateway`.
- Files that must NOT exist in this chart: `templates/gatewayclass.yaml`, `templates/clusterissuer.yaml`, `templates/certificate.yaml`, `values.aks.yaml`, `values.local.yaml`, any cert-manager dependency.
- After any change under the chart dir, the deliverable gate is `bash drunk-cloudflare-tunnel-gateway/verify.sh` exiting 0.
- The vendored subchart hard-`required`s `gatewayClassConfig.tunnelID` (and `cloudflareCredentialsSecretRef.name`) whenever `gatewayClassConfig.create: true`. The shipped `values.yaml` keeps `tunnelID: ""` on purpose (a real deploy must fail loudly until the operator sets it). Therefore EVERY `helm lint` / `helm template` invocation in tests, and `verify.sh`, MUST pass a throwaway tunnelID: `--set cloudflareTunnel.gatewayClassConfig.tunnelID=00000000-0000-0000-0000-000000000000`. `values.example.yaml` sets a non-empty placeholder tunnelID, so renders that use `-f values.example.yaml` need no extra `--set`.
- Local Helm is v4.x; CI pins v3.17.3. Chart must render on both — avoid Helm-4-only template functions.

---

### Task 1: Chart skeleton, dependency, values, helpers

**Files:**
- Create: `drunk-cloudflare-tunnel-gateway/Chart.yaml`
- Create: `drunk-cloudflare-tunnel-gateway/values.yaml`
- Create: `drunk-cloudflare-tunnel-gateway/templates/_helpers.tpl`
- Create: `drunk-cloudflare-tunnel-gateway/.helmignore`
- Create: `drunk-cloudflare-tunnel-gateway/.gitignore`
- Create: `drunk-cloudflare-tunnel-gateway/crds/.gitkeep`

**Interfaces:**
- Produces (used by Tasks 2–4): values keys `namespace`, `gatewayAPI.{version,channel,url}`, `domains[]`, `routeAccess.{mode,namespaces,labelKey,labelValue}`, `cloudflareTunnel.*`; helper defines `gateway.name`, `gateway.fullname`, `gateway.chart`, `gateway.labels`, `gateway.selectorLabels`, `gateway.ns`, `gateway.crdURL`.

- [ ] **Step 1: Write the failing test (render assertion)**

There is no chart yet, so this command must fail. Run it and confirm failure:

```bash
cd /Users/steven/_CODE/GIT/drunk.charts
DUMMY=00000000-0000-0000-0000-000000000000
helm dependency build drunk-cloudflare-tunnel-gateway && \
helm lint drunk-cloudflare-tunnel-gateway --set cloudflareTunnel.gatewayClassConfig.tunnelID=$DUMMY && \
helm template t drunk-cloudflare-tunnel-gateway --set cloudflareTunnel.gatewayClassConfig.tunnelID=$DUMMY | grep -q "kind: GatewayClassConfig"
```

Expected: FAIL (chart directory does not exist).

- [ ] **Step 2: Create `Chart.yaml`**

```yaml
apiVersion: v2
name: drunk-cloudflare-tunnel-gateway
icon: https://drunkcoding.net/assets/logo.png
description: Cloudflare Tunnel Gateway API wrapper — expose services via a Cloudflare Tunnel with no public LoadBalancer, for drunk.charts
type: application
version: 1.0.0
appVersion: "1.0.0"
keywords:
  - gateway-api
  - ingress
  - kubernetes
  - networking
  - cloudflare
  - tunnel
  - zero-trust
home: https://github.com/baoduy/drunk.charts
sources:
  - https://github.com/baoduy/drunk.charts
  - https://github.com/kubernetes-sigs/gateway-api
  - https://github.com/lexfrei/cloudflare-tunnel-gateway-controller
maintainers:
  - name: baoduy
    email: drunkcoding@outlook.com

dependencies:
  - name: cloudflare-tunnel-gateway-controller
    version: 1.x.x
    repository: oci://ghcr.io/lexfrei/charts
    alias: cloudflareTunnel
    condition: cloudflareTunnel.enabled
```

- [ ] **Step 3: Create `values.yaml`**

```yaml
# Default values for drunk-cloudflare-tunnel-gateway
# This chart vendors the cloudflare-tunnel-gateway-controller subchart (alias
# `cloudflareTunnel`) and renders per-domain Gateway API `Gateway` resources.
#
# Network model: the controller's in-process cloudflared data plane dials OUT
# to Cloudflare's edge. There is no LoadBalancer and no in-cluster TLS —
# Cloudflare terminates TLS at its edge — so listeners here are plain HTTP.
#
# YAML anchor note: `gatewayClassName` below DRYs the default at parse time but
# does NOT propagate through `--set`. To override the class name, set each
# consumer path explicitly.

# variables
gatewayClassName: &gatewayClassName "cloudflare-tunnel"

# Target namespace for Gateway resources. Empty → release namespace.
namespace: ""

# Gateway API CRD installation settings (CRDs are applied via install.sh /
# kubectl to bypass Helm's 3MB annotation limit; this block is informational).
gatewayAPI:
  version: "v1.6.1"
  channel: "standard"
  # url: "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/standard-install.yaml"

# Domain-specific Gateways (rendered by templates/domain-gateways.yaml).
domains: []
  # - name: "drunk-dev"
  #   enabled: true
  #   gatewayClassName: "cloudflare-tunnel"
  #   annotations: {}
  #   labels: {}
  #   listeners:
  #     - name: http
  #       protocol: HTTP
  #       port: 80
  #       hostname: "*.drunk.dev"
  #       allowedRoutes:
  #         namespaces:
  #           from: Same

# Route access for auto-generated allowedRoutes when a listener omits it.
#   All  : routes from all namespaces
#   Same : routes only from the Gateway's namespace
#   List : routes from a labeled set of namespaces
routeAccess:
  mode: "Same"
  namespaces: []
  labelKey: "gateway.drunk.charts/access"
  labelValue: ""

# Vendored cloudflare-tunnel-gateway-controller subchart (alias cloudflareTunnel).
# Helm treats a missing condition value as "enabled"; we set it explicitly.
cloudflareTunnel:
  enabled: true
  gatewayClassConfig:
    # Create the GatewayClassConfig CRD + the GatewayClass itself.
    create: true
    # REQUIRED per environment — Cloudflare Tunnel ID (Zero Trust > Networks > Tunnels).
    tunnelID: ""
    # Secret must contain key `api-token` (optional `account-id`, else auto-detected).
    cloudflareCredentialsSecretRef:
      name: "cloudflare-credentials"
    # accountId: ""
  proxy:
    # Secret must contain key `tunnel-token`.
    tunnelTokenSecretRef:
      name: "cloudflare-tunnel-token"
  controller:
    gatewayClassName: *gatewayClassName
    controllerName: "cf.k8s.lex.la/tunnel-controller"
```

- [ ] **Step 4: Create `templates/_helpers.tpl`**

Port the subset actually used here (drop `gateway.serviceAccountName`, which this lean chart has no values for):

```
{{/*
Expand the name of the chart.
*/}}
{{- define "gateway.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "gateway.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "gateway.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "gateway.labels" -}}
helm.sh/chart: {{ include "gateway.chart" . }}
{{ include "gateway.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "gateway.selectorLabels" -}}
app.kubernetes.io/name: {{ include "gateway.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Gateway API CRD URL generator
*/}}
{{- define "gateway.crdURL" -}}
{{- if .Values.gatewayAPI.url }}
{{- .Values.gatewayAPI.url }}
{{- else }}
{{- printf "https://github.com/kubernetes-sigs/gateway-api/releases/download/%s/%s-install.yaml" .Values.gatewayAPI.version .Values.gatewayAPI.channel }}
{{- end }}
{{- end }}

{{/*
Target namespace for namespaced resources (Gateways). Falls back to release namespace if not set.
*/}}
{{- define "gateway.ns" -}}
{{- if .Values.namespace }}{{ .Values.namespace }}{{ else }}{{ .Release.Namespace }}{{ end }}
{{- end }}
```

- [ ] **Step 5: Create `.helmignore`, `.gitignore`, `crds/.gitkeep`**

`.helmignore` — copy verbatim from `drunk-nginx-gateway/.helmignore`.
`.gitignore` — copy verbatim from `drunk-nginx-gateway/.gitignore`.
`crds/.gitkeep`:

```
# Gateway API CRDs are installed separately via kubectl in install.sh
# This avoids Helm's 3MB annotation size limit (Gateway API CRDs > 3MB)
#
# Installation happens in two phases:
#   1. kubectl apply -f https://github.com/.../gateway-api/releases/.../standard-install.yaml
#   2. helm upgrade --install --skip-crds ...
#
# This directory is preserved to maintain Helm chart structure.
```

- [ ] **Step 6: Run the assertion — verify it passes**

```bash
cd /Users/steven/_CODE/GIT/drunk.charts
DUMMY=00000000-0000-0000-0000-000000000000
helm dependency build drunk-cloudflare-tunnel-gateway && \
helm lint drunk-cloudflare-tunnel-gateway --set cloudflareTunnel.gatewayClassConfig.tunnelID=$DUMMY && \
helm template t drunk-cloudflare-tunnel-gateway --set cloudflareTunnel.gatewayClassConfig.tunnelID=$DUMMY | grep -q "kind: GatewayClassConfig"
```
Expected: PASS (dependency resolves from OCI, lint clean, GatewayClassConfig rendered by the subchart).

Also confirm this chart owns no GatewayClass template:
```bash
test ! -f drunk-cloudflare-tunnel-gateway/templates/gatewayclass.yaml && echo "OK: no wrapper GatewayClass"
```

> If `helm dependency build` fails to resolve `1.x.x`, list published tags with `helm show chart oci://ghcr.io/lexfrei/charts/cloudflare-tunnel-gateway-controller` and pin `Chart.yaml`'s dependency `version` to the newest published `1.x` tag, then re-run. Do not change any other field.

- [ ] **Step 7: Commit**

```bash
git add drunk-cloudflare-tunnel-gateway/Chart.yaml drunk-cloudflare-tunnel-gateway/values.yaml \
  drunk-cloudflare-tunnel-gateway/templates/_helpers.tpl drunk-cloudflare-tunnel-gateway/.helmignore \
  drunk-cloudflare-tunnel-gateway/.gitignore drunk-cloudflare-tunnel-gateway/crds/.gitkeep \
  drunk-cloudflare-tunnel-gateway/Chart.lock
git commit -m "feat(cf-tunnel-gateway): chart skeleton, controller subchart, values, helpers"
```

---

### Task 2: Gateway templating + NOTES

**Files:**
- Create: `drunk-cloudflare-tunnel-gateway/templates/domain-gateways.yaml`
- Create: `drunk-cloudflare-tunnel-gateway/templates/NOTES.txt`

**Interfaces:**
- Consumes (from Task 1): `.Values.domains`, `.Values.routeAccess`, `.Values.gatewayAPI`, `.Values.cloudflareTunnel`, helper `gateway.ns`, `gateway.labels`, `gateway.crdURL`.
- Produces: for each enabled `domains[]` entry, a `Gateway` named `<name>-gateway`.

- [ ] **Step 1: Write the failing test (render assertion)**

```bash
cd /Users/steven/_CODE/GIT/drunk.charts
helm template t drunk-cloudflare-tunnel-gateway \
  --set cloudflareTunnel.gatewayClassConfig.tunnelID=00000000-0000-0000-0000-000000000000 \
  --set 'domains[0].name=domain1' \
  --set 'domains[0].enabled=true' \
  --set 'domains[0].gatewayClassName=cloudflare-tunnel' \
  --set 'domains[0].listeners[0].name=http' \
  --set 'domains[0].listeners[0].protocol=HTTP' \
  --set 'domains[0].listeners[0].port=80' \
  --set 'domains[0].listeners[0].hostname=*.example.com' \
  | grep -q "name: domain1-gateway"
```
Expected: FAIL (no `domain-gateways.yaml` yet).

- [ ] **Step 2: Create `templates/domain-gateways.yaml`**

Copy verbatim from `drunk-nginx-gateway/templates/domain-gateways.yaml` — the template is controller-agnostic (iterates `.Values.domains`, renders a `Gateway` per enabled entry with listeners, optional `tls` passthrough, and the `routeAccess`-driven `allowedRoutes` fallback). No edits needed.

- [ ] **Step 3: Create `templates/NOTES.txt`**

```
Thank you for installing {{ .Chart.Name }}!

Chart Version: {{ .Chart.Version }}
App Version: {{ .Chart.AppVersion }}
Release Name: {{ .Release.Name }}
Namespace: {{ .Release.Namespace }}

================================================================================
  GATEWAY API INSTALLATION
================================================================================

Gateway API Version: {{ .Values.gatewayAPI.version }}
Installation Channel: {{ .Values.gatewayAPI.channel }}
CRD URL: {{ include "gateway.crdURL" . }}

To manually install/update the Gateway API CRDs, run:

  kubectl apply -f {{ include "gateway.crdURL" . }}

Verify:

  kubectl get crd | grep gateway.networking.k8s.io

================================================================================
  CLOUDFLARE TUNNEL CONTROLLER
================================================================================

{{- if .Values.cloudflareTunnel.enabled }}

✅ cloudflare-tunnel-gateway-controller subchart is enabled.

It creates the GatewayClass "{{ .Values.cloudflareTunnel.controller.gatewayClassName }}"
with controller "{{ .Values.cloudflareTunnel.controller.controllerName }}".

⚠️  REQUIRED: two Secrets must exist in namespace {{ .Release.Namespace }} BEFORE the
   controller becomes healthy (this chart references them by name — it does NOT
   create them):

   1. "{{ .Values.cloudflareTunnel.gatewayClassConfig.cloudflareCredentialsSecretRef.name }}" with key: api-token
   2. "{{ .Values.cloudflareTunnel.proxy.tunnelTokenSecretRef.name }}" with key: tunnel-token

   kubectl create secret generic {{ .Values.cloudflareTunnel.gatewayClassConfig.cloudflareCredentialsSecretRef.name }} \
     -n {{ .Release.Namespace }} --from-literal=api-token="YOUR_API_TOKEN"
   kubectl create secret generic {{ .Values.cloudflareTunnel.proxy.tunnelTokenSecretRef.name }} \
     -n {{ .Release.Namespace }} --from-literal=tunnel-token="YOUR_TUNNEL_TOKEN"

{{- if not .Values.cloudflareTunnel.gatewayClassConfig.tunnelID }}

⚠️  cloudflareTunnel.gatewayClassConfig.tunnelID is EMPTY. Set it to your
   Cloudflare Tunnel ID or the controller cannot bind the tunnel.

{{- end }}

⚠️  The controller assumes EXCLUSIVE ownership of the tunnel config and removes
   any ingress rules it does not manage. Do not point it at a shared tunnel.

  kubectl get pods -n {{ .Release.Namespace }} -l app.kubernetes.io/name=cloudflare-tunnel-gateway-controller

{{- else }}

ℹ️  Controller subchart is DISABLED. Install a Cloudflare Tunnel Gateway
   controller separately and ensure your Gateways use its GatewayClass.

{{- end }}

================================================================================
  GATEWAY RESOURCES
================================================================================

{{- if .Values.domains }}

Domain-specific Gateways:
{{- range .Values.domains }}
{{- if .enabled }}
  ✅ Gateway "{{ .name }}-gateway" for {{ range .listeners }}{{ .hostname }} {{ end }}
{{- end }}
{{- end }}

  kubectl get gateway -n {{ include "gateway.ns" . }}

{{- else }}

ℹ️  No domain Gateways defined. Add entries under `domains:` in values.yaml.

{{- end }}

================================================================================
  NEXT STEPS
================================================================================

1. Confirm Gateway API CRDs:  kubectl get crd | grep gateway.networking.k8s.io
2. Confirm the two Secrets exist (see above).
3. Confirm GatewayClass is Accepted:  kubectl get gatewayclass {{ .Values.cloudflareTunnel.controller.gatewayClassName }}
4. Create an HTTPRoute to expose a service through the tunnel:

   apiVersion: gateway.networking.k8s.io/v1
   kind: HTTPRoute
   metadata:
     name: my-app
   spec:
     parentRefs:
       - name: <your-domain>-gateway
         namespace: {{ include "gateway.ns" . }}
     hostnames:
       - "myapp.example.com"
     rules:
       - backendRefs:
           - name: my-app-service
             port: 80

For more information:
  - drunk.charts:     https://github.com/baoduy/drunk.charts
  - Gateway API:      https://gateway-api.sigs.k8s.io/
  - CF Tunnel Ctrl:   https://github.com/lexfrei/cloudflare-tunnel-gateway-controller
================================================================================
```

- [ ] **Step 4: Run the assertions — verify they pass**

```bash
cd /Users/steven/_CODE/GIT/drunk.charts
DUMMY=00000000-0000-0000-0000-000000000000
# domain Gateway renders
helm template t drunk-cloudflare-tunnel-gateway \
  --set cloudflareTunnel.gatewayClassConfig.tunnelID=$DUMMY \
  --set 'domains[0].name=domain1' --set 'domains[0].enabled=true' \
  --set 'domains[0].gatewayClassName=cloudflare-tunnel' \
  --set 'domains[0].listeners[0].name=http' \
  --set 'domains[0].listeners[0].protocol=HTTP' \
  --set 'domains[0].listeners[0].port=80' \
  --set 'domains[0].listeners[0].hostname=*.example.com' \
  | grep -q "name: domain1-gateway" && echo "OK gateway"
# routeAccess fallback (no allowedRoutes given → from: Same)
helm template t drunk-cloudflare-tunnel-gateway \
  --set cloudflareTunnel.gatewayClassConfig.tunnelID=$DUMMY \
  --set 'domains[0].name=domain1' --set 'domains[0].enabled=true' \
  --set 'domains[0].gatewayClassName=cloudflare-tunnel' \
  --set 'domains[0].listeners[0].name=http' \
  --set 'domains[0].listeners[0].protocol=HTTP' \
  --set 'domains[0].listeners[0].port=80' \
  --set 'domains[0].listeners[0].hostname=*.example.com' \
  | grep -q "from: Same" && echo "OK routeAccess"
# default render still clean (NOTES is not rendered by `template`, but must not error)
helm template t drunk-cloudflare-tunnel-gateway --set cloudflareTunnel.gatewayClassConfig.tunnelID=$DUMMY >/dev/null && echo "OK default"
```
Expected: all three print OK.

- [ ] **Step 5: Commit**

```bash
git add drunk-cloudflare-tunnel-gateway/templates/domain-gateways.yaml \
  drunk-cloudflare-tunnel-gateway/templates/NOTES.txt
git commit -m "feat(cf-tunnel-gateway): domain Gateways + NOTES"
```

---

### Task 3: Scripts, example values, README

**Files:**
- Create: `drunk-cloudflare-tunnel-gateway/build.sh`
- Create: `drunk-cloudflare-tunnel-gateway/install.sh`
- Create: `drunk-cloudflare-tunnel-gateway/uninstall.sh`
- Create: `drunk-cloudflare-tunnel-gateway/values.example.yaml`
- Create: `drunk-cloudflare-tunnel-gateway/README.md`

**Interfaces:**
- Consumes (from Tasks 1–2): the chart directory, `values.yaml`, `gatewayAPI` defaults.
- Produces: executable scripts; `values.example.yaml` used as the default `VALUES_FILE` by `install.sh`.

- [ ] **Step 1: Create `build.sh`**

Copy from `drunk-nginx-gateway/build.sh` with these exact substitutions and no other changes:
- Comment/header `drunk-nginx-gateway` → `drunk-cloudflare-tunnel-gateway`.
- The `helm repo index` URL suffix `.../drunk-nginx-gateway` → `.../drunk-cloudflare-tunnel-gateway`.
- Dependency-note echo lines: replace the nginx wording with "pulls cloudflare-tunnel-gateway-controller from oci://ghcr.io/lexfrei/charts".
- Keep `helm dependency update`, `helm package . -d .`, the `crds/.gitkeep` guard.

- [ ] **Step 2: Create `values.example.yaml`**

```yaml
# Example values for drunk-cloudflare-tunnel-gateway.
# Copy, fill in tunnelID, ensure the two referenced Secrets exist, then:
#   helm upgrade --install cf-tunnel . -n cloudflare-tunnel-system --create-namespace -f values.example.yaml

cloudflareTunnel:
  enabled: true
  gatewayClassConfig:
    create: true
    tunnelID: "REPLACE-WITH-YOUR-CLOUDFLARE-TUNNEL-ID"
    cloudflareCredentialsSecretRef:
      name: "cloudflare-credentials"      # kubectl secret with key: api-token
  proxy:
    tunnelTokenSecretRef:
      name: "cloudflare-tunnel-token"     # kubectl secret with key: tunnel-token

domains:
  - name: "drunk-dev"
    enabled: true
    gatewayClassName: "cloudflare-tunnel"
    listeners:
      - name: http
        protocol: HTTP
        port: 80
        hostname: "*.drunk.dev"
        allowedRoutes:
          namespaces:
            from: All
```

- [ ] **Step 3: Create `install.sh`**

Copy from `drunk-nginx-gateway/install.sh` with these exact changes:
- Header comments → cloudflare-tunnel wording.
- `RELEASE_NAME` default → `cf-tunnel`; `NAMESPACE` default → `cloudflare-tunnel-system`; `VALUES_FILE` default → `values.example.yaml`; `GATEWAY_API_VERSION` default → `v1.6.1`.
- Between Phase 1 (CRDs) and Phase 2 (helm), add a **secrets pre-flight** block (replaces the NGF-specific RBAC comment):

```bash
# Secrets pre-flight: this chart REFERENCES two Secrets by name; it does not
# create them. Warn (do not fail) if they are missing so the operator can create them.
CRED_SECRET="cloudflare-credentials"
TOKEN_SECRET="cloudflare-tunnel-token"
for s in "$CRED_SECRET" "$TOKEN_SECRET"; do
  if ! kubectl get secret "$s" -n "$NAMESPACE" >/dev/null 2>&1; then
    warn "Secret '$s' not found in namespace '$NAMESPACE'. Create it before the controller can start:"
    if [[ "$s" == "$CRED_SECRET" ]]; then
      echo "  kubectl create secret generic $CRED_SECRET -n $NAMESPACE --from-literal=api-token=YOUR_API_TOKEN"
    else
      echo "  kubectl create secret generic $TOKEN_SECRET -n $NAMESPACE --from-literal=tunnel-token=YOUR_TUNNEL_TOKEN"
    fi
  fi
done
```

- Phase 2: drop the NGF `HELM_SKIP_CRDS_FLAG` branching. The controller subchart ships its `GatewayClassConfig` CRD, so install WITHOUT `--skip-crds`:

```bash
helm dependency build "$CHART_DIR" >/dev/null
helm upgrade --install "$RELEASE_NAME" "$CHART_DIR" \
  --namespace "$NAMESPACE" \
  --create-namespace \
  --values "$CHART_DIR/$VALUES_FILE"
```

- Final verify-hints echo: replace NGF-specific `kubectl` lines with:
```
  kubectl get gatewayclass cloudflare-tunnel
  kubectl get gateway -n $NAMESPACE
  kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=cloudflare-tunnel-gateway-controller
```
- Keep `set -euo pipefail`, dep checks (`helm`, `kubectl`, `curl`), the CRD install/verify logic, and `SKIP_CRDS`/`FORCE_REINSTALL_CRDS` env flags unchanged.

- [ ] **Step 4: Create `uninstall.sh`**

Copy from `drunk-nginx-gateway/uninstall.sh` with header/name/namespace defaults updated (`RELEASE_NAME=cf-tunnel`, `NAMESPACE=cloudflare-tunnel-system`), and add one note echo near the end: `"Referenced Secrets (cloudflare-credentials, cloudflare-tunnel-token) were not created by this chart and are left in place."` Keep any Gateway API CRD cleanup guarded behind its existing opt-in flag.

- [ ] **Step 5: Create `README.md`**

Write a concise README with these sections (prose, no placeholders): Overview (tunnel model, no LoadBalancer/cert-manager); Prerequisites (Cloudflare account, a created Tunnel + Tunnel ID, an API token, Gateway API CRDs v1.6.1); The two Secrets and the exact `kubectl create secret` commands; Install (`./install.sh` and the raw `helm upgrade --install ... -f values.example.yaml` form); Configuration table for `domains[]`, `routeAccess`, and the `cloudflareTunnel.*` passthrough keys; Authoring HTTPRoutes against `<name>-gateway`; the ⚠️ exclusive-tunnel-ownership warning; Uninstall.

- [ ] **Step 6: Make scripts executable and smoke-test**

```bash
cd /Users/steven/_CODE/GIT/drunk.charts/drunk-cloudflare-tunnel-gateway
chmod +x build.sh install.sh uninstall.sh
bash -n build.sh && bash -n install.sh && bash -n uninstall.sh && echo "OK syntax"
# example values render
cd /Users/steven/_CODE/GIT/drunk.charts
helm template t drunk-cloudflare-tunnel-gateway -f drunk-cloudflare-tunnel-gateway/values.example.yaml \
  | grep -q "name: drunk-dev-gateway" && echo "OK example render"
```
Expected: both print OK.

- [ ] **Step 7: Commit**

```bash
git add drunk-cloudflare-tunnel-gateway/build.sh drunk-cloudflare-tunnel-gateway/install.sh \
  drunk-cloudflare-tunnel-gateway/uninstall.sh drunk-cloudflare-tunnel-gateway/values.example.yaml \
  drunk-cloudflare-tunnel-gateway/README.md
git commit -m "feat(cf-tunnel-gateway): build/install/uninstall scripts, example values, README"
```

---

### Task 4: verify.sh (deliverable gate)

**Files:**
- Create: `drunk-cloudflare-tunnel-gateway/verify.sh`

**Interfaces:**
- Consumes: everything from Tasks 1–3.
- Produces: a single pass/fail gate (`exit 0` on success) mirroring `drunk-nginx-gateway/verify.sh`, adapted to this chart.

- [ ] **Step 1: Create `verify.sh`**

Port `drunk-nginx-gateway/verify.sh`, keeping its structure (colored `print_*`, `ERRORS` counter, final summary), with these adaptations:
- Header/name checks: expect `^name: drunk-cloudflare-tunnel-gateway`.
- Dependency check: assert `helm dependency list` contains `cloudflare-tunnel-gateway-controller` (remove the nginx-gateway-fabric and cert-manager checks).
- Required templates list: `templates/_helpers.tpl`, `templates/NOTES.txt`, `templates/domain-gateways.yaml` (remove gatewayclass/clusterissuer/certificate).
- Add a NEGATIVE check: FAIL if `templates/gatewayclass.yaml` exists (the subchart owns the GatewayClass).
- Required values keys: `gatewayAPI`, `domains`, `routeAccess`, `cloudflareTunnel` (remove `gatewayClass`, `gateway`, `certManager`, `nginxGatewayFabric`).
- Define near the top: `DUMMY_TUNNEL_ID="00000000-0000-0000-0000-000000000000"`. EVERY `helm lint` and `helm template` call in this script MUST pass `--set cloudflareTunnel.gatewayClassConfig.tunnelID="$DUMMY_TUNNEL_ID"` (the subchart hard-`required`s tunnelID when `create: true`; the shipped default is intentionally empty). This includes the `helm lint` in Test 1.
- Before render tests, run `helm dependency build "$CHART_DIR" >/dev/null 2>&1` (OCI subchart must be present to template); FAIL with a clear message if it errors.
- Render tests (each adds `--set cloudflareTunnel.gatewayClassConfig.tunnelID="$DUMMY_TUNNEL_ID"`):
  - default `helm template test "$CHART_DIR" --set ...tunnelID=$DUMMY_TUNNEL_ID` succeeds.
  - the same render piped to `grep -q "kind: GatewayClassConfig"` (subchart rendered).
  - the `domains[0]` scenario renders `domain1-gateway` (reuse the nginx scenario 2 block with `gatewayClassName=cloudflare-tunnel`, plus the tunnelID `--set`).
- Scripts check: `install.sh uninstall.sh build.sh` exist and are executable.
- Drop the cert-manager ClusterIssuer scenario entirely.

- [ ] **Step 2: Run the gate**

```bash
cd /Users/steven/_CODE/GIT/drunk.charts
chmod +x drunk-cloudflare-tunnel-gateway/verify.sh
bash drunk-cloudflare-tunnel-gateway/verify.sh
```
Expected: ends with "All verification tests passed!" and exit code 0.

- [ ] **Step 3: Commit**

```bash
git add drunk-cloudflare-tunnel-gateway/verify.sh
git commit -m "feat(cf-tunnel-gateway): verification script"
```

---

## Notes for the executor

- Network access to `oci://ghcr.io/lexfrei/charts` is required for `helm dependency build`. If it is unreachable in the execution environment, that blocks Tasks 1/3/4 render assertions — stop and report rather than stubbing the subchart.
- `Chart.lock` is generated by `helm dependency build`/`update`; commit it in Task 1 (the sibling charts track their `Chart.lock`).
- Do NOT modify `.github/workflows/publish-oci.yml` — CI wiring for this chart is an explicit follow-up, out of scope for this plan.
- Follow the repo convention of semver-range subchart versions (`1.x.x`), matching `drunk-nginx-gateway`'s `2.x.x`/`v1.x.x` deps.
```
