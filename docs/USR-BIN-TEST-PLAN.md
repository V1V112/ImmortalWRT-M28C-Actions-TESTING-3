# /usr/bin 二进制处理 - 测试计划

## 测试环境准备

### 前置条件

- ✅ Git 已安装
- ✅ Bash 环境（WSL2/Docker/Linux）
- ✅ tar, gzip, xz, unzip 等工具已安装
- ✅ file 命令可用
- ✅ mktemp 命令可用

### 创建测试仓库

```bash
# 创建测试私人仓库
mkdir -p ~/test-openwrt-configs/files/usr/bin
cd ~/test-openwrt-configs

# 初始化 git
git init
git config user.email "test@example.com"
git config user.name "Test User"

# 创建测试二进制
mkdir -p test_bins
```

## 测试用例

### 测试 1：单个 aarch64 ELF 二进制

**目的**：验证直接二进制文件的识别和复制

**步骤**：

```bash
# 1. 创建简单的测试二进制
cat > test_bins/testapp << 'EOF'
#!/bin/bash
echo "Test app for aarch64"
EOF
chmod +x test_bins/testapp

# 2. 复制为 ELF 格式（使用真实的 ELF 二进制）
# 或使用现有的 busybox 等
# 这里假设用脚本代替测试
cp test_bins/testapp files/usr/bin/testapp1

# 3. 提交到 git
git add files/
git commit -m "test: add testapp1"

# 4. 运行脚本
OPENWRT_DIR="/tmp/test-openwrt"
mkdir -p "$OPENWRT_DIR/files"
cd <project-root>
scripts/fetch-custom-config.sh "$OPENWRT_DIR" ~/test-openwrt-configs main

# 5. 验证结果
ls -la "$OPENWRT_DIR/files/usr/bin/"
# 应该看到：testapp1 (755 权限)
```

**预期结果**：
- ✅ testapp1 被复制到目标位置
- ✅ 文件权限为 755
- ✅ 输出显示 "安装 /usr/bin/testapp1 (直接文件)"

---

### 测试 2：压缩包自动解压

**目的**：验证压缩包的识别、解压和最佳二进制选择

**步骤**：

```bash
# 1. 创建两个二进制（模拟不同架构）
# 方式 1：使用 busybox（如果可用）
which busybox && cp /bin/busybox test_bins/testapp2-aarch64 || \
  echo '#!/bin/bash' > test_bins/testapp2-aarch64

# 方式 2：创建带有架构标记的脚本
cat > test_bins/testapp2-aarch64 << 'EOF'
#!/bin/bash
echo "App for aarch64"
EOF
chmod +x test_bins/testapp2-aarch64

cat > test_bins/testapp2-arm << 'EOF'
#!/bin/bash
echo "App for arm"
EOF
chmod +x test_bins/testapp2-arm

# 2. 创建压缩包
cd test_bins
tar -czf testapp2.tar.gz testapp2-aarch64 testapp2-arm README.txt 2>/dev/null || \
  tar -czf testapp2.tar.gz testapp2-aarch64 testapp2-arm
cd ..

# 3. 添加到仓库
mkdir -p files/usr/bin
cp test_bins/testapp2.tar.gz files/usr/bin/
git add files/usr/bin/testapp2.tar.gz
git commit -m "test: add testapp2 archive"

# 4. 运行脚本
OPENWRT_DIR="/tmp/test-openwrt-2"
mkdir -p "$OPENWRT_DIR/files"
cd <project-root>
scripts/fetch-custom-config.sh "$OPENWRT_DIR" ~/test-openwrt-configs main

# 5. 验证结果
ls -la "$OPENWRT_DIR/files/usr/bin/"
# 应该看到：testapp2 (不是 testapp2.tar.gz)
file "$OPENWRT_DIR/files/usr/bin/testapp2"
```

**预期结果**：
- ✅ 压缩包被识别
- ✅ 临时目录用于解压
- ✅ aarch64 版本被选中（而不是 arm）
- ✅ 输出显示 "Installed /usr/bin/testapp2"
- ✅ 目标文件是解压后的脚本，不是压缩包

---

### 测试 3：目录内多个二进制

**目的**：验证目录递归扫描和最佳二进制选择

**步骤**：

```bash
# 1. 创建目录结构
mkdir -p files/usr/bin/testapp3
cat > files/usr/bin/testapp3/app-aarch64 << 'EOF'
#!/bin/bash
echo "aarch64"
EOF
chmod +x files/usr/bin/testapp3/app-aarch64

cat > files/usr/bin/testapp3/app-arm << 'EOF'
#!/bin/bash
echo "arm"
EOF
chmod +x files/usr/bin/testapp3/app-arm

echo "README" > files/usr/bin/testapp3/README

# 2. 提交
git add files/usr/bin/testapp3/
git commit -m "test: add testapp3 directory"

# 3. 运行脚本
OPENWRT_DIR="/tmp/test-openwrt-3"
mkdir -p "$OPENWRT_DIR/files"
cd <project-root>
scripts/fetch-custom-config.sh "$OPENWRT_DIR" ~/test-openwrt-configs main

# 4. 验证结果
ls -la "$OPENWRT_DIR/files/usr/bin/testapp3/"
```

**预期结果**：
- ✅ 目录被递归扫描
- ✅ README 被忽略
- ✅ aarch64 版本被选中
- ✅ 文件被安装为 /usr/bin/testapp3

---

### 测试 4：本地文件优先级

**目的**：验证本地 files 文件优先于私人仓库

**步骤**：

```bash
# 1. 在本地 files/usr/bin 创建文件
mkdir -p files/usr/bin
echo "#!/bin/bash" > files/usr/bin/priority-test
echo "echo local version" >> files/usr/bin/priority-test
chmod +x files/usr/bin/priority-test

# 2. 在私人仓库也创建相同文件
mkdir -p ~/test-openwrt-configs/files/usr/bin
echo "#!/bin/bash" > ~/test-openwrt-configs/files/usr/bin/priority-test
echo "echo remote version" >> ~/test-openwrt-configs/files/usr/bin/priority-test
chmod +x ~/test-openwrt-configs/files/usr/bin/priority-test

cd ~/test-openwrt-configs
git add files/usr/bin/priority-test
git commit -m "test: add priority-test to remote"

# 3. 运行脚本
cd <project-root>
OPENWRT_DIR="/tmp/test-openwrt-priority"
mkdir -p "$OPENWRT_DIR/files"
scripts/fetch-custom-config.sh "$OPENWRT_DIR" ~/test-openwrt-configs main

# 4. 验证结果
cat "$OPENWRT_DIR/files/usr/bin/priority-test"
# 应该显示：echo local version（本地版本）

# 查看日志输出
# 应该包含：跳过 /usr/bin/priority-test (本地版本优先级更高)
```

**预期结果**：
- ✅ 本地文件被保留
- ✅ 私人仓库文件被跳过
- ✅ 日志显示优先级信息

---

### 测试 5：多种压缩格式

**目的**：验证不同压缩格式的支持

**步骤**：

```bash
# 创建测试二进制
cat > test_bins/testapp5 << 'EOF'
#!/bin/bash
echo "format test"
EOF
chmod +x test_bins/testapp5

# 测试各种格式
cd test_bins

# tar.gz
tar -czf testapp5.tar.gz testapp5

# tar.xz（如果 xz 可用）
tar -cJf testapp5.tar.xz testapp5 2>/dev/null || true

# tar.bz2（如果 bzip2 可用）
tar -cjf testapp5.tar.bz2 testapp5 2>/dev/null || true

# zip
zip -q testapp5.zip testapp5 2>/dev/null || true

cd ..

# 将每个格式添加到不同的提交
for fmt in tar.gz tar.xz tar.bz2 zip; do
  [ -f "test_bins/testapp5.$fmt" ] || continue
  
  mkdir -p "files/usr/bin/test-$fmt"
  cp "test_bins/testapp5.$fmt" "files/usr/bin/testapp5-$fmt.$fmt"
  git add "files/usr/bin/testapp5-$fmt.$fmt"
  git commit -m "test: add testapp5-$fmt format"
done

# 运行脚本
OPENWRT_DIR="/tmp/test-openwrt-formats"
mkdir -p "$OPENWRT_DIR/files"
cd <project-root>
scripts/fetch-custom-config.sh "$OPENWRT_DIR" ~/test-openwrt-configs main

# 验证所有格式都被正确处理
ls -la "$OPENWRT_DIR/files/usr/bin/"
# 应该看到所有格式都被解压为相应的文件
```

**预期结果**：
- ✅ 所有支持格式都被正确解压
- ✅ 文件被正确安装
- ✅ 没有错误信息

---

## 故障排查测试

### 测试 A：损坏的压缩包

**目的**：验证错误处理

**步骤**：

```bash
# 创建损坏的压缩包
echo "not a real tar" > files/usr/bin/broken.tar.gz

# 尝试处理
OPENWRT_DIR="/tmp/test-broken"
mkdir -p "$OPENWRT_DIR/files"
cd <project-root>
scripts/fetch-custom-config.sh "$OPENWRT_DIR" ~/test-openwrt-configs main 2>&1

# 应该显示错误信息
```

**预期结果**：
- ✅ 脚本显示错误但不完全失败
- ✅ 其他文件继续被处理

---

### 测试 B：无效的二进制

**目的**：验证评分系统排除无效文件

**步骤**：

```bash
# 创建全是文档的压缩包
mkdir -p test_bins/docs-only
echo "README" > test_bins/docs-only/README.md
echo "LICENSE" > test_bins/docs-only/LICENSE
cd test_bins
tar -czf docs-only.tar.gz docs-only/
cd ..

cp test_bins/docs-only.tar.gz files/usr/bin/
git add files/usr/bin/docs-only.tar.gz
git commit -m "test: docs only archive"

# 运行脚本
OPENWRT_DIR="/tmp/test-no-binary"
mkdir -p "$OPENWRT_DIR/files"
cd <project-root>
scripts/fetch-custom-config.sh "$OPENWRT_DIR" ~/test-openwrt-configs main 2>&1

# 应该显示错误：No executable binary/script found
```

**预期结果**：
- ✅ 脚本识别出没有有效的二进制
- ✅ 显示清晰的错误消息

---

## 自动化测试脚本

创建 `test-usr-bin.sh`：

```bash
#!/bin/bash
set -e

echo "=== /usr/bin 二进制处理测试套件 ==="

# 测试 1: 直接二进制
echo "测试 1: 直接二进制文件..."
# ... 测试代码 ...

# 测试 2: 压缩包
echo "测试 2: 压缩包处理..."
# ... 测试代码 ...

# 测试 3: 目录
echo "测试 3: 目录格式..."
# ... 测试代码 ...

# 测试 4: 优先级
echo "测试 4: 本地优先级..."
# ... 测试代码 ...

echo "=== 所有测试完成 ==="
```

---

## 检查清单

运行测试后，检查以下项目：

- [ ] 所有压缩包被正确解压
- [ ] aarch64 二进制优先被选择
- [ ] 本地文件优先级被保留
- [ ] 文件权限正确设置 (755)
- [ ] README/LICENSE 等文档被排除
- [ ] 错误信息清晰明确
- [ ] 临时目录被清理
- [ ] 不支持的格式显示警告

---

## 性能基准

在不同场景下测试脚本执行时间：

| 场景 | 文件大小 | 预期时间 |
|------|--------|---------|
| 单个 1MB 二进制 | 1MB | < 1 秒 |
| 10MB 压缩包 | 10MB | 1-2 秒 |
| 多个文件 | 总 50MB | 5-10 秒 |

---

## 报告格式

测试结果应包含：

```
测试项目: 测试 X - [描述]
输入: [输入文件/条件]
预期结果: [应该发生什么]
实际结果: [实际发生了什么]
状态: ✅ PASS / ❌ FAIL
注释: [任何其他观察]
```

## 参考资源

- [USR-BIN-BINARY-HANDLING.md](./USR-BIN-BINARY-HANDLING.md) - 详细指南
- [fetch-custom-config.sh](../scripts/fetch-custom-config.sh) - 脚本源码
