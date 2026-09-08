#!/bin/bash

# ---------------------------------------------------------
# 双重保险：终结 OpenClash 带来的 Rust 漫长编译噩梦
# ---------------------------------------------------------
echo ">>> 开始执行双重拦截：关闭 Ruby YJIT，跳过 rust/host 编译..."

# ==========================================
# 方案 A：先从顶层配置文件强制取消 YJIT 编译
# ==========================================
# 遍历当前目录下的系统 .config 以及你仓库里的自定义 config (如 mt7986.config)
for conf in .config *.config; do
    if [ -f "$conf" ]; then
        sed -i '/CONFIG_RUBY_ENABLE_YJIT/d' "$conf"
        echo "# CONFIG_RUBY_ENABLE_YJIT is not set" >> "$conf"
        echo "✅ 方案 A 成功：已在 $conf 中强制声明关闭 RUBY_ENABLE_YJIT"
    fi
done

# ==========================================
# 方案 B：修改底层 Makefile，物理斩断依赖引擎
# ==========================================
RUBY_MK=$(find feeds -name "Makefile" -path "*/lang/ruby/Makefile" 2>/dev/null | head -n 1)
if [ -f "$RUBY_MK" ]; then
    echo ">>> 正在魔改 Ruby Makefile，执行物理级依赖阉割..."
    sed -i '/config RUBY_ENABLE_YJIT/,/help/{s/default y.*/default n/g}' "$RUBY_MK"
    echo "✅ 方案 B 成功：Ruby 对 Rust 的依赖链已被彻底斩断！"
else
    echo "⚠️ 警告: 未找到 Ruby 的 Makefile，可能路径有变，方案 B 跳过。"
fi

# =========================================================
# UAX3000E / ImmortalWrt 25.12 target injection
# =========================================================
if grep -q '^CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_umi_uax3000e=y$' .config 2>/dev/null; then
    UAX_DTS_SRC="${GITHUB_WORKSPACE}/25.12/mt7981b-umi-uax3000e.dts"
    UAX_DTS_DST="target/linux/mediatek/dts/mt7981b-umi-uax3000e.dts"
    UAX_IMAGE_MK="target/linux/mediatek/image/filogic.mk"

    if [ ! -f "$UAX_DTS_SRC" ]; then
        echo "ERROR: missing $UAX_DTS_SRC"
        exit 1
    fi
    if [ ! -f "$UAX_IMAGE_MK" ]; then
        echo "ERROR: missing $UAX_IMAGE_MK"
        exit 1
    fi

    install -Dm644 "$UAX_DTS_SRC" "$UAX_DTS_DST"

    if ! grep -q '^define Device/umi_uax3000e$' "$UAX_IMAGE_MK"; then
        cat >> "$UAX_IMAGE_MK" <<'DEVICE_EOF'

define Device/umi_uax3000e
  DEVICE_VENDOR := UMI
  DEVICE_MODEL := UAX3000E
  DEVICE_DTS := mt7981b-umi-uax3000e
  DEVICE_DTS_DIR := ../dts
  DEVICE_PACKAGES := automount blkid blockdev fdisk f2fsck mkf2fs kmod-mmc mmc-utils kmod-usb3
  KERNEL := kernel-bin | lzma | fit lzma $$(KDIR)/image-$$(firstword $$(DEVICE_DTS)).dtb
  KERNEL_INITRAMFS := kernel-bin | lzma |     fit lzma $$(KDIR)/image-$$(firstword $$(DEVICE_DTS)).dtb with-initrd | pad-to 64k
  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
endef
TARGET_DEVICES += umi_uax3000e
DEVICE_EOF
    fi
    echo "✅ UAX3000E target support injected."
fi

echo "🎉 双重拦截部署完毕！"
