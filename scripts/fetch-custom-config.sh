#!/usr/bin/env bash

# 从私人仓库拉取 OpenWrt 配置文件
# 用法: fetch-custom-config.sh <openwrt-dir> <repo-url> [branch] [token]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$SCRIPT_DIR/common.sh"

OPENWRT_DIR="${1:-${OPENWRT_DIR:-}}"
REPO_URL="${2:-}"
BRANCH="${3:-main}"
TOKEN="${4:-${CUSTOM_CONFIG_TOKEN:-}}"

[ -n "$OPENWRT_DIR" ] && [ -n "$REPO_URL" ] || die "Usage: $0 <openwrt-dir> <repo-url> [branch] [token]"
need_dir "$OPENWRT_DIR"

PROJECT_DIR="${PROJECT_DIR:-$(project_dir)}"
TEMP_DIR="${OPENWRT_DIR}/.custom-config-temp"
DST_ROOT="${OPENWRT_DIR}/files"
USR_BIN_SRC=""
USR_BIN_DST="$DST_ROOT/usr/bin"

# ===== 辅助函数（来自 stage-overlay.sh）=====

strip_archive_ext() {
  local name="$1"
  case "$name" in
    *.tar.gz)  name="${name%.tar.gz}" ;;
    *.tar.xz)  name="${name%.tar.xz}" ;;
    *.tar.bz2) name="${name%.tar.bz2}" ;;
    *.tar.zst) name="${name%.tar.zst}" ;;
    *.tgz)     name="${name%.tgz}" ;;
    *.txz)     name="${name%.txz}" ;;
    *.tbz2)    name="${name%.tbz2}" ;;
    *.zip)     name="${name%.zip}" ;;
    *.gz)      name="${name%.gz}" ;;
    *.xz)      name="${name%.xz}" ;;
    *.zst)     name="${name%.zst}" ;;
  esac
  printf '%s\n' "$name"
}

is_archive() {
  local path="$1"
  case "${path,,}" in
    *.tar|*.tar.gz|*.tgz|*.tar.xz|*.txz|*.tar.bz2|*.tbz2|*.tar.zst|*.zip|*.gz|*.xz|*.zst)
      return 0
      ;;
  esac
  return 1
}

extract_archive() {
  local archive="$1"
  local dest="$2"
  local base

  mkdir -p "$dest"
  case "${archive,,}" in
    *.tar.gz|*.tgz)     tar -xzf "$archive" -C "$dest" ;;
    *.tar.xz|*.txz)     tar -xJf "$archive" -C "$dest" ;;
    *.tar.bz2|*.tbz2)   tar -xjf "$archive" -C "$dest" ;;
    *.tar.zst)          tar --zstd -xf "$archive" -C "$dest" ;;
    *.tar)              tar -xf "$archive" -C "$dest" ;;
    *.zip)              unzip -q "$archive" -d "$dest" ;;
    *.gz)
      base="$(basename "${archive%.gz}")"
      gzip -dc "$archive" > "$dest/$base"
      ;;
    *.xz)
      base="$(basename "${archive%.xz}")"
      xz -dc "$archive" > "$dest/$base"
      ;;
    *.zst)
      base="$(basename "${archive%.zst}")"
      zstd -dc "$archive" > "$dest/$base"
      ;;
    *) die "Unsupported archive: $archive" ;;
  esac
}

candidate_score() {
  local file_path="$1"
  local preferred="$2"
  local info lower_path lower_base score

  info="$(file -b "$file_path" 2>/dev/null || true)"
  lower_path="${file_path,,}"
  lower_base="$(basename "$lower_path")"
  score=0

  case "$lower_base" in
    readme*|license*|copying*|*.md|*.txt|*.json|*.conf|*.service|*.desktop|*.png|*.jpg|*.jpeg|*.gif|*.svg)
      printf '%s\n' -999
      return
      ;;
  esac

  if [[ "$info" == *ELF* ]]; then
    score=$((score + 100))
    if [[ "${info,,}" == *aarch64* || "${info,,}" == *arm64* ]]; then
      score=$((score + 45))
    elif [[ "${info,,}" == *arm* ]]; then
      score=$((score + 20))
    fi
  elif head -c 2 "$file_path" 2>/dev/null | grep -q '^#!'; then
    score=$((score + 65))
  elif [[ "${info,,}" == *script* ]]; then
    score=$((score + 55))
  else
    printf '%s\n' -999
    return
  fi

  [[ "$lower_path" == *linux* ]] && score=$((score + 10))
  [[ "$lower_path" == *aarch64* || "$lower_path" == *arm64* ]] && score=$((score + 25))
  [[ "$lower_path" == *x86* || "$lower_path" == *amd64* || "$lower_path" == *windows* || "$lower_path" == *darwin* || "$lower_path" == *macos* ]] && score=$((score - 80))
  [[ "$lower_base" == "${preferred,,}" || "$lower_base" == "${preferred,,}"-* || "$lower_base" == "${preferred,,}"_* ]] && score=$((score + 35))
  [[ "$lower_base" != *.* ]] && score=$((score + 8))
  [ -x "$file_path" ] && score=$((score + 5))

  printf '%s\n' "$score"
}

install_detected_binary() {
  local search_dir="$1"
  local preferred="$2"
  local best="" best_score=-999
  local file_path score dest_name

  while IFS= read -r -d '' file_path; do
    score="$(candidate_score "$file_path" "$preferred")"
    if [ "$score" -gt "$best_score" ]; then
      best_score="$score"
      best="$file_path"
    fi
  done < <(find "$search_dir" -type f -print0)

  [ -n "$best" ] && [ "$best_score" -gt 0 ] || die "No executable binary/script found in $search_dir"

  dest_name="$(basename "$best")"
  case "$dest_name" in
    bin|linux|arm64|aarch64|release)
      dest_name="$preferred"
      ;;
  esac

  mkdir -p "$USR_BIN_DST"
  cp "$best" "$USR_BIN_DST/$dest_name"
  chmod 0755 "$USR_BIN_DST/$dest_name"
  log "Installed /usr/bin/$dest_name from ${best#$search_dir/}"
}

# ===== 主逻辑 =====

# 清理旧的临时目录
[ -d "$TEMP_DIR" ] && rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

# 构建认证 URL
if [ -n "$TOKEN" ]; then
  # 支持 HTTPS 令牌认证
  if [[ "$REPO_URL" == https://* ]]; then
    REPO_URL="${REPO_URL#https://}"
    REPO_URL="https://oauth2:${TOKEN}@${REPO_URL}"
  fi
fi

# Clone 私人仓库
echo "正在从 $REPO_URL (分支: $BRANCH) 拉取配置..."
if ! git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$TEMP_DIR" 2>&1; then
  echo "错误: 拉取配置失败。请检查:"
  echo "  1. 仓库 URL 是否正确"
  echo "  2. 分支名称是否存在"
  echo "  3. 令牌是否有效（如果使用私有仓库）"
  exit 1
fi

# 自动检测仓库结构
# 支持两种结构：
# 1. 仓库有 files/ 目录：files/etc, files/usr 等
# 2. 仓库根目录直接包含配置：etc/, usr/, root/ 等任意目录结构
if [ -d "$TEMP_DIR/files" ]; then
  # 结构 1: 有 files/ 目录
  SRC_ROOT="$TEMP_DIR/files"
  echo "检测到仓库结构：使用 files/ 目录"
else
  # 结构 2: 仓库根目录直接是配置根（支持任意目录结构）
  SRC_ROOT="$TEMP_DIR"
  echo "检测到仓库结构：使用仓库根目录"
fi

# 确保目标目录存在
mkdir -p "$DST_ROOT"

# 确定 /usr/bin 源目录
if [ -d "$SRC_ROOT/usr/bin" ]; then
  USR_BIN_SRC="$SRC_ROOT/usr/bin"
fi

# ===== 合并配置文件 =====
echo "正在合并配置文件..."

# 从私人仓库复制文件到目标位置
# 使用 find 以确保正确处理目录结构，排除 /usr/bin（单独处理）
# 忽略 .git 和其他特殊文件
find "$SRC_ROOT" -type f \
  ! -path '*/.git/*' \
  ! -path '*/usr/bin/*' \
  ! -name '.git*' \
  ! -name '.gitkeep' \
  ! -name 'README*' \
  ! -name 'LICENSE*' \
  ! -name '*.md' -print0 | while IFS= read -r -d '' src_file; do
  
  rel_path="${src_file#$SRC_ROOT/}"
  
  # 跳过仓库根目录直接的特殊文件（只在使用仓库根目录时）
  if [ "$SRC_ROOT" = "$TEMP_DIR" ]; then
    case "$rel_path" in
      .git*|README*|LICENSE*|*.md) continue ;;
    esac
  fi
  
  dst_file="$DST_ROOT/$rel_path"
  
  # 创建目标目录
  mkdir -p "$(dirname "$dst_file")"
  
  # 如果目标文件已存在（来自本地 files），跳过
  # 本地 files 目录优先级最高
  if [ -f "$dst_file" ]; then
    echo "跳过 $rel_path (本地文件优先级更高)"
  else
    cp "$src_file" "$dst_file"
    echo "添加 $rel_path"
  fi
done

# ===== 特殊处理 /usr/bin 目录 =====
if [ -n "$USR_BIN_SRC" ] && [ -d "$USR_BIN_SRC" ]; then
  echo "处理 /usr/bin 目录下的文件..."
  
  shopt -s nullglob dotglob
  for item in "$USR_BIN_SRC"/*; do
    base="$(basename "$item")"
    case "$base" in
      .gitkeep|README.md) continue ;;
    esac

    if [ -d "$item" ]; then
      # 如果本地 /usr/bin 已有此目录，跳过（本地优先）
      if [ ! -d "$USR_BIN_DST/$base" ]; then
        install_detected_binary "$item" "$base"
      else
        echo "跳过 /usr/bin/$base (本地版本优先级更高)"
      fi
    elif is_archive "$item"; then
      # 压缩包智能处理：解压后选择最合适的二进制
      preferred="$(strip_archive_ext "$base")"
      # 如果本地已有此文件，跳过
      if [ ! -f "$USR_BIN_DST/$preferred" ]; then
        tmp_dir="$(mktemp -d)"
        extract_archive "$item" "$tmp_dir"
        install_detected_binary "$tmp_dir" "$preferred"
        rm -rf "$tmp_dir"
      else
        echo "跳过 /usr/bin/$preferred (本地版本优先级更高)"
      fi
    elif [ -f "$item" ]; then
      # 如果本地已有此文件，跳过
      if [ ! -f "$USR_BIN_DST/$base" ]; then
        cp "$item" "$USR_BIN_DST/$base"
        chmod 0755 "$USR_BIN_DST/$base"
        log "安装 /usr/bin/$base (直接文件)"
      else
        echo "跳过 /usr/bin/$base (本地版本优先级更高)"
      fi
    else
      warn "忽略不支持的 /usr/bin 项: $item"
    fi
  done
  shopt -u nullglob dotglob
fi

# 清理临时目录
rm -rf "$TEMP_DIR"

echo "配置文件合并完成！"
