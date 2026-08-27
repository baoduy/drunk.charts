#!/usr/bin/env bash
# Run every sub-folder build.sh (excluding this one). Fails loud on first error.
set -euo pipefail
cd "$(dirname "$0")"

for script in */build.sh; do
  echo "==> Building ${script%/build.sh}"
  (cd "$(dirname "$script")" && bash build.sh)
done

echo "All builds passed."
