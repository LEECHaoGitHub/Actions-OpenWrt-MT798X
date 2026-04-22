#!/bin/bash
# =========================================================
# Daed 手动版本更新脚本 (CI稳定版)
# =========================================================

set -e

# =========================================================
# 手动指定版本
# =========================================================
DAED_VER="1.27.0"

# =========================================================
# 检查环境
# =========================================================
DAED_MK="feeds/packages/net/daed/Makefile"

if [ ! -f "$DAED_MK" ]; then
    echo "❌ 找不到 ${DAED_MK}"
    echo "请确认已执行 ./scripts/feeds update -a && install"
    exit 1
fi

OLD_VER=$(grep '^PKG_VERSION:=' "$DAED_MK" | cut -d= -f2)

echo "========================================="
echo " Daed 更新"
echo "========================================="
echo "旧版本: ${OLD_VER}"
echo "新版本: ${DAED_VER}"
echo "========================================="

# =========================================================
# 检查版本是否存在
# =========================================================
echo ">>> 检查 GitHub release..."

RELEASE_URL="https://github.com/daeuniverse/daed/releases/tag/v${DAED_VER}"

HTTP_CODE=$(curl -sL -o /dev/null -w '%{http_code}' "$RELEASE_URL")

if [ "$HTTP_CODE" != "200" ]; then
    echo "❌ 版本不存在"
    echo "$RELEASE_URL"
    exit 1
fi

echo "✓ Release 存在"

# =========================================================
# 修改 Makefile 版本
# =========================================================
echo ">>> 修改 Makefile"

sed -i "s/^PKG_VERSION:=.*/PKG_VERSION:=${DAED_VER}/" "$DAED_MK"
sed -i 's/^PKG_MIRROR_HASH:=.*/PKG_MIRROR_HASH:=skip/' "$DAED_MK"
sed -i '/define Download\/daed-web/,/endef/{s/HASH:=.*/HASH:=skip/}' "$DAED_MK"

echo "✓ 版本更新完成"

# =========================================================
# 下载 web.zip
# =========================================================
echo ">>> 下载 Web UI"

TMP_DIR=$(mktemp -d)

WEB_URL="https://github.com/daeuniverse/daed/releases/download/v${DAED_VER}/web.zip"

curl -fSL --progress-bar -o "$TMP_DIR/web.zip" "$WEB_URL"

WEB_HASH=$(sha256sum "$TMP_DIR/web.zip" | awk '{print $1}')

echo "web hash:"
echo "$WEB_HASH"

rm -rf "$TMP_DIR"

# =========================================================
# 下载源码
# =========================================================
echo ">>> 下载源码"

rm -f dl/daed-* || true

make package/daed/download V=s

SRC_FILE=$(find dl/ -name "daed-${DAED_VER}*" | head -1)

if [ ! -f "$SRC_FILE" ]; then
    echo "❌ 源码下载失败"
    exit 1
fi

SRC_HASH=$(sha256sum "$SRC_FILE" | awk '{print $1}')

echo "源码 hash:"
echo "$SRC_HASH"

# =========================================================
# 回填 hash
# =========================================================
echo ">>> 回填 hash"

sed -i "s/^PKG_MIRROR_HASH:=.*/PKG_MIRROR_HASH:=${SRC_HASH}/" "$DAED_MK"
sed -i "/define Download\/daed-web/,/endef/{s/HASH:=.*/HASH:=${WEB_HASH}/}" "$DAED_MK"

echo "✓ Hash 更新完成"

# =========================================================
# 验证下载
# =========================================================
echo ">>> 校验源码完整性"

CALC_HASH=$(sha256sum "$SRC_FILE" | awk '{print $1}')

if [ "$CALC_HASH" != "$SRC_HASH" ]; then
    echo "❌ hash 不一致"
    exit 1
fi

echo "✓ Hash 校验通过"

echo ""
echo "========================================="
echo "最终 Makefile 字段"
echo "========================================="

grep PKG_VERSION "$DAED_MK"
grep PKG_MIRROR_HASH "$DAED_MK"

grep -A4 "define Download/daed-web" "$DAED_MK" | grep HASH

echo "========================================="
echo "Daed 更新完成"
