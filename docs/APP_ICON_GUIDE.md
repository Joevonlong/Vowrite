# Voxa App 图标指南

## 快速上手

### 1. 准备图标

用 Gemini (Nano Banana 2) 或任何工具生成一张 **1024×1024 PNG** 图标。

推荐 prompt 示例：
> "A modern macOS app icon for a voice dictation app called Voxa. Clean, minimal design with a microphone or sound wave motif. Rounded square shape following macOS icon guidelines. Vibrant gradient."

### 2. 放置图标

将 PNG 文件放到：

```
VoxaApp/Resources/AppIcon-source.png
```

这是唯一需要你操作的步骤。

### 3. 自动转换

运行构建脚本，图标会自动转换：

```bash
cd VoxaApp
./build.sh
```

或者单独转换图标：

```bash
./scripts/generate-icon.sh
```

也可以指定其他路径的图片：

```bash
./scripts/generate-icon.sh ~/Downloads/my-icon.png
```

### 4. 完成

脚本会自动：
- 从 1024×1024 源图生成所有 macOS 需要的尺寸（16～512@2x）
- 打包为 `.icns` 格式
- 放到 `Voxa.app/Contents/Resources/AppIcon.icns`
- `Info.plist` 已配置好 `CFBundleIconFile`，无需额外操作

## 文件结构

```
VoxaApp/
├── Resources/
│   ├── AppIcon-source.png    ← 你放图标的地方（1024x1024 PNG）
│   └── Info.plist            ← 已包含 CFBundleIconFile 配置
├── scripts/
│   └── generate-icon.sh      ← 自动转换脚本
├── Voxa.app/
│   └── Contents/
│       └── Resources/
│           └── AppIcon.icns  ← 生成的图标（自动）
└── build.sh                  ← 构建时自动检测并转换图标
```

## 更换图标

替换 `Resources/AppIcon-source.png`，然后：

```bash
# 删除旧的 icns 触发重新生成
rm Voxa.app/Contents/Resources/AppIcon.icns
./build.sh
```

或直接强制重新生成：

```bash
./scripts/generate-icon.sh
./build.sh
```

## 注意事项

- 源图片建议 **1024×1024**，小于此尺寸会有警告但仍可生成
- 使用 **PNG 格式**，支持透明背景
- macOS 图标自带圆角遮罩，不需要自己画圆角
- `.icns` 文件和 `build/` 目录建议加入 `.gitignore`，源 PNG 纳入版本管理
