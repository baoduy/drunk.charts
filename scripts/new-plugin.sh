#!/usr/bin/env bash
# scripts/new-plugin.sh — scaffold a new plugin under plugins/<name>/ and
# register it in .claude-plugin/marketplace.json.
#
# Usage: scripts/new-plugin.sh <plugin-name> "<description>"
set -euo pipefail

usage() {
  echo "Usage: $0 <plugin-name> \"<description>\"" >&2
  exit 64
}

[[ $# -eq 2 ]] || usage
NAME="$1"
DESC="$2"

if ! [[ "$NAME" =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo "error: plugin name must match ^[a-z][a-z0-9-]*$ (got: $NAME)" >&2
  exit 2
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

PLUGIN_DIR="plugins/$NAME"
MARKET=".claude-plugin/marketplace.json"

if [[ -e "$PLUGIN_DIR" ]]; then
  echo "error: $PLUGIN_DIR already exists" >&2
  exit 3
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required" >&2
  exit 4
fi

if jq -e --arg n "$NAME" '.plugins[]? | select(.name==$n)' "$MARKET" >/dev/null; then
  echo "error: plugin '$NAME' already in $MARKET" >&2
  exit 5
fi

AUTHOR="$(git config user.name || echo Unknown)"

mkdir -p "$PLUGIN_DIR/.claude-plugin" "$PLUGIN_DIR/skills/$NAME"

jq -n \
  --arg name "$NAME" \
  --arg desc "$DESC" \
  --arg author "$AUTHOR" \
  '{
    name: $name,
    version: "0.1.0",
    description: $desc,
    author: { name: $author },
    repository: "https://github.com/baoduy/drunk.charts",
    license: "MIT",
    keywords: []
  }' > "$PLUGIN_DIR/.claude-plugin/plugin.json"

cat > "$PLUGIN_DIR/skills/$NAME/SKILL.md" <<MD
---
name: $NAME
description: "TODO — describe when this skill activates. Triggers on: <keywords>."
---

# $NAME

TODO — write the skill body. Use \`docs/superpowers/templates/SKILL.md.template\` as a starting point.
MD

# Atomic marketplace.json update via temp file
TMP="$(mktemp)"
jq --arg name "$NAME" --arg desc "$DESC" --arg src "./plugins/$NAME" '
  .plugins += [{
    "name": $name,
    "version": "0.1.0",
    "source": $src,
    "description": $desc
  }]
' "$MARKET" > "$TMP"
mv "$TMP" "$MARKET"

cat <<EOF
✅ Scaffolded plugins/$NAME

Next:
  1. Edit $PLUGIN_DIR/.claude-plugin/plugin.json (set keywords).
  2. Edit $PLUGIN_DIR/skills/$NAME/SKILL.md (use docs/superpowers/templates/SKILL.md.template).
  3. Run: git --no-pager diff -- plugins/$NAME .claude-plugin/marketplace.json
  4. git add plugins/$NAME .claude-plugin/marketplace.json && git commit
EOF
