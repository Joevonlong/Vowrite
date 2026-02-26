# Vowrite App Icon Guide

## Quick Start

### 1. Prepare the Icon

Use Gemini (Nano Banana 2) or any tool to generate a **1024×1024 PNG** icon.

Recommended prompt example:
> "A modern macOS app icon for a voice dictation app called Vowrite. Clean, minimal design with a microphone or sound wave motif. Rounded square shape following macOS icon guidelines. Vibrant gradient."

### 2. Place the Icon

Put the PNG file at:

```
VowriteApp/Resources/AppIcon-source.png
```

This is the only step you need to do manually.

### 3. Automatic Conversion

Run the build script and the icon will be converted automatically:

```bash
cd VowriteApp
./build.sh
```

Or convert the icon separately:

```bash
./scripts/generate-icon.sh
```

You can also specify a different image path:

```bash
./scripts/generate-icon.sh ~/Downloads/my-icon.png
```

### 4. Done

The script will automatically:
- Generate all macOS-required sizes (16–512@2x) from the 1024×1024 source image
- Package into `.icns` format
- Place at `Vowrite.app/Contents/Resources/AppIcon.icns`
- `Info.plist` already has `CFBundleIconFile` configured, no additional steps needed

## File Structure

```
VowriteApp/
├── Resources/
│   ├── AppIcon-source.png    ← Place your icon here (1024x1024 PNG)
│   └── Info.plist            ← Already includes CFBundleIconFile config
├── scripts/
│   └── generate-icon.sh      ← Automatic conversion script
├── Vowrite.app/
│   └── Contents/
│       └── Resources/
│           └── AppIcon.icns  ← Generated icon (automatic)
└── build.sh                  ← Automatically detects and converts icon during build
```

## Replacing the Icon

Replace `Resources/AppIcon-source.png`, then:

```bash
# Delete the old icns to trigger regeneration
rm Vowrite.app/Contents/Resources/AppIcon.icns
./build.sh
```

Or force regeneration directly:

```bash
./scripts/generate-icon.sh
./build.sh
```

## Notes

- Source image should be **1024×1024**; smaller sizes will show a warning but still generate
- Use **PNG format**, transparent backgrounds are supported
- macOS icons have automatic rounded corner masks, no need to draw rounded corners yourself
- `.icns` files and `build/` directory should be added to `.gitignore`; source PNG should be version-controlled
