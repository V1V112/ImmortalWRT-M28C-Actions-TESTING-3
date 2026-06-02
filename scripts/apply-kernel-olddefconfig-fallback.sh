#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$SCRIPT_DIR/common.sh"

OPENWRT_DIR="${1:-${OPENWRT_DIR:-}}"
[ -n "$OPENWRT_DIR" ] || die "Usage: $0 <openwrt-dir>"
need_dir "$OPENWRT_DIR"

kernel_defaults_mk="$OPENWRT_DIR/include/kernel-defaults.mk"
need_file "$kernel_defaults_mk"

if ! grep -q 'YAOF: auto-fill new kernel Kconfig defaults' "$kernel_defaults_mk"; then
  tmp="$(mktemp)"
  awk '
    /^\t\$\(_SINGLE\) \[ -d \$\(LINUX_DIR\)\/user_headers \]/ && !inserted {
      print "\t# YAOF: auto-fill new kernel Kconfig defaults"
      print "\t$(KERNEL_MAKE) olddefconfig"
      print "\tcp $(LINUX_DIR)/.config $(LINUX_DIR)/.config.set"
      print "\tcp $(LINUX_DIR)/.config $(LINUX_DIR)/.config.prev"
      inserted = 1
    }
    { print }
    END {
      if (!inserted) {
        exit 42
      }
    }
  ' "$kernel_defaults_mk" > "$tmp" || {
    rm -f "$tmp"
    die "Unable to patch include/kernel-defaults.mk for olddefconfig"
  }
  mv "$tmp" "$kernel_defaults_mk"
  log "Enabled kernel olddefconfig fallback for new Kconfig defaults"
fi
