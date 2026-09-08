#!/usr/bin/env bash
#
# Local mirror of the `build` job in .github/workflows/release.yaml.
# Produces a platform bundle + archive in ./dist without touching git tags,
# artifacts, or the GitHub release.
#
# Usage:
#   tool/local_build.sh [version]
#
#   version   Optional. Written into bestie_version.dart before compiling.
#             Defaults to the latest v* git tag (minus the `v`), or 0.0.0-dev.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

# --- Resolve target platform from the host ----------------------------------
uname_s="$(uname -s)"
uname_m="$(uname -m)"

case "$uname_s" in
  Darwin) asset_os="macos" ;;
  Linux)  asset_os="linux" ;;
  MINGW*|MSYS*|CYGWIN*) asset_os="windows" ;;
  *) echo "Unsupported OS: $uname_s" >&2; exit 1 ;;
esac

case "$uname_m" in
  arm64|aarch64) asset_arch="arm64" ;;
  x86_64|amd64)  asset_arch="x64" ;;
  *) echo "Unsupported arch: $uname_m" >&2; exit 1 ;;
esac

case "$asset_os" in
  macos)   platform="macos_${asset_arch}"; archive="zip" ;;
  linux)   platform="linux_${asset_arch}"; archive="tar.gz" ;;
  windows) platform="windows_${asset_arch}"; archive="zip" ;;
esac

echo "==> Building for ${platform} (${asset_os}/${asset_arch})"

# --- Version ----------------------------------------------------------------
version="${1:-}"
if [ -z "$version" ]; then
  latest="$(git tag -l 'v*' --sort=-v:refname | head -n1 || true)"
  version="${latest#v}"
  version="${version:-0.0.0-dev}"
fi
echo "==> Version: ${version}"

# --- Fetch native tags (needed by the asset downloaders) --------------------
git -C packages/ffi/curl_impersonate_dart/third_party/curl-impersonate fetch --tags --quiet || true

# --- Dependencies -----------------------------------------------------------
echo "==> dart pub get"
dart pub get

# --- Native / vendored assets -----------------------------------------------
echo "==> Downloading assets"
dart ./tool/download_curl_assets.dart --os "$asset_os"
dart ./tool/download_cert_assets.dart

if [ "$asset_os" = "windows" ]; then
  dart ./tool/download_openconsole_assets.dart
fi

# --- Sidecars ---------------------------------------------------------------
if [ "$asset_os" != "windows" ]; then
  echo "==> Building spawner"
  dart tool/build_spawner.dart
fi

echo "==> Building Rust sidecars"
dart tool/build_sidecar.dart --all

# --- Bundle -----------------------------------------------------------------
bundle_dir="build/cli/${platform}/bundle"
rm -rf "$bundle_dir"

echo "==> Setting version and compiling CLI"
dart tool/set_version.dart "$version"

(cd packages/bestie && dart build cli -o "../../build/cli/${platform}")

rm -f "${bundle_dir}/lib/.gitkeep"

# `dart build cli` only bundles the hook-driven code assets (the dylibs).
# Every other shipped file (cacert.pem, shell/bin, spawner,
# CREDITS.md) is staged from the bundleAssets manifest here, which also
# verifies each declared asset actually landed.
echo "==> Staging app assets (cacert, shell, spawner, credits)"
dart tool/bundle_assets.dart --os "$asset_os" "$bundle_dir"

echo "==> Staging licenses"
dart tool/build_licenses.dart
cp LICENSE.md build/THIRD_PARTY_LICENSES.txt "${bundle_dir}/"

# --- Portable installer -----------------------------------------------------
# The archive has the same flat layout CI ships (bin/bestie at the top level),
# plus install_portable.sh beside it for offline installs.
cp tool/install_portable.sh "${bundle_dir}/install_portable.sh"
chmod +x "${bundle_dir}/install_portable.sh"

# --- Package ----------------------------------------------------------------
mkdir -p dist
out="${repo_root}/dist/bestie-${platform}.${archive}"
rm -f "$out"

echo "==> Packaging ${out}"
if [ "$archive" = "tar.gz" ]; then
  tar -czf "$out" -C "$bundle_dir" .
elif [ "$asset_os" = "windows" ]; then
  (cd "$bundle_dir" && 7z a -tzip "$out" . > /dev/null)
else
  (cd "$bundle_dir" && zip -r "$out" . > /dev/null)
fi

echo ""
echo "==> Done: $out"
echo "    Bundle: ${bundle_dir}"
