#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -eq 0 ]; then
  echo "usage: $0 <icon-name> [icon-name ...]" >&2
  exit 64
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
srcroot="$(cd "${script_dir}/.." && pwd)"
asset_root="${srcroot}/supaterm/Assets.xcassets"
lucide_version="${LUCIDE_ICON_VERSION:-latest}"
base_url="https://unpkg.com/lucide-static@${lucide_version}/icons"
tmp=""
tmp_filtered=""

trap 'rm -f "${tmp}" "${tmp_filtered}"' EXIT

for icon_name in "$@"; do
  case "${icon_name}" in
    "" | *[!a-z0-9-]*)
      echo "error: invalid icon name: ${icon_name}" >&2
      exit 64
      ;;
  esac

  imageset_dir="${asset_root}/${icon_name}.imageset"
  svg_path="${imageset_dir}/${icon_name}.svg"
  contents_path="${imageset_dir}/Contents.json"
  tmp="$(mktemp)"
  tmp_filtered="$(mktemp)"

  curl -fsSL "${base_url}/${icon_name}.svg" -o "${tmp}"
  awk '!/^<!-- @license /' "${tmp}" > "${tmp_filtered}"
  mv "${tmp_filtered}" "${tmp}"

  if ! grep -q "lucide-${icon_name}" "${tmp}"; then
    echo "error: fetched SVG does not look like ${icon_name}" >&2
    exit 65
  fi

  mkdir -p "${imageset_dir}"
  mv "${tmp}" "${svg_path}"

  cat > "${contents_path}" <<JSON
{
  "images" : [
    {
      "filename" : "${icon_name}.svg",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "preserves-vector-representation" : true,
    "template-rendering-intent" : "template"
  }
}
JSON
done
