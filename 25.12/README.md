# UMI UAX3000E — immortalwrt 25.12 构建方案（v2 修复版）

> 2026-11-10 失败复盘 + 修复说明。设备移植本身没有问题，问题出在 **Rust 依赖下载** 和
> **工作流发布逻辑** 两处。

---

## 一、这次失败的真实原因

### 1. 直接原因：crates.io 下载 Rust 依赖失败

日志（`0_build.txt`）最后一段：

```
make[3]: Entering directory '.../feeds/packages/net/shadowsocks-rust'
  Installing shadowsocks-rust v1.24.0
    Updating crates.io index
error: download of ae/s-/aes-gcm-siv failed

Caused by:
  curl failed

Caused by:
  [16] Error in the HTTP2 framing layer
make[3]: *** [.../shadowsocks-rust-1.24.0/.built] Error 101
```

也就是说：**编译到 4 小时 33 分时，`shadowsocks-rust` 需要从 crates.io 下载
`aes-gcm-siv` 等 crate，GitHub Runner 与 crates.io 的 HTTP/2 连接中断**，包编译失败。

这不是 DTS/设备的问题：日志里 `✅ DTS 已写入`、`✅ 已选中设备: umi_uax3000e` 都正常，
内核也编过了，其他包（含 mihomo、daed、dockerd、hysteria 等）都已编译成功。

### 2. 更严重的问题：编译失败后仍然发布了 Release

工作流里 `Organize files` / `Generate release tag` / `Upload firmware to release`
只判断了 `!cancelled()`，没有判断编译是否成功。于是：

- 编译失败 → 后续步骤照跑
- `cd openwrt/bin/targets/mediatek/filogic` 里当时只有 8 个 `mt7981/7986/7987/7988-ram-*-bl2.bin`
- 这些 bl2 被当成固件发到了 Release：
  `25.12-umi-uax3000e-chasey-dev-25.12-20261110-1021`

**这个 Release 里没有 sysupgrade 固件，千万不要下载刷机。**
请在 Releases 页面把它连同 tag 一起删掉。

---

## 二、v2 修复内容

### 配置 `25.12/mt7981-25.12-umi-uax3000e.config`

| 项目 | v1 | v2 |
|---|---|---|
| `luci-app-passwall_INCLUDE_Shadowsocks_Rust_Client` | `=y` | 关闭 |
| `luci-app-passwall_INCLUDE_Shadowsocks_Rust_Server` | `=y` | 关闭 |
| `luci-app-passwall_INCLUDE_Simple_Obfs` | `=y` | 关闭 |
| `luci-app-passwall_INCLUDE_Shadow_TLS` | `=y` | 关闭 |
| Shadowsocks / SS2022 | SS-Rust | **SingBox（Go）** |

保留：SingBox、Hysteria、NaiveProxy、V2ray-Plugin、Geoview、Haproxy、OpenClash、
Nikki、daed、dockerman、diskman、lucky、openlist2 等你开启的组件。

> SingBox 本身完整支持 Shadowsocks / SS2022 / VMess / Trojan / Hysteria2，
> 关掉 SS-Rust 不影响日常使用，反而少下载一堆 Rust crate、构建更快更稳。

### 工作流 `.github/workflows/25.12-umi-uax3000e.yml`

1. **编译失败不再发布**：
   `Organize files`、`Generate release tag`、`Upload firmware to release`、
   `Remove old releases` 全部加上 `steps.compile.outputs.status == 'success'`。
2. **发布前硬校验固件**：`Organize files` 里检查
   `*umi_uax3000e*sysupgrade.bin` 是否存在，不存在立即失败，绝不发空 Release。
3. **Release 只上传本机型文件**：`*umi_uax3000e*.bin/.manifest/.img.gz/.tar.gz`，
   不会再混入 bl2 等无关文件。
4. **重试退避**：编译失败后等 30s/60s 再试，给网络自愈时间。
5. **cargo 容错**（以后若重新开启 Rust 有用）：
   `CARGO_HTTP_MULTIPLEXING=false`、`CARGO_NET_RETRY=10`、
   `CARGO_HTTP_TIMEOUT=120`、`CARGO_NET_GIT_FETCH_WITH_CLI=true`。

### 未改动

- `25.12/umi-uax3000e/mt7981b-umi-uax3000e.dts`
- `25.12/umi-uax3000e/add-device.sh`

这两个文件已验证可用（设备注入成功、DTS 编译通过），不需要重传。

---

## 三、上传

覆盖仓库里的这两个文件即可：

| 本地文件 | 仓库路径 |
|---|---|
| `25.12/mt7981-25.12-umi-uax3000e.config` | `25.12/mt7981-25.12-umi-uax3000e.config` |
| `.github/workflows/25.12-umi-uax3000e.yml` | `.github/workflows/25.12-umi-uax3000e.yml` |

可选：把本 README 覆盖到 `25.12/README.md`。

---

## 四、重新构建

Actions → **25.12-umi-uax3000e** → Run workflow（分支 `AI`）。

日志里确认这几行：

```
✅ 已选中设备: umi_uax3000e
✅ 待发布固件: immortalwrt-mediatek-filogic-umi_uax3000e-squashfs-sysupgrade.bin
```

产物：

```
immortalwrt-mediatek-filogic-umi_uax3000e-squashfs-sysupgrade.bin
```

编译时间预计 3.5~4.5 小时（比 v1 少掉 Rust 部分）。

---

## 五、刷机

- U-Boot 网页恢复：`192.168.1.1`，上传 `*sysupgrade.bin`
- 进入系统后 LAN 地址：**`192.168.2.1`**
  （你同步后的 `25.12/diy-part2.sh` 已把默认 `192.168.1.1` 改成 `192.168.2.1`）
- 首次刷 25.12 前保留 24.10 固件作为回退

---

## 六、如果确实需要 SS-Rust

把配置里那 4 行改回 `=y` 即可，工作流已加 cargo 重试/HTTP1.1 容错；
但 crates.io 属于外部网络，仍可能偶发失败，且构建时间会增加。
建议先用 v2 跑通一次，再按需开启。
