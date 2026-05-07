#!/usr/bin/env bash
set -euo pipefail

sparkle_version=$(awk -F'"' '/sparkle-project\/Sparkle/ { print $4; exit }' apps/mac/Tuist/Package.swift)
if [[ -z "$sparkle_version" ]]; then
  echo "::error::Unable to determine Sparkle version"
  exit 1
fi

tools_dir=apps/mac/build/sparkle-tools
archive="$tools_dir/sparkle.zip"

rm -rf "$tools_dir"
mkdir -p "$tools_dir"

curl \
  --fail \
  --silent \
  --show-error \
  --location \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 10 \
  --connect-timeout 30 \
  --speed-time 60 \
  --speed-limit 1024 \
  "https://github.com/sparkle-project/Sparkle/releases/download/$sparkle_version/Sparkle-for-Swift-Package-Manager.zip" \
  --output "$archive"

unzip -q "$archive" -d "$tools_dir"
