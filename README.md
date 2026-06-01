# ImmortalWrt M28C GitHub Actions Builder

这是一个面向 Widora / MangoPi M28C 的 ImmortalWrt 自动编译项目。仓库通过 GitHub Actions 拉取 ImmortalWrt 源码，合并本项目中的目标配置、软件包列表、第三方源码包、本地软件包、内核补丁和 rootfs overlay，然后生成可下载的 M28C 固件。

## 构建目标

- ImmortalWrt 分支：默认 `openwrt-25.12`
- 设备平台：`rockchip/armv8`
- 设备型号：`widora_mangopi-m28c`
- 固件格式：`squashfs`
- rootfs 分区：`1024 MB`
- 镜像压缩：启用 `gzip`
- 构建缓存：启用 `ccache`

## 固件特性

### 基础系统

- 基于 ImmortalWrt 构建，目标设备固定为 Widora / MangoPi M28C。
- 默认只编译 M28C 单设备 profile，避免生成无关设备镜像。
- 使用 SquashFS rootfs，并生成 gzip 压缩镜像。
- rootfs 分区默认设置为 `1024 MB`，适合内置较多插件和 WebUI 资源。
- 启用构建日志和 ccache，便于 GitHub Actions 上排错和加速后续构建。

### LuCI 与管理界面

- 内置 LuCI Web 管理界面：`luci`、`luci-base`、`luci-ssl`。
- 内置中文语言包：`luci-i18n-base-zh-cn`。
- 内置 Argon 主题及配置页：`luci-theme-argon`、`luci-app-argon-config`。
- 内置网页终端：`ttyd`、`luci-app-ttyd`。
- 预置多个 `/etc/config/` 配置文件，可在刷入后直接获得较完整的初始配置。

### 网络与防火墙

- 使用 Firewall4 / nftables 体系。
- 内置 nftables、NAT、flow offload、TProxy、socket match 等相关内核模块。
- 内置 `ip-full`、`tc-full`、`ethtool`、`curl`、`wget-ssl` 等常用网络工具。
- 内置 `kmod-tcp-bbr`，支持 BBR 拥塞控制。
- 内置 `kmod-tun`、`kmod-ifb`、`kmod-sched-*` 等流量控制和代理常用模块。

### 5G 模块支持

- 面向华为 MT5700 / 常见 USB 5G 模块预置驱动和管理组件。
- 内置 USB 串口相关模块：`kmod-usb-serial`、`kmod-usb-serial-option`、`kmod-usb-serial-wwan`、`kmod-usb-acm`、`kmod-usb-wdm`。
- 内置多种拨号链路支持：QMI、MBIM、NCM、Huawei NCM、RNDIS、CDC ECM。
- 内置拨号工具和协议支持：`uqmi`、`umbim`、`comgt`、`comgt-ncm`、`wwan`、`luci-proto-qmi`、`luci-proto-mbim`。
- 内置 QModem Next：`qmodem`、`luci-app-qmodem-next`、中文语言包和短信转发组件。
- 内置 MT5700 AT WebServer / WebUI 相关本地包，便于通过网页查看和调试模块 AT 功能。
- 附带 MT5700 USB 串口识别补丁：`999-usb-serial-option-add-mt5700-3466-3301.patch`。

### DNS 与代理

- 内置 SmartDNS：`smartdns`、`smartdns-ui`、`luci-app-smartdns`、中文语言包。
- 内置 MosDNS：`mosdns`、`luci-app-mosdns`、中文语言包。
- 内置 v2ray geodata：`v2ray-geoip`、`v2ray-geosite`、`v2dat`。
- 内置 momo 透明代理相关包：`momo`、`luci-app-momo`、中文语言包。
- `files/etc/momo/`、`files/etc/mosdns/`、`files/etc/smartdns/` 中带有对应 overlay 配置和资源。

### 硬件与外设

- 内置 Rockchip / M28C 相关支持包。
- 内置 AIC8800 SDIO 无线相关模块：`kmod-aic8800-sdio`。
- 内置 USB 2.0 / USB 3.0 / USB 存储 / USB 网卡基础支持。
- 内置 `block-mount`，支持挂载外部存储。
- 内置 `usbutils`、`pciutils`，便于查看外设识别情况。
- 内置 `wpad-openssl`，提供较完整的 Wi-Fi 加密能力。

### 风扇与温控

- M28C 上游 DTS 已声明 `pwm-fan`。
- 固件内置 `kmod-hwmon-pwmfan`。
- 仓库通过 Rockchip DTS 补丁固定默认 PWM 风扇曲线，由内核 thermal 框架自动调速。

### eBPF / BTF 能力

- 启用内核调试信息和 BTF：`CONFIG_KERNEL_DEBUG_INFO`、`CONFIG_KERNEL_DEBUG_INFO_BTF`。
- 启用 BPF events、cgroups、cgroup BPF、XDP sockets。
- 内置 `bpftool`。
- 适合需要 eBPF、CO-RE、XDP 或高级网络调试能力的场景。

## 快速使用

1. 将本仓库推送到自己的 GitHub 仓库。
2. 打开仓库页面的 `Actions`。
3. 选择 M28C 固件编译 workflow，并点击 `Run workflow`。
4. 选择 ImmortalWrt 版本：
   - `openwrt-25.12`：默认分支
   - `v25.12.0-rc2`：指定版本标签
   - `master`：上游主分支
   - `custom`：自定义分支、标签或 commit，需要填写 `custom_ref`
5. 等待编译完成后，在本次 workflow 的 `Artifacts` 中下载固件。

产物名称类似：

```text
immortalwrt-<run_number>-m28c-<ref>
```

产物内容：

- `targets/`：固件镜像、manifest、buildinfo、sha256sums 等文件。
- `config.build`：本次编译使用的最终 `.config`。
- `packages/`：仅当运行 workflow 时启用 `upload_packages` 才会上传。

## Workflow 参数

| 参数 | 说明 |
| --- | --- |
| `immortalwrt_version` | 选择 ImmortalWrt 分支或标签，默认 `openwrt-25.12` |
| `custom_ref` | 当版本选择 `custom` 时填写，例如某个分支、标签或 commit |
| `profile` | 构建配置方案，目前只有 `m28c` |
| `extra_feeds` | 临时追加 OpenWrt feed，每行一个 `src-git` 配置 |
| `extra_packages` | 临时追加或禁用软件包，包名前加 `-` 表示禁用 |
| `extra_config` | 临时追加原始 Kconfig 配置行 |
| `upload_packages` | 是否额外上传 `bin/packages` |
| `verbose_fallback` | 编译失败后是否用 `make -j1 V=s` 重新输出详细日志 |

## 仓库结构

```text
.
|-- .github/workflows/             # GitHub Actions 编译流程
|   `-- build-immortalwrt.yml
|-- configs/                       # 额外 Kconfig 配置
|   `-- custom.config
|-- docs/                          # 补充维护文档
|-- feeds/                         # 第三方 feed 和单包源码声明
|   |-- custom.feeds
|   |-- package-sources.conf
|   `-- third-party.feeds
|-- files/                         # rootfs overlay，内容会进入固件根目录
|   |-- etc/
|   |-- usr/bin/
|   `-- www/
|-- local-packages/                # 本地 OpenWrt 软件包源码
|-- patches/kernel/generic/        # 追加到上游源码的通用内核补丁
|-- patches/kernel/rockchip/       # 追加到 Rockchip 平台的内核补丁
|-- profiles/m28c/                 # M28C 构建 profile
|   |-- packages.txt               # 默认内置软件包列表
|   `-- target.config              # 目标平台和固件格式配置
|-- scripts/                       # workflow 调用的辅助脚本
|-- .gitattributes
|-- .gitignore
`-- README.md
```

### `.github/workflows/`

保存 GitHub Actions 编译流程。

- `build-immortalwrt.yml`：主 workflow。负责解析版本参数、释放磁盘空间、安装依赖、拉取 ImmortalWrt、恢复缓存、合并 feeds、准备软件包、应用补丁、注入 overlay、生成 `.config`、下载源码、编译固件并上传 Artifacts。

### `configs/`

保存额外 Kconfig 配置。

- `custom.config`：追加到 profile 配置之后的原始 `.config` 片段。适合放无法写成软件包名的配置项。

### `docs/`

保存补充维护文档。

- `MAINTENANCE.md`：项目维护说明和后续记录入口。

### `feeds/`

保存第三方源码来源声明。

- `third-party.feeds`：项目默认启用的 OpenWrt feed。
- `custom.feeds`：个人追加或后期维护的 OpenWrt feed。
- `package-sources.conf`：单包源码仓库列表，不走 OpenWrt feeds 机制，直接克隆后放入 ImmortalWrt 源码树。

`third-party.feeds` 和 `custom.feeds` 会被 `scripts/add-feeds.sh` 合并到上游 `feeds.conf.default`。`package-sources.conf` 会被 `scripts/prepare-packages.sh` 处理。

### `files/`

保存 rootfs overlay。这里的路径会映射到固件根目录。

- `files/etc/config/`：预置 UCI 配置，例如网络、防火墙、LuCI、SmartDNS、MosDNS、QModem、momo、ttyd 等。
- `files/etc/momo/`：momo 运行目录、缓存和 WebUI 资源。
- `files/etc/mosdns/`：MosDNS 相关配置和资源。
- `files/etc/smartdns/`：SmartDNS 相关配置。
- `files/etc/sysctl.d/`：系统内核参数配置。
- `files/usr/bin/`：注入到固件 `/usr/bin/` 的可执行文件。普通文件会自动加执行权限；目录或压缩包会扫描并挑选 arm64 / aarch64 Linux 可执行文件。
- `files/www/luci-static/`：Web 静态资源覆盖或补充。

示例映射：

```text
files/etc/config/network  ->  /etc/config/network
files/usr/bin/example     ->  /usr/bin/example
files/www/luci-static/x   ->  /www/luci-static/x
```

### `local-packages/`

保存本地 OpenWrt 软件包源码。workflow 会复制到 ImmortalWrt 源码目录的 `package/local/`。

当前包含：

- `luci-app-fancontrol-main/`：风扇控制程序和 LuCI 页面源码，当前默认不编入固件。
- `mt5700webui-openwrt-server-main/`：MT5700 AT WebServer 和对应 LuCI / WebUI 资源。

支持的目录结构：

```text
local-packages/<package-name>/Makefile
local-packages/<collection>/<package-name>/Makefile
```

只有包源码存在还不够，仍需把包名写进 `profiles/m28c/packages.txt` 才会被编入固件。

### `patches/`

保存构建时追加到 ImmortalWrt 源码树的补丁。

- `patches/kernel/generic/`：通用内核补丁目录。
- `patches/kernel/rockchip/`：Rockchip 平台内核补丁目录。
- 当前补丁：`999-usb-serial-option-add-mt5700-3466-3301.patch`，用于补充 MT5700 USB 串口识别。

`scripts/stage-kernel-patches.sh` 会自动检测 rockchip 目标使用的 `KERNEL_PATCHVER`，并把通用补丁复制到 `target/linux/generic/hack-<kernel-version>/`，把 Rockchip 平台补丁复制到 `target/linux/rockchip/patches-<kernel-version>/`。通用补丁目录不存在时会回退到 `target/linux/generic/hack/`。

### `profiles/`

保存设备 profile。

- `profiles/m28c/target.config`：M28C 目标平台、固件格式、rootfs 大小、ccache、eBPF / BTF 等基础构建配置。
- `profiles/m28c/packages.txt`：默认内置软件包列表。每行可写一个或多个包名，包名前加 `-` 表示禁用。

### `scripts/`

保存 workflow 调用的脚本。

- `common.sh`：公共函数，如日志、错误退出、路径检测。
- `add-feeds.sh`：合并 `feeds/*.feeds` 和 workflow 的 `extra_feeds`，并跳过重复 feed。
- `prepare-packages.sh`：克隆 `package-sources.conf` 中的单包源码，复制 `local-packages/` 中的本地包，并移除上游冲突包。
- `stage-kernel-patches.sh`：把 `patches/kernel/generic/*.patch` 和 `patches/kernel/rockchip/*.patch` 放入 ImmortalWrt 内核补丁目录。
- `stage-overlay.sh`：把 `files/` 注入 ImmortalWrt 的 rootfs overlay，并特殊处理 `files/usr/bin/`。
- `generate-config.sh`：合并 `target.config`、`packages.txt`、`configs/custom.config`、`extra_packages` 和 `extra_config`，生成最终 `.config`。

## 修改软件包

长期固定的软件包建议写入：

```text
profiles/m28c/packages.txt
```

常见写法：

```text
luci-app-example
-luci-app-unwanted
+luci-app-explicit
```

含义：

- `luci-app-example`：启用该软件包。
- `-luci-app-unwanted`：禁用该软件包。
- `+luci-app-explicit`：显式启用该软件包。

临时测试可以在运行 GitHub Actions 时填写 `extra_packages`，格式相同。

如果需要追加原始 Kconfig 行，可以写入：

```text
configs/custom.config
```

也可以在 workflow 的 `extra_config` 中临时追加。

## 添加第三方源码

### 添加 OpenWrt feed

长期默认 feed 写入：

```text
feeds/third-party.feeds
```

个人维护或临时实验 feed 写入：

```text
feeds/custom.feeds
```

格式：

```text
src-git myfeed https://github.com/example/openwrt-packages.git;main
```

### 添加单包源码仓库

单包仓库写入：

```text
feeds/package-sources.conf
```

格式：

```text
<name> <repo-url> <ref> <destination-dir> <source-subdir>
```

当前默认单包源码：

- `mosdns`：`https://github.com/sbwml/luci-app-mosdns.git`
- `v2ray-geodata`：`https://github.com/sbwml/v2ray-geodata.git`
- `momo`：`https://github.com/nikkinikki-org/OpenWrt-momo.git`
- `qmodem`：`https://github.com/FUjr/QModem.git`

## 本地调试参考

GitHub Actions 中的主要构建步骤等价于：

```bash
git clone https://github.com/immortalwrt/immortalwrt.git immortalwrt
cd immortalwrt
git checkout <ref>
cd ..

export OPENWRT_DIR="$PWD/immortalwrt"
export PROJECT_DIR="$PWD"

chmod +x scripts/*.sh
scripts/add-feeds.sh "$OPENWRT_DIR"
cd "$OPENWRT_DIR"
./scripts/feeds update -a
./scripts/feeds install -a
cd "$PROJECT_DIR"

scripts/prepare-packages.sh "$OPENWRT_DIR"
scripts/stage-kernel-patches.sh "$OPENWRT_DIR"
scripts/stage-overlay.sh "$OPENWRT_DIR"
scripts/generate-config.sh "$OPENWRT_DIR" "profiles/m28c"

cd "$OPENWRT_DIR"
make defconfig
make download -j"$(nproc)"
make -j"$(nproc)"
```

## 常见维护入口

- 修改默认软件包：编辑 `profiles/m28c/packages.txt`。
- 修改目标平台或固件格式：编辑 `profiles/m28c/target.config`。
- 添加个人 feed：编辑 `feeds/custom.feeds`。
- 添加单包源码仓库：编辑 `feeds/package-sources.conf`。
- 添加本地 OpenWrt 包：放入 `local-packages/`。
- 覆盖系统配置文件：放入 `files/etc/`。
- 添加可执行文件：放入 `files/usr/bin/`。
- 添加 Web 静态资源：放入 `files/www/`。
- 添加通用内核补丁：放入 `patches/kernel/generic/`。
- 添加 Rockchip 平台内核补丁：放入 `patches/kernel/rockchip/`。
- 追加原始 Kconfig：编辑 `configs/custom.config`。

## 参考项目

- ImmortalWrt: https://github.com/immortalwrt/immortalwrt
- Momo: https://github.com/nikkinikki-org/OpenWrt-momo
- MosDNS: https://github.com/sbwml/luci-app-mosdns
- QModem: https://github.com/FUjr/QModem
- Fan Control: https://github.com/rockjake/luci-app-fancontrol
