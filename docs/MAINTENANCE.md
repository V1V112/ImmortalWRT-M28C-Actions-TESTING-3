# Maintenance Notes

## 目录职责

`.github/workflows/build-immortalwrt.yml` 只负责 CI 流程。能放到配置文件和脚本里的东西都不要直接写死在 workflow 里。

`profiles/m28c/target.config` 只放目标、内核和全局 Kconfig。

`profiles/m28c/packages.txt` 只放软件包选择。

`feeds/third-party.feeds` 放默认第三方 feeds，`feeds/custom.feeds` 放你后续自己追加的 feeds。

`feeds/package-sources.conf` 放不适合作为 feed 添加、需要直接克隆到 `package/custom` 的源码包，比如第三方 MosDNS 和 fancontrol。

`local-packages/` 放你自己维护的本地 OpenWrt 包源码。

`files/` 是固件 rootfs overlay。`files/etc` 对应 `/etc`，`files/usr/bin` 对应 `/usr/bin`。

## 常见修改

切换 ImmortalWrt 版本：运行 Actions 时修改 `immortalwrt_ref`。默认是 `openwrt-25.12`。

固定某个第三方包版本：把 `feeds/package-sources.conf` 或 `feeds/third-party.feeds` 里的分支名改成 tag 或 commit 可取到的 ref。

添加源码包：如果是 feed，写到 `feeds/custom.feeds`；如果是单包仓库，写到 `feeds/package-sources.conf`；如果是本地包，放到 `local-packages/`。

追加二进制工具：直接放可执行文件、目录或压缩包到 `files/usr/bin/`。目录和压缩包会优先选择 Linux aarch64/arm64 ELF，其次选择脚本。

## 编译失败排查顺序

1. 看 `Generate .config` 步骤，确认关键包是否被选中。
2. 如果提示 unknown package，检查包名是否真的存在，或第三方 feed 是否拉取成功。
3. 如果 MosDNS 和上游自带包冲突，检查 `prepare-packages.sh` 是否已删除 `package/feeds/packages/mosdns`。
4. 如果 Go 包编译失败，优先确认 ImmortalWrt 当前分支的 `feeds/packages/lang/golang` 版本是否满足第三方包要求。
5. 如果 `/usr/bin` 压缩包识别错了，改成直接放目标二进制文件，或者把压缩包内不需要的其它平台文件删掉。
