#!/usr/bin/env bash
# guide_check.sh — acceptance checks for DRK-2043 that live in the drunk-app guide and values files.
# Run from anywhere: bash drunk-app/tests/guide_check.sh
# Prints one PASS/FAIL line per check and exits 1 when any check fails.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHART_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$CHART_DIR/.." && pwd)"
GUIDE="$REPO_ROOT/docs/drunk-app.md"
EXAMPLE="$SCRIPT_DIR/values/workload-identity.yaml"

FAILED=0
pass() { echo "PASS  $1"; }
fail() { echo "FAIL  $1 — $2"; FAILED=1; }

# Print the body of the first heading that matches $1 exactly, up to the next heading of the same or higher level.
section() {
  awk -v h="$1" '
    BEGIN { lvl = length(h) - length(substr(h, index(h, " "))) }
    /^```/ { fence = !fence }
    !fence && /^#+ / {
      l = index($0, " ") - 1
      if (inside && l <= lvl) exit
      if ($0 == h && !done) { inside = 1; done = 1; next }
    }
    inside { print }
  ' "$GUIDE"
}

# The nearest "### " heading above the first line that equals $1.
parent_h3() {
  awk -v h="$1" '
    /^```/ { fence = !fence }
    !fence && /^### / { last = $0 }
    !fence && $0 == h { print last; exit }
  ' "$GUIDE"
}

# ── Scenario: The guide's workload identity example works without a manual patch ──
S1="The guide's workload identity example works without a manual patch"
if [ "$(parent_h3 '#### Workload identity')" != "### secretProvider" ]; then
  fail "$S1" "no '#### Workload identity' heading inside '### secretProvider' in docs/drunk-app.md"
else
  quoted="$(section '#### Workload identity' | awk '/^```yaml$/ && !seen { seen = 1; on = 1; next } on && /^```$/ { exit } on { print }')"
  if [ -z "$quoted" ]; then
    fail "$S1" "'#### Workload identity' has no yaml example block"
  elif ! diff -u "$EXAMPLE" <(printf '%s\n' "$quoted") >/dev/null; then
    fail "$S1" "the guide's yaml example is not tests/values/workload-identity.yaml verbatim"
  else
    pass "$S1"
  fi
fi

# ── Scenario: The default values hold no unused pod annotations setting ──
S2="The default values hold no unused pod annotations setting"
s2_ok=1
for f in "$CHART_DIR/values.yaml" "$CHART_DIR/values.example.yaml"; do
  # Every podAnnotations key must sit directly under the top-level deployment or statefulset key.
  bad="$(awk -v name="drunk-app/$(basename "$f")" '
    /^[A-Za-z_][A-Za-z0-9_]*:/ { top = $0; sub(/:.*/, "", top) }
    /^[[:space:]]*podAnnotations:/ {
      indent = match($0, /[^ ]/) - 1
      if (!(indent == 2 && (top == "deployment" || top == "statefulset"))) print name ":" NR
    }
  ' "$f")"
  if [ -n "$bad" ]; then
    fail "$S2" "podAnnotations outside deployment/statefulset at $bad"
    s2_ok=0
  fi
done
if [ "$(parent_h3 '#### podAnnotations')" != "### Pod Settings" ]; then
  fail "$S2" "no '#### podAnnotations' heading inside '### Pod Settings' in docs/drunk-app.md"
  s2_ok=0
else
  body="$(section '#### podAnnotations')"
  for key in 'deployment.podAnnotations' 'statefulset.podAnnotations'; do
    if ! grep -qF "\`$key\`" <<<"$body"; then
      fail "$S2" "the guide's pod annotations section does not point at \`$key\`"
      s2_ok=0
    fi
  done
  if grep -qE '^podAnnotations:' <<<"$body"; then
    fail "$S2" "the guide's pod annotations section still shows a top-level podAnnotations key"
    s2_ok=0
  fi
fi
[ "$s2_ok" -eq 1 ] && pass "$S2"

# ── Scenario: The guide warns charts that relied on a plain false ──
S3="The guide warns charts that relied on a plain false"
if ! grep -qx '## Upgrade Notes' "$GUIDE"; then
  fail "$S3" "no '## Upgrade Notes' section in docs/drunk-app.md"
else
  note="$(section '## Upgrade Notes' | awk '/^### 2\.0\.4$/ { on = 1; next } on && /^#{1,3} / { exit } on { print }')"
  if [ -z "$note" ]; then
    fail "$S3" "no '### 2.0.4' note under '## Upgrade Notes'"
  elif ! grep -qF 'useVMManagedIdentity' <<<"$note"; then
    fail "$S3" "the 2.0.4 note does not name useVMManagedIdentity"
  elif ! grep -qw 'false' <<<"$note" || ! grep -qw 'true' <<<"$note"; then
    fail "$S3" "the 2.0.4 note does not say that a plain false must now be written as true"
  else
    pass "$S3"
  fi
fi

# ── Brief §3 row 7: the guide documents the new and changed settings ──
S4="The guide documents the pod labels, client id and VM identity settings"
s4_ok=1
for key in 'deployment.podLabels' 'statefulset.podLabels' 'secretProvider.provider.clientID' 'secretProvider.provider.useVMManagedIdentity'; do
  if ! grep -qE "^\| \`$(sed 's/\./\\./g' <<<"$key")\` \|" "$GUIDE"; then
    fail "$S4" "no parameter table row for \`$key\`"
    s4_ok=0
  fi
done
if ! grep -qF '[Upgrade Notes](#upgrade-notes)' "$GUIDE"; then
  fail "$S4" "the table of contents has no Upgrade Notes entry"
  s4_ok=0
fi
[ "$s4_ok" -eq 1 ] && pass "$S4"

exit "$FAILED"
