# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com),
and this project uses [4-segment versioning](ops/VERSIONING.md) (`MAJOR.MINOR.PATCH.BUILD`).

## [Unreleased]

## [0.1.5.0] — 2026-02-28

### Added
- German README (`README_DE.md`)
- Language switcher in all README files (EN/CN/DE)
- GitHub badges (version, downloads, license, stars, platform, Swift)

### Changed
- Restructured version line — all development consolidated under v0.1.x.x
- Adopted 4-segment versioning (MAJOR.MINOR.PATCH.BUILD) across the project
- Translated all documentation and scripts to English
- Redesigned README to match top-tier open source standards
- Updated Info.plist, SettingsView, and all ops docs to new version format
- Replaced `RELEASE_NOTES.md` with `CHANGELOG.md` (Keep a Changelog standard)
- Release script now validates 4-segment version format

### Removed
- Legacy `VoxaApp/` directory
- Old release DMGs (Voxa-v0.2, v0.3, v0.4)

## [0.1.4.0] — 2026-02-26

### Changed
- **Rebranded** Voxa → Vowrite (all code, docs, config)
- Bundle Identifier: `com.voxa.app` → `com.vowrite.app`
- Migrated to new GitHub repository

### ⚠️ Upgrade Notes
- Re-add Vowrite in System Settings → Accessibility (Bundle ID changed)
- Re-enter API keys in settings (Keychain item name changed)

## [0.1.3.0] — 2026-02-23

### Added
- ESC to cancel recording instantly
- Developer guide (`DEV_GUIDE.md`)

### Fixed
- Rewrote text injection engine (based on Maccy's proven paste approach)
- Fixed text insertion in Discord, VS Code, and other Electron apps
- Fixed target app activation timing issues

### Changed
- Waveform animation redesign: 13 bars, bell-curve distribution, 60fps rendering
- Recording overlay layout: more compact, larger buttons, centered waveform
- Audio level detection changed to binary mode (above noise floor = sound)
- Simplified injection from multi-fallback to single reliable clipboard+Cmd+V approach

## [0.1.2.0] — 2026-02-23

### Added
- Official app icon (waveform ring + text cursor, coral-pink to amber-orange gradient)
- Icon automation script (`scripts/generate-icon.sh`)
- Icon guide (`docs/APP_ICON_GUIDE.md`)

### Changed
- Build script auto-detects new icon and converts
- Added `CFBundleIconFile` to Info.plist

## [0.1.1.0] — 2026-02-22

### Changed
- All debug logs wrapped with `#if DEBUG` for release builds
- User-facing error messages rewritten for clarity

## [0.1.0.0] — 2026-02-20

### Added
- Voice-to-text via OpenAI Whisper API (Chinese, English, mixed)
- AI text polishing via GPT (filler word removal, grammar, punctuation)
- Smart cursor injection (clipboard paste or Unicode fallback)
- macOS menu bar app with floating recording overlay + waveform animation
- Customizable global hotkey (default: `⌥ Space`)
- Multi-provider support (OpenAI, OpenRouter, Groq, Together AI, DeepSeek, custom)
- Dictation history with SwiftData
- Microphone selection and Launch at Login
- API key storage via Keychain

[Unreleased]: https://github.com/Joevonlong/Vowrite/compare/v0.1.5.0...HEAD
[0.1.5.0]: https://github.com/Joevonlong/Vowrite/compare/v0.1.4.0...v0.1.5.0
[0.1.4.0]: https://github.com/Joevonlong/Vowrite/compare/v0.1.3.0...v0.1.4.0
[0.1.3.0]: https://github.com/Joevonlong/Vowrite/compare/v0.1.2.0...v0.1.3.0
[0.1.2.0]: https://github.com/Joevonlong/Vowrite/compare/v0.1.1.0...v0.1.2.0
[0.1.1.0]: https://github.com/Joevonlong/Vowrite/compare/v0.1.0.0...v0.1.1.0
[0.1.0.0]: https://github.com/Joevonlong/Vowrite/releases/tag/v0.1.0.0
