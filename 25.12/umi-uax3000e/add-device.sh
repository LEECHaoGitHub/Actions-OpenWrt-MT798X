#!/bin/bash
#
# 为 immortalwrt 25.12 (chasey-dev/immortalwrt-mt798x-rebase) 增加 UMI UAX3000E 设备支持
# 说明：25.12 源码内没有 umi,uax3000e 这个设备，本脚本负责：
#       1) 写入 target/linux/mediatek/dts/mt7981b-umi-uax3000e.dts
#       2) 在 target/linux/mediatek/image/filogic.mk 追加 Device/umi_uax3000e
# 执行目录：openwrt 源码根目录（GitHub Actions 中由 workflow 自动 cd 进入）
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(pwd)"

DTS_SRC="$SCRIPT_DIR/mt7981b-umi-uax3000e.dts"
DTS_DST="$ROOT_DIR/target/linux/mediatek/dts/mt7981b-umi-uax3000e.dts"
MK="$ROOT_DIR/target/linux/mediatek/image/filogic.mk"

echo "=========================================="
echo "注入 UMI UAX3000E 设备支持"
echo "  源码目录: $ROOT_DIR"
echo "  DTS 来源: $DTS_SRC"
echo "=========================================="

if [ ! -f "$DTS_SRC" ]; then
	echo "❌ 未找到 DTS 文件: $DTS_SRC"
	exit 1
fi

if [ ! -f "$MK" ]; then
	echo "❌ 未找到 $MK，当前目录可能不是 openwrt 源码根目录"
	exit 1
fi

# ---------- 1. 写入 DTS ----------
cp "$DTS_SRC" "$DTS_DST"
echo "✅ DTS 已写入: target/linux/mediatek/dts/mt7981b-umi-uax3000e.dts"

# ---------- 2. 追加设备定义 ----------
if grep -q 'Device/umi_uax3000e' "$MK"; then
	echo "ℹ️ filogic.mk 中已存在 Device/umi_uax3000e，跳过"
else
	cat >> "$MK" <<'EOF'

# ---------------------------------------------------------
# UMI UAX3000E (MT7981B / 1GB DDR3 / 128GB eMMC / USB3.0)
# eMMC 版：kernel(FIT) + rootfs 分区，sysupgrade-tar 由 U-Boot 网页/救砖工具写入
# ---------------------------------------------------------
define Device/umi_uax3000e
  DEVICE_VENDOR := UMI
  DEVICE_MODEL := UAX3000E
  DEVICE_DTS := mt7981b-umi-uax3000e
  DEVICE_DTS_DIR := ../dts
  SUPPORTED_DEVICES += umi,uax3000e
  DEVICE_PACKAGES := kmod-usb3 kmod-usb-storage kmod-usb-storage-uas \
	kmod-mmc mmc-utils e2fsprogs kmod-fs-ext4 kmod-fs-f2fs \
	f2fsck mkf2fs dosfstools kmod-fs-exfat exfat-mkfs \
	automount blkid blockdev fdisk
  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
endef
TARGET_DEVICES += umi_uax3000e
EOF
	echo "✅ 设备定义已追加到 image/filogic.mk"
fi

# ---------- 3. 校验 ----------
if grep -q 'Device/umi_uax3000e' "$MK" && [ -f "$DTS_DST" ]; then
	echo "✅ UMI UAX3000E 设备支持注入完成"
else
	echo "❌ 注入校验失败"
	exit 1
fi
