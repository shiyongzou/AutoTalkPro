#!/bin/bash
# 将微信服务打包到 macOS app bundle 中
# 在 flutter build 之后运行

set -e

APP_BUNDLE="build/macos/Build/Products/Debug/tg_ai_sales_desktop.app"
if [ ! -d "$APP_BUNDLE" ]; then
  APP_BUNDLE="build/macos/Build/Products/Release/tg_ai_sales_desktop.app"
fi

if [ ! -d "$APP_BUNDLE" ]; then
  echo "错误: 找不到 app bundle，请先运行 flutter build macos"
  exit 1
fi

DEST="$APP_BUNDLE/Contents/Resources/wechat_service"
SRC="macos/Runner/Resources/wechat_service"

echo "=== 复制微信服务到 app bundle ==="
echo "源: $SRC"
echo "目标: $DEST"

mkdir -p "$DEST"
cp -R "$SRC/node" "$DEST/node"
cp -R "$SRC/node_modules" "$DEST/node_modules"
chmod +x "$DEST/node"

echo "=== 完成 ==="
du -sh "$DEST"
