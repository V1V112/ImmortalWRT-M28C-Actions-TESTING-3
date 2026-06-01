# /usr/bin 二进制文件处理 - 快速参考

## 最简快速开始

### 场景 1：单个压缩的二进制

在私人仓库中添加：
```
files/usr/bin/myapp.tar.gz
```

包含内容：
```
myapp.tar.gz
├── myapp-aarch64  ← 会被自动选中（最佳分数）
├── myapp-arm
└── README.md      ← 自动忽略
```

**结果**：编译时自动解压并安装 `myapp-aarch64` 为 `/usr/bin/myapp`

### 场景 2：目录格式多个二进制

```
files/usr/bin/mytool/
├── mytool-aarch64
├── mytool-arm
└── mytool-x86_64  # 不会被选中（架构不兼容）
```

**结果**：自动选择 `mytool-aarch64`

### 场景 3：脚本文件

```
files/usr/bin/myscript
```

（需要有 shebang `#!/bin/bash` 或 `#!/bin/sh`）

**结果**：直接复制并设置执行权限

## 支持的格式

| 格式 | 示例 | 支持 |
|------|------|------|
| .tar.gz | `app.tar.gz` | ✅ |
| .tar.xz | `app.tar.xz` | ✅ |
| .tar.bz2 | `app.tar.bz2` | ✅ |
| .tar.zst | `app.tar.zst` | ✅ |
| .zip | `app.zip` | ✅ |
| 直接二进制 | `app` (ELF) | ✅ |
| 脚本 | `app` (#!/bin/bash) | ✅ |
| 目录 | `app/` (包含二进制) | ✅ |

## 评分系统速查表

**快速判断优先级**：

| 优先级 | 条件 | 得分 |
|--------|------|------|
| 第 1 名 | ELF + aarch64 | 170+ |
| 第 2 名 | ELF + arm | 120+ |
| 第 3 名 | 脚本 | 65+ |
| 被忽略 | README/LICENSE/MD5 | -999 |

## 常见问题速答

### Q1: 如何让特定版本优先？

**答**：在文件名中包含架构信息
```
myapp-aarch64        # +45 分（架构）+ 35 分（名字匹配）= +80 分
myapp-arm            # +20 分（架构）+ 35 分（名字匹配）= +55 分
```

### Q2: 压缩包里多个文件怎么办？

**答**：系统自动选择得分最高的
```
app.tar.gz
├── linux/aarch64/myapp  # +100 +45 +10 = +155 ✅ 选中
├── windows/myapp.exe    # +100 -80 = +20  ❌ 不选
└── README               # -999            ❌ 忽略
```

### Q3: 本地文件会被覆盖吗？

**答**：不会。本地优先级最高

```
本地 files/usr/bin/myapp       ← 保留
私人仓库 /usr/bin/myapp.tar.gz ← 被跳过
```

### Q4: 如何调试选择结果？

**答**：运行脚本时查看输出
```bash
bash -x scripts/fetch-custom-config.sh \
  /path/to/openwrt \
  <repo-url> main <token>
```

查找 "Installed /usr/bin/" 的输出行

## 最佳实践速记

1. ✅ **规范命名**
   ```
   myapp              # 通用版本
   myapp-aarch64      # 特定架构（推荐）
   myapp-linux-aarch64 # 完整标识
   ```

2. ✅ **压缩包内容**
   ```
   app.tar.gz
   ├── app-aarch64   # 包含需要的二进制
   └── app-arm       # 无需要的杂文件
   ```

3. ✅ **文件格式**
   ```bash
   file ./myapp
   # 应该显示: ELF 64-bit ... aarch64
   
   # 或脚本：
   head -c 2 ./myscript
   # 应该显示: #!/
   ```

4. ✅ **权限设置**
   ```bash
   chmod +x myapp    # 二进制需要执行权限
   chmod +x script   # 脚本也需要
   ```

## 目录结构模板

推荐的私人仓库结构：

```
your-private-repo/
├── files/
│   ├── etc/
│   │   └── config/
│   │       ├── network
│   │       └── firewall
│   └── usr/
│       └── bin/
│           ├── app1.tar.gz       ← 压缩包格式
│           ├── app2              ← 直接二进制
│           ├── script1            ← 脚本
│           └── tools/             ← 目录格式
│               ├── tool-aarch64
│               └── tool-arm
├── README.md
└── .gitignore
```

## 故障排查树

```
问题：压缩包未被解压
├─ 检查：是否为支持的格式？ .tar.gz? .zip?
├─ 检查：包内是否有二进制？
│  └─ 运行 tar -tzf app.tar.gz
└─ 检查：二进制格式是否有效？
   └─ 运行 file <binary>

问题：选了错误的版本
├─ 检查：文件名中有架构信息吗？
├─ 检查：ELF 文件头中的架构标记
└─ 启用调试看详细评分

问题：脚本执行失败
├─ 检查：脚本有没有 shebang (#!)?
├─ 检查：脚本是否有执行权限？
└─ 检查：是否为 DOS 行尾？
   └─ 运行 dos2unix script
```

## 参考资源

- **完整指南**：[USR-BIN-BINARY-HANDLING.md](./USR-BIN-BINARY-HANDLING.md)
- **集成指南**：[PRIVATE-REPO-INTEGRATION.md](./PRIVATE-REPO-INTEGRATION.md)
- **脚本源码**：[fetch-custom-config.sh](../scripts/fetch-custom-config.sh)

## 更新历史

| 版本 | 日期 | 变更 |
|------|------|------|
| 1.1.0 | 2026-05-24 | 添加 /usr/bin 二进制智能处理 |
| 1.0.0 | 2026-05-23 | 初始版本 |
