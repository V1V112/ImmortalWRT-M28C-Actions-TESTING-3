# OpenWrt 配置管理 - 私人仓库集成指南

## 概述

本指南说明如何将 OpenWrt 配置文件管理从本地 `files` 目录迁移到私人仓库，同时保持本地配置的最高优先级。

## 架构设计

### 优先级层次（从高到低）

1. **本地 `files` 目录**（最高优先级）- 用于覆盖和快速测试
2. **私人仓库配置** - 用于集中管理和版本控制
3. **OpenWrt 默认配置**（最低优先级）

### 工作流程

```
开始构建
    ↓
├─→ 拉取私人仓库配置 (可选)
│   └─→ 合并到临时 files 目录
│       (本地文件优先级更高，不被覆盖)
│   
├─→ 应用内核补丁
│
├─→ 执行 overlay staging
│   (将本地 files 目录复制到 OpenWrt)
│
├─→ 生成 .config 配置
│
└─→ 编译固件
```

## 快速开始

### 第一步：创建私人仓库

在 GitHub/Gitee 上创建一个私人仓库用于存储 OpenWrt 配置：

```bash
# 示例仓库结构
openwrt-configs/
├── files/
│   ├── etc/
│   │   ├── config/
│   │   │   ├── network
│   │   │   ├── firewall
│   │   │   └── mosdns/
│   │   │       └── config_custom.yaml
│   │   ├── mosdns/
│   │   │   ├── mosdns_custom/
│   │   │   └── rules/
│   │   └── smartdns/
│   │       └── custom.conf
│   └── usr/
│       └── bin/
│           └── custom-scripts/
├── README.md
└── .gitignore
```

### 第二步：推送初始配置

```bash
# 初始化私人仓库
git clone <your-private-repo-url> openwrt-configs
cd openwrt-configs
mkdir -p files/etc/config
mkdir -p files/usr/bin

# 从现有项目复制配置（可选）
cp -r <existing-project>/files/* ./files/

# 提交并推送
git add .
git commit -m "initial: add openwrt configurations"
git push origin main
```

### 第三步：获取 GitHub Token

如果私人仓库是私密的，需要 GitHub Personal Access Token 用于认证：

1. 访问 https://github.com/settings/tokens
2. 点击 "Generate new token" → "Generate new token (classic)"
3. 配置：
   - Scopes: 选择 `repo` (完整仓库访问)
   - 有效期：根据需要选择
4. 复制生成的 token，稍后会用到

### 第四步：配置 GitHub Actions Secret

在原项目的仓库设置中配置 Secret：

1. 进入项目 → Settings → Secrets and variables → Actions
2. 创建以下 Secret（如果使用私人仓库）：
   - `CUSTOM_CONFIG_TOKEN`: 粘贴从步骤 3 获得的 token

### 第五步：修改 GitHub Actions 工作流

编辑 `.github/workflows/build-immortalwrt.yml`，在 **"准备 feeds 和自定义软件包"** 步骤之后，**"应用内核补丁"** 步骤之前，添加拉取私人配置的步骤：

**原配置：**
```yaml
      - name: 应用内核补丁
        run: |
          scripts/stage-kernel-patches.sh "$OPENWRT_DIR"

      - name: 放置自定义 overlay 文件
        run: |
          scripts/stage-overlay.sh "$OPENWRT_DIR"
```

**改为：**
```yaml
      - name: 应用内核补丁
        run: |
          scripts/stage-kernel-patches.sh "$OPENWRT_DIR"

      - name: 放置自定义 overlay 文件
        env:
          CUSTOM_CONFIG_REPO_URL: https://github.com/YOUR_USERNAME/openwrt-configs.git
          CUSTOM_CONFIG_BRANCH: main
          CUSTOM_CONFIG_TOKEN: ${{ secrets.CUSTOM_CONFIG_TOKEN }}
        run: |
          chmod +x scripts/prepare-overlay.sh
          scripts/prepare-overlay.sh "$OPENWRT_DIR"
```

**说明：**
- 将 `YOUR_USERNAME` 替换为你的 GitHub 用户名
- 私人仓库配置必须包含 `files/` 目录
- `CUSTOM_CONFIG_BRANCH` 默认为 `main`，可根据需要修改

## 高级配置

### 添加工作流输入参数

为了在构建时灵活选择配置源，可以在工作流中添加输入参数：

```yaml
on:
  workflow_dispatch:
    inputs:
      # ... 现有参数 ...
      
      custom_config_repo:
        description: "（可选）自定义 OpenWrt 配置仓库 URL"
        required: false
        type: string
        default: "https://github.com/YOUR_USERNAME/openwrt-configs.git"
      
      custom_config_branch:
        description: "配置仓库分支"
        required: false
        type: string
        default: "main"

# ... 在 env 部分 ...
env:
  # ... 现有变量 ...
  CUSTOM_CONFIG_REPO_URL: ${{ inputs.custom_config_repo }}
  CUSTOM_CONFIG_BRANCH: ${{ inputs.custom_config_branch }}
```

### 支持多种私人仓库

脚本支持任何 Git 仓库：

- GitHub 私人仓库：`https://github.com/username/repo.git`
- Gitee 私人仓库：`https://gitee.com/username/repo.git`
- 自建 GitLab：`https://gitlab.example.com/group/project.git`
- SSH 地址：`git@github.com:username/repo.git`（需要配置 SSH key）

### 禁用私人仓库配置

如果只想使用本地 `files` 目录：

```yaml
      - name: 放置自定义 overlay 文件
        run: |
          scripts/stage-overlay.sh "$OPENWRT_DIR"
```

或者在 `.github/workflows/build-immortalwrt.yml` 中，不设置 `CUSTOM_CONFIG_REPO_URL` 环境变量。

## 配置迁移指南

### 从本地 files 到私人仓库的迁移步骤

**第 1 阶段：并行运行**（推荐 1-2 周）

- 保持本地 `files` 目录完整
- 在私人仓库维护相同的配置副本
- 本地测试：只用本地 `files`，验证功能
- GitHub Actions：同时使用私人仓库配置

**第 2 阶段：逐步迁移**

1. 将稳定配置迁移到私人仓库
2. 保留实验性配置在本地 `files`
3. 更新私人仓库的版本号和说明

**第 3 阶段：清理本地 files**（可选）

如果完全迁移到私人仓库，可以：

```bash
# 保留 files 目录结构，但清空内容
rm -rf files/etc/*
rm -rf files/usr/*
echo ".gitkeep" > files/.gitkeep

git add files/
git commit -m "chore: archive openwrt configurations to private repo"
git push
```

## 最佳实践

### 1. 版本控制

在私人仓库中使用 Git 标签管理配置版本：

```bash
# 标记稳定版本
git tag -a v1.0-openwrt-25.12 -m "openwrt 25.12 stable configuration"
git push origin v1.0-openwrt-25.12

# 在工作流中指定特定版本
CUSTOM_CONFIG_BRANCH: v1.0-openwrt-25.12
```

### 2. 敏感信息管理

**不要在配置仓库中存储：**
- WiFi 密码（使用占位符，构建时替换）
- API 密钥和令牌
- 个人信息（IP、域名等）

**推荐做法：**

```bash
# 在 files/etc/config/ 中使用占位符
# network 文件示例
config interface 'lan'
    option proto 'static'
    option ipaddr '192.168.1.1'
    option netmask '255.255.255.0'
    # 实际 WiFi 密码在构建时注入

# 在工作流中使用 Secret 替换
```

### 3. 定期备份

```bash
# 定期从本地 files 同步到私人仓库
cd /path/to/openwrt-configs
cp -r /path/to/ImmortalWRT-M28C-Actions-TESTING/files/* ./
git add .
git commit -m "sync: update from local build environment"
git push
```

### 4. 配置文件注释

在配置文件中添加说明：

```bash
# /files/etc/config/network
# M28C Router Configuration
# Updated: 2025-05-23
# Description: Primary LAN configuration

config interface 'lan'
    # ...
```

## 故障排查

### 问题 1：拉取私人仓库失败

**错误信息：**
```
错误: 拉取配置失败。请检查:
  1. 仓库 URL 是否正确
  2. 分支名称是否存在
  3. 令牌是否有效（如果使用私有仓库）
```

**解决方案：**

1. 验证仓库 URL：
   ```bash
   git clone <repo-url> /tmp/test-clone
   ```

2. 检查 GitHub Secret 配置：
   - 确认 `CUSTOM_CONFIG_TOKEN` 已设置
   - 验证 token 有效（未过期）
   - 检查 token 权限包含 `repo` scope

3. 检查分支名称是否正确

### 问题 2：本地 files 文件被覆盖

**症状：** 本地配置被私人仓库配置覆盖

**原因：** 脚本逻辑反转

**解决方案：** 检查 `fetch-custom-config.sh` 中的优先级逻辑：

```bash
# 正确的逻辑：存在则跳过
if [ -f "$dst_file" ]; then
  echo "跳过 $rel_path (本地文件优先级更高)"
else
  cp "$src_file" "$dst_file"
fi
```

### 问题 3：权限错误

**错误信息：** `Permission denied` 或 `Cannot remove`

**解决方案：**

```bash
# 在本地调试环境中运行
bash -x scripts/prepare-overlay.sh /path/to/openwrt

# 检查文件权限
ls -la files/
```

### 问题 4：/usr/bin 中的二进制无法正确识别

**症状：**
- 压缩包未被解压，直接被复制到固件
- 错误的架构版本被选中（如选了 ARM 而不是 aarch64）
- 脚本执行失败，显示 "No executable binary/script found"

**原因：**
1. 压缩包内文件格式不被识别（不是 ELF 二进制或脚本）
2. 所有候选文件评分都是负数（文档、配置等）
3. 压缩包损坏或格式不支持

**解决方案：**

1. **验证压缩包内容：**
   ```bash
   # 查看压缩包结构
   tar -tzf your-app.tar.gz
   
   # 检查文件类型
   file your-app-aarch64
   unzip -l your-app.zip
   ```

2. **确保包含有效的可执行文件：**
   ```bash
   # 验证是否为 ELF 二进制
   file /path/to/binary
   # 应该显示: ELF 64-bit LSB executable, ARM aarch64...
   
   # 或验证是否为脚本
   head -c 2 /path/to/script
   # 应该显示 shebang: #!/
   ```

3. **避免在压缩包中包含不必要的文件：**
   ```bash
   # 不好的做法（会导致多个候选，可能选错）
   app.tar.gz
   ├── README.md           # 会被自动忽略
   ├── LICENSE
   ├── app-arm
   ├── app-aarch64
   └── app-x86_64          # 得分低，但不会完全排除
   
   # 好的做法（只包含需要的二进制）
   app.tar.gz
   ├── app-arm
   └── app-aarch64
   ```

4. **调试脚本评分过程：**
   ```bash
   # 启用详细输出
   bash -x scripts/fetch-custom-config.sh \
     /path/to/openwrt \
     https://github.com/your/repo.git \
     main \
     your_token
   
   # 查看输出中的"评分"部分来诊断问题
   ```

5. **参考完整指南：**
   - 详见 [/usr/bin 二进制文件智能处理指南](./USR-BIN-BINARY-HANDLING.md)

## 脚本参考

### /usr/bin 二进制文件智能识别

> **新功能**（v1.1.0+）：智能处理 `/usr/bin` 目录下的压缩二进制文件

#### 支持的场景

1. **压缩包自动解压**（.tar.gz, .tar.xz, .tar.bz2, .tar.zst, .zip 等）
2. **智能二进制评分**（基于文件类型、架构、名称等）
3. **自动架构选择**（优先 aarch64 > arm > 其他）
4. **目录递归扫描**（支持多层目录结构）

#### 工作原理

当 `fetch-custom-config.sh` 处理私人仓库配置时：

```
对于 /usr/bin 下的每个文件/目录：

1. 如果是压缩包 (.tar.gz 等)
   ├─ 解压到临时目录
   ├─ 扫描所有文件并评分
   └─ 安装评分最高的二进制

2. 如果是目录
   ├─ 递归扫描目录中的文件
   └─ 安装评分最高的二进制

3. 如果是普通文件
   ├─ 直接复制
   └─ 设置执行权限 (755)

4. 保留本地优先级
   └─ 本地 /usr/bin 中已存在的文件不被覆盖
```

#### 评分系统

| 因素 | 分数 |
|------|------|
| **文件类型** | |
| ELF 二进制 | +100 |
| 脚本 (shebang #!) | +65 |
| 其他脚本 | +55 |
| **架构** (ELF 文件) | |
| aarch64/arm64 | +45 |
| arm | +20 |
| x86/amd64 | -80 |
| **特征** | |
| 文件名匹配提示 | +35 |
| 无扩展名 | +8 |
| 可执行权限 | +5 |
| 路径含 linux | +10 |
| 路径含 aarch64/arm64 | +25 |

#### 示例

**私人仓库结构：**
```
files/usr/bin/
├── app1.tar.gz           # 包含多个架构版本
│   ├── app1-aarch64
│   ├── app1-arm
│   └── README
└── app2/                 # 目录格式
    ├── app2-aarch64
    └── app2-arm
```

**编译结果：**
```
/usr/bin/
├── app1                  # 来自 app1.tar.gz 中的 aarch64 版本
└── app2                  # 来自 app2 目录中的 aarch64 版本
```

#### 详细文档

参考 [/usr/bin 二进制文件智能处理指南](./USR-BIN-BINARY-HANDLING.md) 获取完整说明。

---

### fetch-custom-config.sh

从私人仓库拉取配置文件。

**用法：**
```bash
scripts/fetch-custom-config.sh <openwrt-dir> <repo-url> [branch] [token]
```

**参数：**
- `openwrt-dir`: OpenWrt 源码目录
- `repo-url`: 私人仓库 URL
- `branch`: 分支名称（默认：main）
- `token`: 认证令牌（可选，私人仓库必需）

**返回值：**
- `0`: 成功
- `1`: 失败（仓库不存在或认证失败）

### prepare-overlay.sh

综合脚本，支持拉取私人仓库后执行标准 overlay 操作。

**用法：**
```bash
scripts/prepare-overlay.sh <openwrt-dir>
```

**环境变量：**
- `CUSTOM_CONFIG_REPO_URL`: 私人仓库 URL（可选）
- `CUSTOM_CONFIG_BRANCH`: 分支名称（默认：main）
- `CUSTOM_CONFIG_TOKEN`: 认证令牌（可选）

## 示例配置

### 示例 1：完整的 GitHub Actions 配置

参考 [GitHub Actions 工作流示例](#)

### 示例 2：本地测试

```bash
# 在本地克隆项目
git clone <project-url> ImmortalWRT-M28C-Actions-TESTING
cd ImmortalWRT-M28C-Actions-TESTING

# 模拟拉取私人配置（需要已配置的私人仓库）
CUSTOM_CONFIG_REPO_URL="https://github.com/YOUR_USERNAME/openwrt-configs.git"
CUSTOM_CONFIG_BRANCH="main"
CUSTOM_CONFIG_TOKEN="your_token_here"

# 创建 OpenWrt 目录用于测试
mkdir -p /tmp/openwrt-test/workdir/immortalwrt
export OPENWRT_DIR="/tmp/openwrt-test/workdir/immortalwrt"

# 执行脚本
scripts/fetch-custom-config.sh "$OPENWRT_DIR" "$CUSTOM_CONFIG_REPO_URL" "$CUSTOM_CONFIG_BRANCH" "$CUSTOM_CONFIG_TOKEN"
```

## 常见问题 (FAQ)

### Q: 能否同时使用多个私人仓库？

A: 当前脚本仅支持单一私人仓库。如需多个源，可以：
1. 在私人仓库中按目录组织（如 `files/v1/`, `files/v2/`）
2. 修改脚本以支持多仓库（见进阶开发指南）

### Q: 私人仓库的更新多久生效？

A: 在下次运行 GitHub Actions 工作流时立即生效。

### Q: 如何恢复到仅使用本地 files？

A: 在工作流中移除 `CUSTOM_CONFIG_REPO_URL` 的设置，工作流将跳过私人仓库拉取。

### Q: Token 泄露了怎么办？

A: 立即访问 https://github.com/settings/tokens 删除该 token，并重新生成新 token。

## 相关文档

- [OpenWrt 官方文档](https://openwrt.org)
- [ImmortalWrt 项目](https://immortalwrt.org)
- [GitHub Actions 文档](https://docs.github.com/en/actions)

---

**最后更新：** 2025-05-23  
**作者：** OpenWrt Configuration Management Script

