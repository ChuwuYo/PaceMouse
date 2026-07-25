#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
for dir in "$ROOT"/Reference/*/; do
  name=$(basename "$dir")
  echo "==> $name"
  git -C "$dir" pull --ff-only --quiet || echo "WARN: $name update failed"
done
echo "All references synced."
