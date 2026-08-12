#!/bin/bash
set -euo pipefail

installer=$(mktemp)
trap 'rm -f "$installer"' EXIT
curl \
  --proto '=https' \
  --tlsv1.2 \
  --retry 3 \
  --retry-all-errors \
  --silent \
  --show-error \
  --fail \
  --output "$installer" \
  https://download.posthog.com/cli
sh "$installer"
