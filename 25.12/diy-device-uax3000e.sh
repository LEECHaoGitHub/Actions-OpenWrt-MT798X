#!/bin/bash
#
# 25.12 源码（chasey-dev/immortalwrt-mt798x-rebase）未原生包含 UMI UAX3000E 设备，
# 本脚本在编译前把设备树与设备定义注入源码，使 make defconfig 能生成
# CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_umi_uax3000e 符号。
# 由 .github/workflows/25.12-umi-uax3000e.yml 在 openwrt/ 源码目录内调用。
#
set -e

DEV_DIR="$GITHUB_WORKSPACE/25.12/devices"
DTS_DST="target/linux/mediatek/dts"
IMG_MK="target/linux/mediatek/image/filogic.mk"

echo ">>> 注入 UMI UAX3000E 设备支持 ..."

# 1. 设备树
if [ ! -f "$DEV_DIR/mt7981b-umi-uax3000e.dts" ]; then
	echo "❌ 未找到设备树: $DEV_DIR/mt7981b-umi-uax3000e.dts"
	exit 1
fi
if [ ! -d "$DTS_DST" ]; then
	echo "❌ 未找到目录: $DTS_DST（上游可能已调整设备树路径）"
	exit 1
fi
if [ ! -f "$IMG_MK" ]; then
	echo "❌ 未找到 $IMG_MK（上游可能已调整镜像定义位置）"
	exit 1
fi
cp -f "$DEV_DIR/mt7981b-umi-uax3000e.dts" "$DTS_DST/"
echo "✅ 设备树已注入: $DTS_DST/mt7981b-umi-uax3000e.dts"

# 2. 设备定义（幂等：已存在则跳过）
if grep -q "Device/umi_uax3000e" "$IMG_MK"; then
	echo "ℹ️ filogic.mk 已包含 umi_uax3000e，跳过追加"
else
	cat >> "$IMG_MK" << 'EOF'

# ============================================================
# UMI UAX3000E (eMMC) - injected by Actions-OpenWrt-MT798X
# ============================================================
define Device/umi_uax3000e
  DEVICE_VENDOR := UMI
  DEVICE_MODEL := UAX3000E
  DEVICE_DTS := mt7981b-umi-uax3000e
  DEVICE_DTS_DIR := ../dts
  DEVICE_PACKAGES := kmod-mt7915e kmod-mt7981-firmware mt7981-wo-firmware automount coremark blkid blockdev fdisk f2fsck mkf2fs kmod-mmc mmc-utils
  KERNEL := kernel-bin | lzma | fit lzma $$(KDIR)/image-$$(firstword $$(DEVICE_DTS)).dtb
  KERNEL_INITRAMFS := kernel-bin | lzma | \
	fit lzma $$(KDIR)/image-$$(firstword $$(DEVICE_DTS)).dtb with-initrd | pad-to 64k
  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
endef
TARGET_DEVICES += umi_uax3000e
EOF
	echo "✅ filogic.mk 已追加 umi_uax3000e 设备定义"
fi

echo ">>> UMI UAX3000E 设备支持注入完成"
