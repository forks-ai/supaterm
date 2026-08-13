#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script_path="${script_dir}/$(basename "${BASH_SOURCE[0]}")"
srcroot="${SRCROOT:-$(cd "${script_dir}/.." && pwd)}"
repo_root="$(cd "${srcroot}/../.." && pwd)"
zmx_dir="${srcroot}/ThirdParty/zmx"
zmx_submodule_path="${zmx_dir#"${repo_root}/"}"
zmx_build_root="${srcroot}/.build/zmx"
zmx_local_cache_dir="${zmx_build_root}/.zig-cache"
zmx_global_cache_dir="${zmx_build_root}/.zig-global-cache"
zmx_fingerprint_path="${zmx_build_root}/fingerprint"
zmx_binary_path="${zmx_build_root}/bin/zmx"
zmx_target="aarch64-macos.26.0"
zmx_macos_minimum="26.0"

ensure_zmx_checkout() {
  if [ -f "${zmx_dir}/build.zig" ]; then
    return
  fi

  git -C "${repo_root}" submodule sync --recursive -- "${zmx_submodule_path}"
  git -C "${repo_root}" submodule update --init --recursive -- "${zmx_submodule_path}"

  if [ ! -f "${zmx_dir}/build.zig" ]; then
    echo "error: missing ${zmx_dir} after submodule update" >&2
    exit 1
  fi
}

ensure_zmx_checkout

zmx_revision="$(git -C "${zmx_dir}" rev-parse --short=12 HEAD)"
zmx_version="0.7.0+supaterm.${zmx_revision}"

validate_zmx_binary() {
  local binary_path="$1"
  local architectures
  local minos
  local smoke_dir
  local valid=0
  local version_output

  smoke_dir="$(mktemp -d /tmp/zmx-smoke.XXXXXX)"
  architectures="$(lipo -archs "${binary_path}" 2>/dev/null || true)"
  minos="$(xcrun vtool -show-build "${binary_path}" 2>/dev/null | awk '$1 == "minos" { print $2 }' | sort -u)"
  version_output="$(ZMX_DIR="${smoke_dir}" "${binary_path}" version 2>/dev/null || true)"
  if [ "${architectures}" = "arm64" ] &&
    [ "${minos}" = "${zmx_macos_minimum}" ] &&
    grep -Fq "${zmx_version}" <<<"${version_output}" &&
    ZMX_DIR="${smoke_dir}" "${binary_path}" ls --short >/dev/null 2>&1 &&
    [ "$(stat -f '%Lp' "${smoke_dir}")" = "700" ] &&
    [ "$(stat -f '%Lp' "${smoke_dir}/logs")" = "700" ] &&
    [ "$(stat -f '%Lp' "${smoke_dir}/logs/zmx.log")" = "600" ]; then
    valid=1
  fi
  find "${smoke_dir}" -depth -delete
  [ "${valid}" -eq 1 ]
}

print_fingerprint() {
  (
    cd "${zmx_dir}"
    {
      git rev-parse HEAD
      git diff --no-ext-diff --no-color HEAD -- . | shasum -a 256
      git ls-files --others --exclude-standard | LC_ALL=C sort | shasum -a 256
      shasum -a 256 "${script_path}" | awk '{print $1}'
      mise exec -- zig version
      printf '%s\n' "${zmx_target}" "${zmx_version}"
    } | shasum -a 256 | awk '{print $1}'
  )
}

if [ "${1:-}" = "--print-fingerprint" ]; then
  print_fingerprint
  exit 0
fi

fingerprint="$(print_fingerprint)"

mkdir -p "${zmx_build_root}"

if [ -f "${zmx_fingerprint_path}" ] &&
  [ -x "${zmx_binary_path}" ] &&
  [ "$(cat "${zmx_fingerprint_path}")" = "${fingerprint}" ]; then
  if validate_zmx_binary "${zmx_binary_path}"; then
    printf '%s\n' "Using cached zmx build"
    exit 0
  fi
  printf '%s\n' "Cached zmx build failed smoke test; rebuilding" >&2
fi

cd "${zmx_dir}"
mise exec -- zig build -Doptimize=ReleaseSafe -Dtarget="${zmx_target}" -Dversion="${zmx_version}" --prefix "${zmx_build_root}" --cache-dir "${zmx_local_cache_dir}" --global-cache-dir "${zmx_global_cache_dir}"

if [ ! -x "${zmx_binary_path}" ]; then
  echo "error: zmx build produced no binary at ${zmx_binary_path}" >&2
  exit 1
fi

if ! validate_zmx_binary "${zmx_binary_path}"; then
  echo "error: zmx build produced an unusable binary at ${zmx_binary_path}" >&2
  exit 1
fi

printf '%s\n' "${fingerprint}" > "${zmx_fingerprint_path}"
