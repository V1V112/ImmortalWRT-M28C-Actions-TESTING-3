#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$SCRIPT_DIR/common.sh"

OPENWRT_DIR="${1:-${OPENWRT_DIR:-}}"
[ -n "$OPENWRT_DIR" ] || die "Usage: $0 <openwrt-dir>"
need_dir "$OPENWRT_DIR"

PROJECT_DIR="${PROJECT_DIR:-$(project_dir)}"
YAOF_REPO_URL="${YAOF_REPO_URL:-https://github.com/QiuSimons/YAOF.git}"
YAOF_REF="${YAOF_REF:-25.12}"
YAOF_SUPPORTED_KERNEL="${YAOF_SUPPORTED_KERNEL:-6.12}"
tmp_dirs=()
FETCHED_YAOF_DIR=""

cleanup() {
  local dir
  for dir in "${tmp_dirs[@]}"; do
    [ -n "$dir" ] && rm -rf "$dir"
  done
  return 0
}
trap cleanup EXIT

kernel_patchver="$(
  awk -F ':=' '/^KERNEL_PATCHVER:=/ { gsub(/[[:space:]]/, "", $2); print $2; exit }' "$OPENWRT_DIR/target/linux/rockchip/Makefile"
)"
[ -n "$kernel_patchver" ] || die "Unable to detect rockchip KERNEL_PATCHVER"

append_yaof_lrng_config() {
  local dst="$OPENWRT_DIR/target/linux/generic/config-$kernel_patchver"

  need_file "$dst"

  log "Appending YAOF LRNG kernel config"
  cat >> "$dst" <<'EOF'

# YAOF LRNG defaults
# CONFIG_RANDOM_DEFAULT_IMPL is not set
CONFIG_LRNG=y
CONFIG_LRNG_DEV_IF=y
# CONFIG_LRNG_AIS2031_NTG1_SEEDING_STRATEGY is not set
# CONFIG_LRNG_IRQ is not set
CONFIG_LRNG_JENT=y
CONFIG_LRNG_CPU=y
# CONFIG_LRNG_SCHED is not set
CONFIG_LRNG_SELFTEST=y
# CONFIG_LRNG_SELFTEST_PANIC is not set
EOF
}

stage_patches() {
  local src="$1"
  local dst="$2"
  local fallback="${3:-}"

  [ -d "$src" ] || return 0

  if [ ! -d "$dst" ] && [ -n "$fallback" ]; then
    dst="$fallback"
  fi
  need_dir "$dst"

  log "Staging kernel patches into ${dst#$OPENWRT_DIR/}"
  find "$src" -maxdepth 1 -name '*.patch' -type f -print0 |
    xargs -0 -r cp -t "$dst"
}

fetch_yaof() {
  local dst

  if [ -n "${YAOF_SOURCE_DIR:-}" ]; then
    need_dir "$YAOF_SOURCE_DIR"
    FETCHED_YAOF_DIR="$YAOF_SOURCE_DIR"
    return 0
  fi

  dst="$(mktemp -d)"
  tmp_dirs+=("$dst")

  log "Fetching YAOF kernel assets: $YAOF_REPO_URL ($YAOF_REF)" >&2
  if ! git clone --depth 1 --filter=blob:none --sparse --branch "$YAOF_REF" "$YAOF_REPO_URL" "$dst"; then
    warn "Filtered YAOF clone failed; retrying without blob filter"
    rm -rf "$dst"
    dst="$(mktemp -d)"
    tmp_dirs+=("$dst")
    git clone --depth 1 --sparse --branch "$YAOF_REF" "$YAOF_REPO_URL" "$dst"
  fi

  git -C "$dst" sparse-checkout set PATCH/kernel/bbr3 PATCH/kernel/lrng

  FETCHED_YAOF_DIR="$dst"
}

stage_yaof_kernel_assets() {
  local yaof_dir

  if [ "$kernel_patchver" != "$YAOF_SUPPORTED_KERNEL" ]; then
    warn "Skipping YAOF BBRv3/LRNG patches: kernel $kernel_patchver is not $YAOF_SUPPORTED_KERNEL"
    return 0
  fi

  fetch_yaof
  yaof_dir="$FETCHED_YAOF_DIR"

  stage_patches \
    "$yaof_dir/PATCH/kernel/bbr3" \
    "$OPENWRT_DIR/target/linux/generic/backport-$kernel_patchver" \
    "$OPENWRT_DIR/target/linux/generic/backport"

  stage_patches \
    "$yaof_dir/PATCH/kernel/lrng" \
    "$OPENWRT_DIR/target/linux/generic/hack-$kernel_patchver" \
    "$OPENWRT_DIR/target/linux/generic/hack"

  append_yaof_lrng_config
  bash "$SCRIPT_DIR/apply-kernel-olddefconfig-fallback.sh" "$OPENWRT_DIR"
}

apply_openwrt_patches() {
  local src="$1"
  local patch_file
  local reject_dir="$OPENWRT_DIR/.patch-rejects"

  [ -d "$src" ] || return 0

  while IFS= read -r -d '' patch_file; do
    log "Applying OpenWrt tree patch: ${patch_file#$PROJECT_DIR/}"
    if patch -d "$OPENWRT_DIR" -p1 --forward --dry-run < "$patch_file" >/dev/null; then
      patch -d "$OPENWRT_DIR" -p1 --forward < "$patch_file"
    elif patch -d "$OPENWRT_DIR" -p1 --reverse --dry-run < "$patch_file" >/dev/null 2>&1; then
      warn "OpenWrt tree patch already applied, skipping: ${patch_file#$PROJECT_DIR/}"
    else
      mkdir -p "$reject_dir"
      if ! patch -d "$OPENWRT_DIR" -p1 --forward --batch --reject-file="$reject_dir/$(basename "$patch_file").rej" < "$patch_file"; then
        warn "OpenWrt tree patch failed: ${patch_file#$PROJECT_DIR/}"
        if [ -s "$reject_dir/$(basename "$patch_file").rej" ]; then
          sed 's/^/REJECT: /' "$reject_dir/$(basename "$patch_file").rej" >&2
        fi
        return 1
      fi
    fi
  done < <(find "$src" -name '*.patch' -type f -print0 | sort -z)
}

stage_patches \
  "$PROJECT_DIR/patches/kernel/generic" \
  "$OPENWRT_DIR/target/linux/generic/hack-$kernel_patchver" \
  "$OPENWRT_DIR/target/linux/generic/hack"

stage_patches \
  "$PROJECT_DIR/patches/kernel/generic/hack" \
  "$OPENWRT_DIR/target/linux/generic/hack-$kernel_patchver" \
  "$OPENWRT_DIR/target/linux/generic/hack"

stage_patches \
  "$PROJECT_DIR/patches/kernel/generic/backport" \
  "$OPENWRT_DIR/target/linux/generic/backport-$kernel_patchver" \
  "$OPENWRT_DIR/target/linux/generic/backport"

stage_patches \
  "$PROJECT_DIR/patches/kernel/generic/pending" \
  "$OPENWRT_DIR/target/linux/generic/pending-$kernel_patchver" \
  "$OPENWRT_DIR/target/linux/generic/pending"

stage_yaof_kernel_assets

apply_openwrt_patches \
  "$PROJECT_DIR/patches/kernel/rockchip"
