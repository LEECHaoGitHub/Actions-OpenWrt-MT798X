# UMI UAX3000E — immortalwrt 25.12 构建方案

本目录是给 `LEECHaoGitHub/Actions-OpenWrt-MT798X`（分支 `AI`）准备的
**immortalwrt 25.12 + UMI UAX3000E** 构建文件。

---

## 一、先说结论（很重要）

`chasey-dev/immortalwrt-mt798x-rebase` 的 **25.12 分支里没有 `umi,uax3000e` 这个设备**：

- `target/linux/mediatek/image/filogic.mk` 里没有 `Device/umi_uax3000e`
- `target/linux/mediatek/dts/` 里没有 `mt7981b-umi-uax3000e.dts`

而 24.10 能编译，是因为 `Yuzhii0718/immortalwrt-mt798x-6.6-padavanonly` 这个仓库
自带 UMI 设备（`mt7981b-umi-uax3000e.dts` + `Device/umi_uax3000e`）。

所以，**只放一个 `.config` 是不够的**：`make defconfig` 会把不存在的设备符号直接丢掉，
最后编出来的是默认机型（甚至可能刷错变砖）。

因此本方案包含 3 个文件：配置 + 设备移植（DTS + 设备定义）+ 专用工作流。

---

## 二、为什么不直接选现成的 `cmcc_rax3000m` / `sl_3000-emmc`

UAX3000E 的硬件和 CMCC RAX3000M eMMC 非常接近（MT7981B + 1GB + eMMC + USB3），
但 25.12 里 `cmcc_rax3000m` 用的是 **fit + UBI（`root=/dev/fit0`）** 布局，
UMI 的 U-Boot 则是 **GPT 分区 + `root=PARTLABEL=rootfs`**，两者不兼容，直接刷起不来。

`sl_3000-emmc` 的镜像格式对（sysupgrade-tar），但它的 DTS 是另一块板子的
（512MB 内存、不同的交换芯片/PHY/LED），也不适合。

所以这里按 24.10 的 UMI 设备定义单独移植了一份，镜像格式与你现在能用的 24.10 固件一致。

## 三、需要上传到仓库的文件

| 本地文件 | 上传到仓库的路径 |
|---|---|
| `25.12/mt7981-25.12-umi-uax3000e.config` | `25.12/mt7981-25.12-umi-uax3000e.config` |
| `25.12/umi-uax3000e/mt7981b-umi-uax3000e.dts` | `25.12/umi-uax3000e/mt7981b-umi-uax3000e.dts` |
| `25.12/umi-uax3000e/add-device.sh` | `25.12/umi-uax3000e/add-device.sh` |
| `.github/workflows/25.12-umi-uax3000e.yml` | `.github/workflows/25.12-umi-uax3000e.yml` |

GitHub 网页快速新建（分支选 `AI`）：

- https://github.com/LEECHaoGitHub/Actions-OpenWrt-MT798X/new/AI?filename=25.12/mt7981-25.12-umi-uax3000e.config
- https://github.com/LEECHaoGitHub/Actions-OpenWrt-MT798X/new/AI?filename=25.12/umi-uax3000e/mt7981b-umi-uax3000e.dts
- https://github.com/LEECHaoGitHub/Actions-OpenWrt-MT798X/new/AI?filename=25.12/umi-uax3000e/add-device.sh
- https://github.com/LEECHaoGitHub/Actions-OpenWrt-MT798X/new/AI?filename=.github/workflows/25.12-umi-uax3000e.yml

> 注意：`add-device.sh` 必须是 **LF 换行**（GitHub 网页粘贴保存默认就是 LF）。
> 如果用 Windows 记事本另存，请在编辑器里确认是 LF，避免 `bash: $'\r': command not found`。

---

## 四、构建流程

1. 上传完上面 4 个文件；
2. 打开 **Actions** → 左侧选 **25.12-umi-uax3000e** → **Run workflow**（分支 `AI`）；
3. 构建过程会依次：
   - 克隆 `chasey-dev/immortalwrt-mt798x-rebase` 的 `25.12` 分支
   - 执行原有的 `25.12/diy-part1.sh`（克隆 passwall / nikki / daed / 主题等）
   - 执行 `25.12/umi-uax3000e/add-device.sh` 注入 DTS 与设备定义
   - 载入 `25.12/mt7981-25.12-umi-uax3000e.config`
   - **校验** `CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_umi_uax3000e=y` 是否真的生效
     （不生效会立刻失败并打印当前设备列表，不会白跑 4 小时）
   - 编译并发布到 Release

最终固件名形如：

```
immortalwrt-mediatek-filogic-umi_uax3000e-squashfs-sysupgrade.bin
```

---

## 五、刷机

- 本配置沿用 24.10 的设备布局：**eMMC + GPT 分区（kernel / rootfs）+ sysupgrade-tar**
- U-Boot 网页恢复（`192.168.1.1`）或原厂/不死 U-Boot 的升级页面上传
  `*sysupgrade.bin` 即可
- **默认管理地址是 `192.168.1.1`**：25.12 源码的 `config_generate` 默认就是 192.168.1.1，
  你现有 `25.12/diy-part2.sh` 里的 `sed 's/192.168.6.1/192.168.30.1/'` 在 25.12 上匹配不到，
  不会生效。想改成 `192.168.30.1`，把那条 sed 的 `192.168.6.1` 换成 `192.168.1.1` 即可
- **务必保留 24.10 固件作为回退**；第一次刷 25.12 建议先确认能进 U-Boot 网页再刷

---

## 六、这份配置里有什么

- 设备：`umi_uax3000e`（MT7981B / 1GB DDR3 / 128GB eMMC / USB3.0 / WiFi6 160MHz）
- 1GB 内存：DTS `memory@40000000` 写死 `0x40000000`（1GB）
- eMMC：`kmod-mmc`、`mmc-utils`、ext4/f2fs/exfat/vfat、分区与挂载工具
- USB3.0：`kmod-usb3`、`kmod-usb-storage`、`kmod-usb-storage-uas`（UASP）
- WiFi：MTK `mt_wifi` 闭源驱动 + `mt7981-fw-20260601` 固件 + `mtwifi-cfg`/`datconf`；
  DTS 同时按 25.12 eMMC 设备的通用写法声明了 eMMC `factory` 分区与 `eeprom@0` nvmem
  （若你机器的 GPT 里没有名为 `factory` 的分区，这一段会被忽略，不影响启动）
- 硬件加速：`kmod-mediatek_hnat`、`kmod-warp`、turboacc-mtk、eqos-mtk
- 代理：passwall（含 SingBox / SS-Rust / Hysteria 等）、nikki、daede
- 其他：dockerman、diskman、ttyd、smartdns、upnp、authshield、argon/aurora 主题
- 内核：cgroup v2 + BPF/BTF + XDP（daed、透明代理需要）

> 与 24.10 的差异：25.12 的 `mtwifi-cfg`、`iwinfo`、`datconf` 已改为 ucode 版本，
> 所以包名是 `mtwifi-cfg-ucode`、`iwinfo-ucode`、`ucode-mod-datconf` 等；
> 25.12 里 dae 家族包名是 `luci-app-daede`。

---

## 七、编译太慢 / 想精简

首次编译（无工具链缓存）本来就要 2~4 小时。想更快，把配置里这些改成 `=n`：

```diff
-CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadowsocks_Rust_Server=y
-CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Simple_Obfs=y
-CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadow_TLS=y
-CONFIG_PACKAGE_luci-app-dockerman=y
-CONFIG_PACKAGE_luci-app-nikki=y
```

其中 Rust 组件（shadowsocks-rust / simple-obfs / shadow-tls）最耗时，
`25.12/diy-part2.sh` 还把 Rust 改成 `download-ci-llvm=false`（本地编 LLVM），
所以每多一个 Rust 包都会明显变慢。

---

## 八、出问题怎么排查

| 现象 | 处理 |
|---|---|
| `Verify UMI UAX3000E device selected` 失败 | 说明 `add-device.sh` 没生效：确认脚本在 `25.12/umi-uax3000e/` 下、文件名没拼错、是 LF 换行 |
| 编译报 DTS 错误 | 把 Actions 日志里 `mt7981b-umi-uax3000e.dts` 的报错行发我，多半是 25.12 内核节点名差异 |
| 刷完能启动但没 WiFi | 25.12 的 `mt_wifi` 读 eMMC factory 分区的方式与 24.10 可能不同，需要按日志补 `mediatek,mtd-eeprom`/nvmem 配置 |
| 想先用现有工作流试 | 把 `25.12-mt7981.yml` 的 `CONFIG_FILE` 改成新配置，并在 `Load custom feeds` 步骤后加一行执行 `add-device.sh` 的 step 即可 |
