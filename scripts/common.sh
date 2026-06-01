#!/usr/bin/env bash

set -euo pipefail

project_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

log() {
  printf '\033[1;34m==>\033[0m %s\n' "$*"
}

warn() {
  printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2
}

die() {
  printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2
  exit 1
}

need_dir() {
  local dir="$1"
  [ -d "$dir" ] || die "Directory not found: $dir"
}

need_file() {
  local file="$1"
  [ -f "$file" ] || die "File not found: $file"
}
