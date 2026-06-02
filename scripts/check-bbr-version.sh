#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$SCRIPT_DIR/common.sh"

MODE="${1:-}"
OPENWRT_DIR="${2:-${OPENWRT_DIR:-}}"
EXPECTED_BBR_VERSION="${EXPECTED_BBR_VERSION:-3}"

[ -n "$MODE" ] && [ -n "$OPENWRT_DIR" ] || die "Usage: $0 <staged|module> <openwrt-dir>"
need_dir "$OPENWRT_DIR"

kernel_patchver="$(
  awk -F ':=' '/^KERNEL_PATCHVER:=/ { gsub(/[[:space:]]/, "", $2); print $2; exit }' "$OPENWRT_DIR/target/linux/rockchip/Makefile"
)"
[ -n "$kernel_patchver" ] || die "Unable to detect rockchip KERNEL_PATCHVER"

detect_staged_patch_version() {
  local patch_dir="$OPENWRT_DIR/target/linux/generic/backport-$kernel_patchver"
  local version=""

  [ -d "$patch_dir" ] || die "BBR backport patch directory not found: $patch_dir"

  version="$(
    grep -RhoE '^\+#[[:space:]]*define[[:space:]]+BBR_VERSION[[:space:]]+[0-9]+' "$patch_dir" 2>/dev/null |
      awk '{ print $NF; exit }' || true
  )"

  [ -n "$version" ] || die "Unable to detect BBR_VERSION from staged patches in $patch_dir"
  [ "$version" = "$EXPECTED_BBR_VERSION" ] || die "Expected BBR v$EXPECTED_BBR_VERSION patch, detected v$version"

  log "Detected staged BBR patch version: v$version"
}

detect_module_version() {
  local module_file=""
  local source_file=""
  local version=""

  module_file="$(
    find "$OPENWRT_DIR/bin" "$OPENWRT_DIR/build_dir" -name 'tcp_bbr.ko' -type f 2>/dev/null |
      sort |
      head -n 1 || true
  )"

  [ -n "$module_file" ] || die "tcp_bbr.ko not found after build"

  if command -v modinfo >/dev/null 2>&1; then
    version="$(modinfo -F version "$module_file" 2>/dev/null || true)"
  fi

  if [ -z "$version" ] && command -v strings >/dev/null 2>&1; then
    version="$(strings "$module_file" | sed -n 's/^version=//p' | head -n 1)"
  fi

  if [ -z "$version" ]; then
    source_file="$(
      find "$OPENWRT_DIR/build_dir" -path '*/linux-*/net/ipv4/tcp_bbr.c' -type f 2>/dev/null |
        sort |
        head -n 1 || true
    )"

    if [ -n "$source_file" ]; then
      version="$(
        awk '/^[[:space:]]*#[[:space:]]*define[[:space:]]+BBR_VERSION[[:space:]]+[0-9]+/ { print $NF; exit }' "$source_file"
      )"
    fi
  fi

  [ -n "$version" ] || die "Unable to read BBR version from $module_file"
  [ "$version" = "$EXPECTED_BBR_VERSION" ] || die "Expected BBR v$EXPECTED_BBR_VERSION, detected v$version"

  log "Detected built BBR version: v$version (${module_file#$OPENWRT_DIR/})"
}

case "$MODE" in
  staged) detect_staged_patch_version ;;
  module) detect_module_version ;;
  *) die "Unknown mode: $MODE (expected staged or module)" ;;
esac
