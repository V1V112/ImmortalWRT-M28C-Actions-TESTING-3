# 本地 OpenWrt 软件包

把本地 OpenWrt 软件包源码目录放在这里：

```text
local-packages/
  luci-app-example/
    Makefile
    root/
```
在 CI 编译过程中，每个目录都会在生成 .config 之前被复制到 package/local/<名称>。

然后你需要把软件包名称添加到 profiles/m28c/packages.txt，或者填写到 GitHub Actions 工作流的 extra_packages 输入框中。