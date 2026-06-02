#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$SCRIPT_DIR/common.sh"

OPENWRT_DIR="${1:-${OPENWRT_DIR:-}}"
[ -n "$OPENWRT_DIR" ] || die "Usage: $0 <openwrt-dir>"
need_dir "$OPENWRT_DIR"

target_mk="$OPENWRT_DIR/include/target.mk"
need_file "$target_mk"

log "Applying YAOF O2 target optimization"
sed -i \
  -e 's/-Os/-O2/g' \
  "$target_mk"

bash "$SCRIPT_DIR/apply-kernel-olddefconfig-fallback.sh" "$OPENWRT_DIR"
