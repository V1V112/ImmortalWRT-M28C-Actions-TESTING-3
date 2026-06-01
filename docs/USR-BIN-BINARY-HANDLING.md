# /usr/bin 二进制文件智能处理指南

## 概述

ImmortalWRT 编译系统支持对 `/usr/bin` 目录下的二进制文件进行智能识别和处理。这个特性确保无论二进制文件如何打包（直接文件、压缩包、目录），系统都能正确识别和安装最合适的版本。

## 核心特性

### 1. 自动解压支持格式

系统支持以下压缩格式的自动解压：

| 格式 | 扩展名 | 说明 |
|------|--------|------|
| gzip 压缩包 | `.tar.gz`, `.tgz` | 使用 `tar -xzf` |
| xz 压缩包 | `.tar.xz`, `.txz` | 使用 `tar -xJf` |
| bzip2 压缩包 | `.tar.bz2`, `.tbz2` | 使用 `tar -xjf` |
| zstd 压缩包 | `.tar.zst` | 使用 `tar --zstd -xf` |
| tar 归档 | `.tar` | 使用 `tar -xf` |
| zip 格式 | `.zip` | 使用 `unzip` |
| 单文件 gzip | `.gz` | 使用 `gzip -dc` |
| 单文件 xz | `.xz` | 使用 `xz -dc` |
| 单文件 zstd | `.zst` | 使用 `zstd -dc` |

### 2. 智能二进制评分系统

系统根据以下因素对候选二进制进行评分，并选择分数最高的版本：

#### 文件类型评分（最高优先级）
- **ELF 二进制**：+100 分（最佳）
- **脚本**（shebang `#!`）：+65 分（次佳）
- **脚本**（文件命令识别）：+55 分
- **其他**：-999 分（拒绝）

#### 架构优先级
- **aarch64/arm64**（匹配 M28C 架构）：+45 分（ELF）或 +25 分（路径匹配）
- **arm**：+20 分
- **x86/amd64/Windows/macOS**：-80 分（不兼容，降低评分）
- **Linux**（路径中包含）：+10 分

#### 文件特征
- **名称匹配**（匹配提示名称）：+35 分
- **无扩展名**：+8 分（通常是可执行文件）
- **可执行权限**：+5 分

#### 被排除的文件
文件类型包含以下内容时自动排除（-999 分）：
- `README*`, `LICENSE*`, `COPYING*`
- `*.md`, `*.txt`, `*.json`, `*.conf`, `*.service`, `*.desktop`
- `*.png`, `*.jpg`, `*.jpeg`, `*.gif`, `*.svg`

### 3. 处理流程

```
对于 /usr/bin 下的每个项目：
│
├─ 如果是目录
│  └─ 递归查找目录中的二进制
│     └─ 评分并安装最佳候选
│
├─ 如果是压缩包
│  ├─ 解压到临时目录
│  ├─ 递归查找解压后的二进制
│  ├─ 评分并安装最佳候选
│  └─ 清理临时目录
│
├─ 如果是普通文件
│  └─ 直接复制并设置执行权限 (755)
│
└─ 其他
   └─ 显示警告信息
```

## 实现位置

### 相关脚本

1. **stage-overlay.sh** - 本地文件处理
   - 函数：`stage_usr_bin()`, `install_detected_binary()`, `candidate_score()` 等
   - 位置：`scripts/stage-overlay.sh`

2. **fetch-custom-config.sh** - 私人仓库处理
   - 函数：相同的辅助函数集合
   - 位置：`scripts/fetch-custom-config.sh`

### 辅助函数

| 函数 | 说明 |
|------|------|
| `strip_archive_ext()` | 去除文件名中的压缩包扩展名 |
| `is_archive()` | 检测文件是否为压缩包 |
| `extract_archive()` | 解压压缩包到指定目录 |
| `candidate_score()` | 评分单个候选二进制 |
| `install_detected_binary()` | 递归搜索、评分、安装最佳二进制 |

## 使用场景

### 场景 1：单个压缩二进制

**目录结构**：
```
files/usr/bin/
└── myapp.tar.gz      # 包含多个可执行文件
    ├── bin/myapp
    ├── bin/myapp-aarch64
    └── bin/myapp-arm
```

**行为**：
1. 检测 `myapp.tar.gz` 为压缩包
2. 解压到临时目录
3. 扫描所有二进制文件
4. 评分：aarch64 版本得分最高 (+100+45+25 = +170)
5. 安装 `myapp-aarch64` 到 `/usr/bin/myapp`

### 场景 2：目录中的多个二进制

**目录结构**：
```
files/usr/bin/
└── myapp/
    ├── myapp                # ELF, arm
    ├── myapp-aarch64        # ELF, aarch64
    └── README.md            # 被忽略
```

**行为**：
1. 检测 `myapp` 为目录
2. 扫描目录中的文件
3. README.md 被排除（-999 分）
4. aarch64 版本得分最高
5. 安装 `myapp-aarch64` 到 `/usr/bin/myapp`

### 场景 3：本地文件优先级

**本地 files 结构**：
```
files/usr/bin/
├── myapp              # 本地版本
└── otherapp.tar.gz
```

**私人仓库结构**：
```
files/usr/bin/
├── myapp.tar.gz       # 被忽略（本地优先）
└── otherapp.tar.gz    # 已被本地优先级检查，若本地不存在则使用
```

**行为**：
1. `myapp` 本地版本被保留（优先级最高）
2. 私人仓库的 `myapp.tar.gz` 被跳过
3. `otherapp.tar.gz` 正常处理（本地不存在）

## 配置私人仓库

### 推荐结构：使用 files/ 目录

```
your-private-repo/
├── files/
│   ├── etc/
│   │   └── config/
│   │       └── network
│   └── usr/
│       └── bin/
│           ├── app1.tar.gz
│           ├── app2
│           └── app3/
│               ├── app3-aarch64
│               └── app3-arm
├── README.md
└── LICENSE
```

### 替代结构：直接根目录

```
your-private-repo/
├── etc/
│   └── config/
│       └── network
├── usr/
│   └── bin/
│       ├── app1.tar.gz
│       ├── app2
│       └── app3/
├── README.md
└── LICENSE
```

**系统会自动检测结构并相应处理。**

## 故障排查

### 问题：压缩包未被解压

**检查项**：
1. 确保文件扩展名正确（`.tar.gz`, `.tar.xz` 等）
2. 确保压缩包内至少有一个可执行文件（ELF 或脚本）
3. 检查输出日志中是否有错误信息

**解决方案**：
```bash
# 手动验证压缩包内容
tar -tzf your-app.tar.gz

# 检查二进制文件类型
file your-app-aarch64
```

### 问题：选择了错误的二进制版本

**原因分析**：
- 检查文件名中是否包含架构信息（aarch64, arm64, arm）
- 检查 ELF 文件头中的架构标记
- 查看日志输出的评分过程

**调试方法**：
```bash
# 查看脚本的详细输出
bash -x fetch-custom-config.sh <openwrt-dir> <repo-url>
```

### 问题：本地文件被覆盖

**原因**：未启用本地优先级保护

**检查**：
- `fetch-custom-config.sh` 应该在复制前检查本地文件是否存在
- `stage-overlay.sh` 排除 `/usr/bin` 使用 rsync `--exclude='/usr/bin'`

## 性能考虑

- **解压时间**：大型压缩包可能需要数秒
- **评分过程**：O(n) 复杂度，其中 n 是压缩包内的文件数
- **临时空间**：需要足够的临时目录空间来解压压缩包

## 限制和注意事项

1. **权限管理**：安装的二进制将被设置为 `0755`（可读写执行）
2. **符号链接**：不支持压缩包内的符号链接（会被复制为常规文件）
3. **大型压缩包**：建议将大型二进制分解为更小的压缩包
4. **架构不匹配**：如果没有找到合适的架构，系统将退出并报错

## 最佳实践

1. **使用一致的命名约定**
   ```
   app              # 通用版本（如果只有一个）
   app-aarch64      # 特定架构版本
   app-arm
   app-linux-x86_64 # 完整标识符
   ```

2. **压缩包组织**
   ```
   # 好的做法
   app-1.0-aarch64.tar.gz   # 单一架构
   
   # 也可以
   app-1.0.tar.gz           # 包含多个架构（系统自动选择）
       ├── app-aarch64
       ├── app-arm
       └── README
   ```

3. **文件大小**
   - 压缩包大小 < 100 MB：可以接受
   - 直接二进制 < 50 MB：最优
   - 如超过此限制，考虑进行优化或分层

4. **版本管理**
   - 在文件名中包含版本号
   - 在 README 中文档化版本信息
   - 使用 Git 标签进行版本控制

## 参考

- [OpenWrt 官方文档](https://openwrt.org/)
- [ImmortalWRT 项目](https://github.com/immortalwrt/immortalwrt)
- [私人配置集成指南](./PRIVATE-REPO-INTEGRATION.md)
