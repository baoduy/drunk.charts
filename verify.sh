#!/usr/bin/env bash
# Run every sub-folder verify.sh (excluding this one). Fails loud on first error.
set -euo pipefail
cd "$(dirname "$0")"

for script in */verify.sh; do
  echo "==> Verifying ${script%/verify.sh}"
  (cd "$(dirname "$script")" && bash verify.sh)
done

echo "All verifications passed."
