# Customization Guide

Vowrite is designed to be customizable. This guide covers all the ways you can personalize your experience.

## Quick Links

| Area | Guide | Description |
|------|-------|-------------|
| App Icon | [APP_ICON_GUIDE.md](APP_ICON_GUIDE.md) | Replace the app icon with your own design |
| Recording Indicator | [THEME_GUIDE.md](THEME_GUIDE.md) | Choose or create recording animation presets |
| AI Providers | [PROVIDER_GUIDE.md](PROVIDER_GUIDE.md) | Add new AI providers via `providers.json` |

## App Icon

Vowrite supports custom app icons. Place a 1024x1024 PNG at `VowriteMac/Resources/AppIcon-source.png` and rebuild — the build script automatically generates all required sizes.

See [APP_ICON_GUIDE.md](APP_ICON_GUIDE.md) for full instructions.

## Recording Indicator

The recording indicator is the visual feedback shown while you're recording or processing. Vowrite ships with **5 built-in presets**:

| Preset | Style | Description |
|--------|-------|-------------|
| **Classic Bar** | Capsule bar | Waveform bars with cancel/confirm buttons and duration display |
| **Orb Pulse** | Breathing orb | Orange radial gradient orb that pulses with audio level |
| **Ripple Ring** | Concentric rings | Cyan ripple waves emanating from a center mic icon |
| **Spectrum Arc** | Semicircle bars | 12 bars arranged in a 180-degree arc, responsive to audio |
| **Minimal Dot** | Single dot | Color + size changes based on audio level (accessibility-friendly) |

Switch presets in **Settings > General > Recording Indicator**.

See [THEME_GUIDE.md](THEME_GUIDE.md) for details on creating new presets.

## AI Providers

Vowrite supports 15+ AI providers for speech-to-text and text polishing. You can add new providers by editing `providers.json`.

See [PROVIDER_GUIDE.md](PROVIDER_GUIDE.md) for the full provider integration guide.
