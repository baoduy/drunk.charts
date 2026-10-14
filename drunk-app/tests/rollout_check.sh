#!/usr/bin/env bash
# Integration coverage for aggregate consumers, aliases sharing one YAML anchor,
# and comments that helm-unittest's parsed YAML cannot inspect.
set -euo pipefail
CHART_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$CHART_DIR/.." && pwd)"
CHECK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/drunk-rollout-check.XXXXXX")"
trap 'rm -rf "$CHECK_DIR"' EXIT

mkdir -p "$CHECK_DIR/aggregate/templates" "$CHECK_DIR/aggregate/charts"
cat > "$CHECK_DIR/aggregate/Chart.yaml" <<'YAML'
apiVersion: v2
name: aggregate
version: 0.1.0
dependencies:
  - name: drunk-lib
    version: 2.*.*
YAML
cp "$CHART_DIR"/charts/drunk-lib-*.tgz "$CHECK_DIR/aggregate/charts/"
printf '{{ include "drunk-lib.all" . }}\n' > "$CHECK_DIR/aggregate/templates/all.yaml"
helm template test "$CHECK_DIR/aggregate" \
  --values "$REPO_ROOT/drunk-lib/tests/values/rollout.yaml" > "$CHECK_DIR/aggregate.yaml"
grep -q '^kind: PodDisruptionBudget$' "$CHECK_DIR/aggregate.yaml"
helm template test "$CHECK_DIR/aggregate" \
  --values "$REPO_ROOT/drunk-lib/tests/values/rollout.yaml" \
  --set podDisruptionBudget.enabled=false > "$CHECK_DIR/aggregate-disabled.yaml"
if grep -q '^kind: PodDisruptionBudget$' "$CHECK_DIR/aggregate-disabled.yaml"; then
  echo 'FAIL aggregate PDB opt-out'
  exit 1
fi
echo 'PASS drunk-lib.all includes opt-in PDB and respects opt-out'

# The aggregate must expose the same policy includes as the app wrappers.
helm template test "$CHECK_DIR/aggregate" --namespace app-namespace \
  --values "$REPO_ROOT/drunk-lib/tests/values/rollout.yaml" \
  --set httpRoute.enabled=true \
  --set httpRoute.hostnames[0]=app.example.com \
  --set httpRoute.tlsValidation.wellKnownCACertificates=System \
  --set nginxUpstreamSettingsPolicy.enabled=true \
  --set nginxClientSettingsPolicy.enabled=true > "$CHECK_DIR/aggregate-policies.yaml"
for kind in UpstreamSettingsPolicy ClientSettingsPolicy BackendTLSPolicy; do
  count="$(grep -c "^kind: $kind$" "$CHECK_DIR/aggregate-policies.yaml")"
  if [ "$count" -ne 1 ]; then
    echo "FAIL aggregate $kind: expected 1 document, found $count"
    exit 1
  fi
done
if grep -qE '^kind: (UpstreamSettingsPolicy|ClientSettingsPolicy|BackendTLSPolicy)$' "$CHECK_DIR/aggregate.yaml"; then
  echo 'FAIL aggregate policies render without opt-in'
  exit 1
fi
echo 'PASS drunk-lib.all includes all 3 opt-in gateway policies and omits them by default'

mkdir -p "$CHECK_DIR/aliases/charts"
cat > "$CHECK_DIR/aliases/Chart.yaml" <<'YAML'
apiVersion: v2
name: rollout-aliases
version: 0.1.0
dependencies:
  - name: drunk-app
    alias: first
    version: 2.*.*
  - name: drunk-app
    alias: second
    version: 2.*.*
YAML
helm package "$CHART_DIR" --destination "$CHECK_DIR/aliases/charts" >/dev/null
cat > "$CHECK_DIR/aliases/values.yaml" <<'YAML'
first: &shared
  global: {image: example/app, tag: latest}
  deployment: {enabled: true, replicaCount: 3}
  podAntiAffinityPreset: soft
  topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: topology.kubernetes.io/zone
      whenUnsatisfiable: ScheduleAnyway
  podDisruptionBudget: {enabled: true, minAvailable: 1}
second: *shared
YAML
helm template test "$CHECK_DIR/aliases" > "$CHECK_DIR/aliases.yaml"
# Each alias has 5 name labels: Deployment metadata, selector, pod, anti-affinity,
# spread selector; and 2 PDB name labels: metadata and selector.
for alias in first second; do
  for template in deployment pdb; do
    awk -v source="rollout-aliases/charts/$alias/templates/$template.yaml" '
      /^# Source:/ { inside = ($0 == "# Source: " source) }
      inside { print }
    ' "$CHECK_DIR/aliases.yaml" > "$CHECK_DIR/$alias-$template.yaml"
    expected=5
    if [ "$template" = pdb ]; then expected=2; fi
    count="$(grep -c "app.kubernetes.io/name: $alias$" "$CHECK_DIR/$alias-$template.yaml")"
    if [ "$count" -ne "$expected" ]; then
      echo "FAIL $alias $template selectors: $count labels, expected $expected"
      exit 1
    fi
  done
done
echo 'PASS two actual chart aliases share one anchor and retain independent selectors'

helm template test "$CHART_DIR" --set deployment.strategy.type=Recreate \
  --show-only templates/deployment.yaml > "$CHECK_DIR/recreate.yaml"
if grep -qE 'rollingUpdate:|# Rolling update parameters' "$CHECK_DIR/recreate.yaml"; then
  echo 'FAIL Recreate contains rolling update block or comment'
  exit 1
fi
echo 'PASS Recreate omits rolling update block and comment'

# The full example includes an auto-detected HTTPRoute backend and 2 explicit
# Ingress backend ports. Check each render against those exact expected ports.
for iteration in {1..20}; do
  helm template test "$CHART_DIR" --values "$CHART_DIR/values.example.yaml" \
    --show-only templates/httproute.yaml --show-only templates/ingress.yaml \
    > "$CHECK_DIR/example-$iteration.yaml"
  route_ports="$(awk '
    /^# Source:/ { source = $0 }
    source ~ /templates\/httproute.yaml$/ && /^[[:space:]]+port:/ { print $2 }
  ' "$CHECK_DIR/example-$iteration.yaml")"
  ingress_ports="$(awk '
    /^# Source:/ { source = $0 }
    source ~ /templates\/ingress.yaml$/ && /^[[:space:]]+number:/ { print $2 }
  ' "$CHECK_DIR/example-$iteration.yaml")"
  if [ "$route_ports" != 8080 ] || [ "$ingress_ports" != $'8080\n9090' ]; then
    echo "FAIL render $iteration: unexpected HTTPRoute or Ingress backend port"
    exit 1
  fi
done
echo 'PASS 20 example renders: HTTPRoute 8080; explicit Ingress ports 8080 and 9090 every time'
