# 快速开始指南 - 私人配置仓库集成

## 5 分钟快速设置

### 步骤 1: 在 GitHub 创建私人仓库

```bash
# 创建仓库名称：openwrt-configs（可自定义）
# 访问: https://github.com/new
# 选择: Private
# 初始化: 勾选 "Add a README file"
```

### 步骤 2: 获取访问令牌

1. 访问: https://github.com/settings/tokens/new
2. 配置:
   - Token name: `ImmortalWRT Config Access`
   - Expiration: `90 days` (按需调整)
   - Select scopes: `repo`
3. 复制 token，保存在安全的地方

### 步骤 3: 在此项目中创建 Secret

1. 进入项目 → Settings → Secrets and variables → Actions
2. 点击 "New repository secret"
3. 名称: `CUSTOM_CONFIG_TOKEN`
4. 值: 粘贴从步骤 2 获得的 token
5. 保存

### 步骤 4: 推送配置到私人仓库

```bash
# 初始化私人仓库（选一个）

# 方法 A: 直接在 Web UI 创建目录结构
# 在 GitHub Web UI 创建以下文件夹结构：
# - files/
#   - etc/
#     - config/
#   - usr/
#     - bin/

# 方法 B: 使用 Git（推荐）
git clone https://github.com/YOUR_USERNAME/openwrt-configs.git
cd openwrt-configs

# 创建目录结构
mkdir -p files/etc/config files/usr/bin

# 复制现有配置（可选）
# cp -r <path-to-ImmortalWRT>/files/* ./files/

git add .
git commit -m "initial: create openwrt configuration structure"
git push origin main
```

### 步骤 5: 修改 GitHub Actions 工作流

编辑 `.github/workflows/build-immortalwrt.yml`，修改"放置自定义 overlay 文件"步骤：

**原代码:**
```yaml
      - name: 放置自定义 overlay 文件
        run: |
          scripts/stage-overlay.sh "$OPENWRT_DIR"
```

**新代码:**
```yaml
      - name: 放置自定义 overlay 文件
        env:
          CUSTOM_CONFIG_REPO_URL: https://github.com/YOUR_USERNAME/openwrt-configs.git
          CUSTOM_CONFIG_BRANCH: main
          CUSTOM_CONFIG_TOKEN: ${{ secrets.CUSTOM_CONFIG_TOKEN }}
        run: |
          chmod +x scripts/prepare-overlay.sh
          scripts/prepare-overlay.sh "$OPENWRT_DIR"
```

**记得替换:**
- `YOUR_USERNAME`: 你的 GitHub 用户名

### 步骤 6: 测试构建

1. 进入项目 → Actions → 编译 ImmortalWrt M28C 固件
2. 点击 "Run workflow"
3. 等待编译完成

✅ 完成！现在你的 OpenWrt 配置存储在私人仓库中了。

---

## 常用命令

### 更新私人仓库中的配置

```bash
cd openwrt-configs

# 编辑配置
vim files/etc/config/network

# 提交更改
git add .
git commit -m "update: network configuration"
git push origin main

# 下次构建会自动使用新配置
```

### 本地测试脚本

```bash
# 设置环境变量
export CUSTOM_CONFIG_REPO_URL="https://github.com/YOUR_USERNAME/openwrt-configs.git"
export CUSTOM_CONFIG_BRANCH="main"
export CUSTOM_CONFIG_TOKEN="your_token_here"

# 创建临时 OpenWrt 目录
mkdir -p /tmp/openwrt-test/workdir/immortalwrt
export OPENWRT_DIR="/tmp/openwrt-test/workdir/immortalwrt"

# 运行脚本（调试）
bash -x scripts/fetch-custom-config.sh "$OPENWRT_DIR" "$CUSTOM_CONFIG_REPO_URL" "$CUSTOM_CONFIG_BRANCH" "$CUSTOM_CONFIG_TOKEN"
```

### 本地 files 优先级测试

```bash
# 在本地 files 中创建测试文件
echo "local version" > files/etc/config/test.conf

# 在私人仓库中创建不同版本
# (在 Web UI 或本地仓库中)

# 执行脚本后，查看结果
# 应该显示：本地文件保留，私人仓库文件被跳过
```

---

## 调试

### 检查 Token 是否有效

```bash
# 在终端测试
TOKEN="your_token_here"
REPO="openwrt-configs"
USERNAME="your_username"

curl -H "Authorization: token $TOKEN" \
  https://api.github.com/repos/$USERNAME/$REPO
```

预期输出应该包含仓库信息，而不是错误。

### 查看工作流日志

1. 进入项目 → Actions
2. 选择最近的工作流运行
3. 点击 "Logs" → 查找 "正在从私人仓库拉取配置..."
4. 检查是否有错误信息

---

## 完整项目结构参考

```
ImmortalWRT-M28C-Actions-TESTING/
├── .github/
│   └── workflows/
│       ├── build-immortalwrt.yml (原始)
│       └── build-immortalwrt-with-private-config.yml (新增，带私人仓库支持)
├── scripts/
│   ├── fetch-custom-config.sh (新增)
│   ├── prepare-overlay.sh (新增)
│   ├── stage-overlay.sh (原始)
│   └── ...其他脚本
├── files/
│   ├── etc/
│   ├── usr/
│   └── www/
├── docs/
│   ├── MAINTENANCE.md (原始)
│   └── PRIVATE-REPO-INTEGRATION.md (新增，完整指南)
└── README.md

your-openwrt-configs/ (私人仓库)
├── files/
│   ├── etc/
│   │   ├── config/
│   │   │   ├── network
│   │   │   ├── firewall
│   │   │   └── ...
│   │   ├── mosdns/
│   │   └── smartdns/
│   └── usr/
│       └── bin/
├── README.md
└── .gitignore
```

---

## 下一步

- 详细文档: 阅读 [`docs/PRIVATE-REPO-INTEGRATION.md`](../docs/PRIVATE-REPO-INTEGRATION.md)
- 高级配置: 支持多分支、多仓库等
- 本地开发: 在本地编译环境中使用脚本

---

**遇到问题？** 检查 [`docs/PRIVATE-REPO-INTEGRATION.md`](../docs/PRIVATE-REPO-INTEGRATION.md) 中的"故障排查"部分。
