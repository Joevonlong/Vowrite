#!/bin/bash
# generate-icon.sh — 将单张 PNG 图标转换为 macOS .icns 并安装到 app bundle
#
# 用法:
#   ./scripts/generate-icon.sh [源图片路径]
#
# 默认源图片: Resources/AppIcon-source.png (1024x1024 PNG)
#
set -e
cd "$(dirname "$0")/.."

SOURCE="${1:-Resources/AppIcon-source.png}"
ICONSET_DIR="build/Voxa.iconset"
ICNS_OUTPUT="Voxa.app/Contents/Resources/AppIcon.icns"

if [ ! -f "$SOURCE" ]; then
  echo "❌ 找不到源图片: $SOURCE"
  echo ""
  echo "请将 1024x1024 的 PNG 图标放到以下位置:"
  echo "  VoxaApp/Resources/AppIcon-source.png"
  echo ""
  echo "或者指定路径: ./scripts/generate-icon.sh /path/to/icon.png"
  exit 1
fi

# 检查图片尺寸
WIDTH=$(sips -g pixelWidth "$SOURCE" | tail -1 | awk '{print $2}')
HEIGHT=$(sips -g pixelHeight "$SOURCE" | tail -1 | awk '{print $2}')
if [ "$WIDTH" -lt 1024 ] || [ "$HEIGHT" -lt 1024 ]; then
  echo "⚠️  警告: 源图片为 ${WIDTH}x${HEIGHT}，建议使用 1024x1024 以获得最佳效果"
fi

echo "🎨 从 $SOURCE 生成图标..."

# 清理并创建 iconset 目录
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

# 生成所有 macOS 需要的尺寸
sips -z 16 16       "$SOURCE" --out "$ICONSET_DIR/icon_16x16.png"      > /dev/null
sips -z 32 32       "$SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png"   > /dev/null
sips -z 32 32       "$SOURCE" --out "$ICONSET_DIR/icon_32x32.png"      > /dev/null
sips -z 64 64       "$SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png"   > /dev/null
sips -z 128 128     "$SOURCE" --out "$ICONSET_DIR/icon_128x128.png"    > /dev/null
sips -z 256 256     "$SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" > /dev/null
sips -z 256 256     "$SOURCE" --out "$ICONSET_DIR/icon_256x256.png"    > /dev/null
sips -z 512 512     "$SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" > /dev/null
sips -z 512 512     "$SOURCE" --out "$ICONSET_DIR/icon_512x512.png"    > /dev/null
sips -z 1024 1024   "$SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" > /dev/null

# 转换为 .icns
iconutil -c icns "$ICONSET_DIR" -o "$ICNS_OUTPUT"

# 清理临时文件
rm -rf "$ICONSET_DIR"

echo "✅ 图标已生成: $ICNS_OUTPUT"
echo "   下次 build.sh 会自动包含此图标。"
