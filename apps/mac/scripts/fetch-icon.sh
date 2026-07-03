#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "usage: $0 <lucide|simple-icons> <icon-name> [icon-name ...]" >&2
  exit 64
fi

icon_source="$1"
shift

case "${icon_source}" in
  lucide)
    base_url="https://unpkg.com/lucide-static@${LUCIDE_ICON_VERSION:-latest}/icons"
    ;;
  simple-icons)
    base_url="https://unpkg.com/simple-icons@${SIMPLE_ICONS_VERSION:-latest}/icons"
    ;;
  *)
    echo "error: unknown icon source: ${icon_source}" >&2
    exit 64
    ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
srcroot="$(cd "${script_dir}/.." && pwd)"
asset_root="${srcroot}/supaterm/Assets.xcassets"
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

  case "${icon_source}" in
    lucide)
      awk '!/^<!-- @license /' "${tmp}" > "${tmp_filtered}"
      if ! grep -q "lucide-${icon_name}" "${tmp_filtered}"; then
        echo "error: fetched SVG does not look like ${icon_name}" >&2
        exit 65
      fi
      ;;
    simple-icons)
      if ! grep -q 'viewBox="0 0 24 24"' "${tmp}"; then
        echo "error: fetched SVG does not look like ${icon_name}" >&2
        exit 65
      fi
      sed 's/viewBox="0 0 24 24"/viewBox="-1 -1 26 26" fill="currentColor"/' "${tmp}" > "${tmp_filtered}"
      ;;
  esac

  mkdir -p "${imageset_dir}"
  mv "${tmp_filtered}" "${svg_path}"
  rm -f "${tmp}"

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
