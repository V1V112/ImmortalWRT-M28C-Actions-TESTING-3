#!/usr/bin/env bash

# OpenWrt 构建集成脚本
# 支持从私人仓库拉取配置并与本地 files 目录合并
# 
# 环境变量:
#   CUSTOM_CONFIG_REPO_URL: 私人配置仓库 URL (可选)
#   CUSTOM_CONFIG_BRANCH: 私人配置仓库分支，默认: main
#   CUSTOM_CONFIG_TOKEN: GitHub/Gitee Token，用于私有仓库认证 (可选)
#
# 用法: prepare-overlay.sh <openwrt-dir>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$SCRIPT_DIR/common.sh"

OPENWRT_DIR="${1:-${OPENWRT_DIR:-}}"
[ -n "$OPENWRT_DIR" ] || die "Usage: $0 <openwrt-dir>"
need_dir "$OPENWRT_DIR"

PROJECT_DIR="${PROJECT_DIR:-$(project_dir)}"

# 从私人仓库拉取配置（可选）
REPO_URL="${CUSTOM_CONFIG_REPO_URL:-}"
if [ -n "$REPO_URL" ]; then
  BRANCH="${CUSTOM_CONFIG_BRANCH:-main}"
  TOKEN="${CUSTOM_CONFIG_TOKEN:-}"
  
  log "从私人仓库拉取配置文件..."
  "$SCRIPT_DIR/fetch-custom-config.sh" "$OPENWRT_DIR" "$REPO_URL" "$BRANCH" "$TOKEN" || {
    warn "无法从私人仓库拉取配置，继续使用本地 files 目录"
  }
fi

# 执行标准的 overlay 阶段
log "执行标准 overlay 阶段..."
"$SCRIPT_DIR/stage-overlay.sh" "$OPENWRT_DIR"

log "Overlay 准备完成"
