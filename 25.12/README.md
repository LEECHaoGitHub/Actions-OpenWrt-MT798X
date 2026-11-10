UMI UAX3000E — immortalwrt 25.12 构建方案（v4：honk + momo 专用精简版）
目标：只保留 luci-app-honk 和 luci-app-momo 两个代理程序， 其余代理程序及其专用依赖全部关闭，缩短构建时间、减小固件体积。

一、v4 改了什么
保留的代理
包	说明
luci-app-honk + honk	eBPF 透明代理（dae 后继），honk-core 由工作流下载作者预编译包，不需要 zig/rust
luci-app-momo + momo + sing-box	momo 基于 sing-box，依赖 sing-box 本体
v2ray-geoip / v2ray-geosite	honk 所需 geo 数据（由 v2ray-geodata 源码生成）
关闭的代理
代码块


luci-app-openclash
luci-app-passwall / passwall2
luci-app-ssr-plus
luci-app-nikki / nikki-rs
luci-app-daede / daed / dae
luci-app-homeproxy
一并移除的专用依赖（共 55 项）
仅 passwall/openclash 用到的 iptables 扩展： iptables-mod-*、kmod-ipt-*（socket/ipset/tee/u32/ipmark/iprange/hashlimit/iface/proto/ipopt/nat-extra/raw6/filter/extra/conntrack-extra/compat-xtables/offload）
ipset / libipset / kmod-ipt-ipset
ip6tables-extra / kmod-ip6tables-extra
kmod-sched-act-mirred、tc-mod-iptables
bpftool、BPF_TOOLCHAIN_HOST（honk 用预编译 core，不再需要）
luci-app-smartdns（会和 honk/momo 抢 DNS，见下）
新增/保留的 honk + momo 依赖
honk：kmod-sched-core、kmod-sched-bpf、kmod-nft-queue、kmod-veth、v2ray-geoip/geosite
momo：sing-box、kmod-nft-tproxy、kmod-nft-socket、kmod-inet-diag、kmod-tun、kmod-dummy、firewall4、ip-full
smartdns 为什么关掉
honk 有自己的 dns.dae，momo/sing-box 也会接管 DNS。smartdns 再监听 53 会互相抢端口， 所以 v4 默认关闭；如果你确实需要，把配置里那行改回 CONFIG_PACKAGE_luci-app-smartdns=y 即可。

没有动的部分
docker（dockerman）、diskman、ttyd、upnp、authshield、lucky、openlist2、主题、 USB3/eMMC/文件系统支持等非代理插件都保留，避免影响你原来的使用习惯。

二、honk 的 honk-core 怎么来
工作流里的 Prepare prebuilt honk-core 仍然有效：

读 honk/Makefile 的 PKG_VERSION（当前 2026.11.09~6484888）；
下载作者同版本的 aarch64_generic 预编译包；
解出 usr/bin/honk-core（已验证是 AArch64 静态 ELF）；
放进 honk/files/honk-core.bin，构建时 --if-needed 直接复用。
所以不需要 zig、bpf-linker、nightly Rust，也不会访问 crates.io。

三、上传
本地文件	仓库路径
25.12/mt7981-25.12-umi-uax3000e.config	25.12/mt7981-25.12-umi-uax3000e.config
.github/workflows/25.12-umi-uax3000e.yml	.github/workflows/25.12-umi-uax3000e.yml
工作流与 v3 相同（含 honk 预编译步骤）。如果你已经上传过 v3 工作流，只需覆盖 config； 否则两个都传。mt7981b-umi-uax3000e.dts 和 add-device.sh 没有改动。

四、重新构建
Actions → 25.12-umi-uax3000e → Run workflow。

日志应出现：

代码块


✅ 已选中设备: umi_uax3000e
honk 版本: 2026.11.09~6484888 (release 1)
✅ 已放置预编译 honk-core，honk 将跳过 zig/rust 编译
...
✅ 待发布固件: immortalwrt-mediatek-filogic-umi_uax3000e-squashfs-sysupgrade.bin
去掉 passwall/openclash/daed/nikki 后，构建时间预计 1~1.5 小时（比上一轮 1h41m 更短）。

五、刷机
U-Boot 网页恢复：192.168.1.1，上传 *sysupgrade.bin
进入系统后 LAN：192.168.2.1（同步后的 25.12/diy-part2.sh 已改）
首次刷 25.12 前保留 24.10 固件回退
honk 与 momo 都会接管 DNS/防火墙，建议先启用其中一个、确认正常后再启用另一个， 避免两者的 nft/路由规则互相覆盖。
