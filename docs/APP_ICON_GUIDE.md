# Vowrite App Icon Guide

The Vowrite icon ships across three surfaces: **macOS app bundle**, **iOS app bundle**, and the **marketing website**. All are driven from a single 1024×1024 master.

## Source of Truth

| File | Purpose |
|------|---------|
| `VowriteMac/Resources/AppIcon-source.png` | 1024×1024 raster master (drives macOS .icns + iOS + web) |
| `VowriteMac/Resources/AppIcon-source.svg` | Vector companion (used for `docs/favicon.svg`; close visual match to the PNG) |

Both are version-controlled. The `.icns` and `build/` artifacts are gitignored / build-time only.

## macOS — Automatic

Replace `VowriteMac/Resources/AppIcon-source.png` with a new 1024×1024 PNG, then:

```bash
cd VowriteMac
rm -f Vowrite.app/Contents/Resources/AppIcon.icns   # force regen
./build.sh                                           # builds + signs + relaunches
```

Or regenerate just the icon without rebuilding:

```bash
cd VowriteMac
./scripts/generate-icon.sh                           # default source path
./scripts/generate-icon.sh ~/Downloads/my-icon.png   # custom path
```

`generate-icon.sh` produces all macOS sizes (16–512@2x) and packs them into `Vowrite.app/Contents/Resources/AppIcon.icns`. `Info.plist` already has `CFBundleIconFile = AppIcon`, no further wiring needed.

## iOS — One-time wiring

Drop a 1024×1024 PNG at `VowriteIOS/Assets.xcassets/AppIcon.appiconset/AppIcon.png`. The matching `Contents.json` references the filename, and Xcode 15+ auto-slices it into all required iOS sizes (60pt @2x/@3x, 76pt, 83.5pt, 29pt, 40pt, 20pt). No per-size PNGs required.

To replace, just overwrite `AppIcon.png`:

```bash
cp VowriteMac/Resources/AppIcon-source.png \
   VowriteIOS/Assets.xcassets/AppIcon.appiconset/AppIcon.png
```

## Website — Manual regeneration

The marketing site (`docs/`) needs a small set of derived assets. Run from the `Vowrite/` repo root after replacing the master:

```bash
# Square icons (header logo, footer, favicon fallback, schema.org)
sips -z 64  64  VowriteMac/Resources/AppIcon-source.png --out docs/app-icon-64.png
sips -z 128 128 VowriteMac/Resources/AppIcon-source.png --out docs/app-icon-128.png
sips -z 256 256 VowriteMac/Resources/AppIcon-source.png --out docs/app-icon-256.png

# iOS home-screen bookmark
sips -z 180 180 VowriteMac/Resources/AppIcon-source.png --out docs/apple-touch-icon.png

# Vector favicon (modern browsers)
cp VowriteMac/Resources/AppIcon-source.svg docs/favicon.svg

# 1200×630 Open Graph / Twitter share preview
sips -z 512 512 VowriteMac/Resources/AppIcon-source.png --out /tmp/vowrite-icon-512.png
python3 - <<'PY'
from PIL import Image
canvas = Image.new('RGB', (1200, 630), '#FFFFFF')  # match the icon's white surface
icon = Image.open('/tmp/vowrite-icon-512.png').convert('RGBA')
canvas.paste(icon, ((1200 - icon.width) // 2, (630 - icon.height) // 2),
             icon if icon.mode == 'RGBA' else None)
canvas.save('docs/og-image.png', 'PNG', optimize=True)
PY
```

The HTML files in `docs/` already reference these filenames — no markup changes required when refreshing.

## File Structure

```
Vowrite/
├── VowriteMac/
│   ├── Resources/
│   │   ├── AppIcon-source.png    ← 1024×1024 raster master
│   │   ├── AppIcon-source.svg    ← vector companion
│   │   └── Info.plist            ← CFBundleIconFile = AppIcon
│   ├── scripts/generate-icon.sh  ← .png → .icns
│   ├── Vowrite.app/Contents/Resources/AppIcon.icns   (generated)
│   └── build.sh                  ← auto-runs generate-icon.sh when needed
├── VowriteIOS/Assets.xcassets/AppIcon.appiconset/
│   ├── AppIcon.png               ← copy of 1024 master
│   └── Contents.json
└── docs/
    ├── favicon.svg, app-icon-{64,128,256}.png,
    │   apple-touch-icon.png, og-image.png
    └── *.html                    ← references all of the above
```

## Notes

- Source PNG should be **1024×1024**. Smaller sizes warn but still work.
- Background can be solid (current icon: white) or transparent — macOS / iOS apply their own corner mask on top.
- `.icns` and `build/` are gitignored; the source PNG/SVG and all `docs/` derivatives **are** committed.
- The Brewfile-free OG image step needs `python3` + Pillow (`pip install pillow`). If unavailable, install ImageMagick (`brew install imagemagick`) and use `magick -size 1200x630 xc:'#FFFFFF' \( app-icon-512.png \) -gravity center -composite docs/og-image.png` instead.
