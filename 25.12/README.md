UMI UAX3000E — v8.1（基于你同步上游后的 config 重制）
这一版以你 GitHub 上当前的 mt7981-25.12-umi-uax3000e.config 为基础， 保留你从 mt7986-clx-s20p.config 复制过来的有用部分，去掉对 UAX3000E 无用的部分， 再加入 V8 的默认项、WAN 修复、honk UDP 修复和 MT7981 最大功率补丁。

一、你从 clx-s20p 复制过来的代码，逐项判断
配置	对 UAX3000E 是否有用	处理
CONFIG_BPF_TOOLCHAIN_HOST=y	只在源码编译 daed/eBPF 时需要；honk 用预编译 core	删除（省构建时间）
CONFIG_PACKAGE_bpftool=y	同上，运行时诊断才需要	删除
CONFIG_PACKAGE_libcap-bin=y	提供 capsh/getcap，有用且很小	保留
CONFIG_PACKAGE_libcurl=y	很多脚本/插件依赖 curl	保留
CONFIG_PACKAGE_wget-ssl=y	下载工具，有用	保留
CONFIG_PACKAGE_bind-dig=y	dig DNS 诊断，有用	保留
CONFIG_PACKAGE_kmod-ipt-socket=y	老式 iptables socket 匹配，passwall/openclash 用；honk/momo 用 nft	删除
CONFIG_PACKAGE_iptables-mod-socket=y	同上	删除
CONFIG_PACKAGE_kmod-ipt-ipset=y	ipset 是老代理/IPset 分流用；honk/momo 用 nft set	删除
CONFIG_PACKAGE_luci-app-oxidns=y	DoH 客户端，和 honk/momo 的 DNS 接管重复	删除
另外，你的 config 是 v5 基线，缺了 V8 的这些关键项，已补回：

CONFIG_PACKAGE_kmod-nft-offload=y（软件流量卸载）
CONFIG_KERNEL_MPTCP=y
CONFIG_KERNEL_FUNCTION_TRACER=y
CONFIG_KERNEL_DYNAMIC_FTRACE=y（honk UDP 跟踪）
二、WAN 绑定（V7 修复）
files/etc/board.d/03-umi-network：首启 board.json 改为 LAN=lan1 lan2 lan3、WAN=eth1
files/etc/uci-defaults/99-umi-network：升级保留配置时修正 network.wan/wan6.device=eth1，并收敛 br-lan 端口
三、默认项（同 V8）
WiFi：5G TP-ls、2.4G TP-ls2.4，密码 lixiaolan15987359965，psk-mixed
files/lib/wifi/mtwifi.uc 覆盖默认生成器（全新刷机）
files/etc/uci-defaults/99-umi-wireless 升级时只改 ImmortalWrt-* 默认 SSID
全局：MPTCP、tcp_l3mdev、udp_l3mdev、packet_steering=2、steering_flows=128
DNS：rebind_protection=0
防火墙：fullcone=1、fullcone6=1、flow_offloading=1、删除 flow_offloading_hw
四、MT7981 一键最大功率（按你给的 txt）
你已确认 /lib/firmware/MT7981_iPAiLNA_EEPROM.bin 存在（4096 字节），方法可用。

V8.1 的实现是“首次启动 + rc.local 兜底”：

files/usr/sbin/umi-txpwr
检查文件 ≥ 1120 字节
把 5G TX power 的 20 字节（偏移 0x445，MT_EE_TX0_POWER_5G_V2）写成 0x2B
成功后在 /etc/.umi-txpwr-applied 打标记，不重复写
files/etc/uci-defaults/99-umi-txpwr
首次启动先执行一次 /usr/sbin/umi-txpwr
再把 /usr/sbin/umi-txpwr 插到 /etc/rc.local 的 exit 0 之前，作为每次开机的兜底 （防止首次启动时校准文件还没生成）
工作流给 /usr/sbin/umi-txpwr 加 0755
刷完第一次启动后建议再重启一次： 如果首次启动时文件已存在，第一次启动就已经写入；否则由 rc.local 在下一次开机补上。

按你给的 txt，只改 5G 的 20 字节（0x445），2.4G 的 0x441 没有动。

五、会不会影响固件生成？
结论：不会引入新的包冲突，反而少编了一些东西。

删除 bpftool/BPF_TOOLCHAIN_HOST：少编 host bpftool，缩短构建
删除 kmod-ipt-socket/iptables-mod-socket/kmod-ipt-ipset/oxidns：少几个小包，honk/momo 用 nft，不受影响
新增 kmod-nft-offload：本来就是 firewall4 默认依赖，只是显式写上
新增 CONFIG_KERNEL_MPTCP/FUNCTION_TRACER/DYNAMIC_FTRACE：内核多编几个选项，正常
files/ 覆盖层只影响 rootfs 文件，不参与包依赖解析
最大功率脚本只在运行时写 /lib/firmware 文件，不参与编译
唯一需要留意：mtwifi.uc 是覆盖上游无线生成器的文件，以后 mtwifi-cfg 大版本更新时需要重新生成。

六、上传
本地	仓库
25.12/mt7981-25.12-umi-uax3000e.config	同路径覆盖
.github/workflows/25.12-umi-uax3000e.yml	同路径覆盖（必须，仓库里的旧版没有 chmod 步骤）
files/ 整个目录	files/
工作流里的 Fix overlay permissions 会给 uci-defaults、board.d、lib/wifi/mtwifi.uc 加执行权限， 如果只传 config 不传 workflow，uci-defaults 不会执行。

七、当前固件手动生效（可选）
WAN / 全局 / DNS / 防火墙同上一版 README。

最大功率（先确认文件存在）：

sh


ls -l /lib/firmware/MT7981_iPAiLNA_EEPROM.bin
printf '++++++++++++++++++++' > /tmp/txpwr.bin
dd if=/tmp/txpwr.bin of=/lib/firmware/MT7981_iPAiLNA_EEPROM.bin bs=1 seek=$((0x445)) conv=notrunc
sync
reboot
如果 ls 报不存在，就不要执行。
