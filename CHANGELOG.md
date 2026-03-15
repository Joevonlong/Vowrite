# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com),
and this project uses [4-segment versioning](ops/VERSIONING.md) (`MAJOR.MINOR.PATCH.BUILD`).

## [Unreleased]

## [0.1.8.1] — 2026-03-15

### Added
- **F-024**: Stable code signing with self-signed certificate + dedicated keychain (permissions persist across updates)
- **F-025**: macOS standard menu bar when Settings window is open + sidebar navigation redesign
- **F-027**: STT model expansion — gpt-4o-transcribe support, Groq as default STT, DeepSeek as default polish
- **Ollama**: Local LLM provider support for AI polish (on-device processing)

### Changed
- Default STT provider changed to Groq (faster, free tier)
- Default AI polish provider changed to DeepSeek (cost-effective)
- Model config UX improvements for STT provider selection

### Partial
- **F-026**: Sparkle auto-update framework integrated (code + UI ready, EdDSA key + appcast.xml pending)

## [0.1.8.0] — 2026-03-13

### Added
- **F-002**: Output Style templates system — customizable text formatting presets (formal, casual, bullet points, etc.)

### Fixed
- Prevent AI polish from responding conversationally to transcripts (treats all input as text to polish, not questions to answer)

## [0.1.7.2] — 2026-03-12

### Fixed
- **App launch failure**: Code signing now includes entitlements (microphone, network access) — fixes "network error" on all API calls
- **Long recordings timeout**: STT timeout 60s→180s, AI polish timeout 30s→120s — long dictations no longer fail
- **Misleading error messages**: Show actual error instead of generic "network error" for all failure types
- **STT provider check**: Warn before recording if provider doesn't support Whisper API (e.g. OpenRouter, DeepSeek)

### Added
- **Install script in DMG**: Double-click `Install Vowrite.command` to auto-quit → replace → relaunch (no need to manually quit first)
- **Applications symlink in DMG**: Standard macOS drag-to-install experience
- **25MB file size check**: Clear error message when recording exceeds Whisper API limit
- **Self-signed certificate support**: `release.sh` auto-detects "Vowrite Developer" cert for consistent signing identity
- **Standardized release pipeline**: `scripts/release.sh` — one-command build, sign, package, tag, push, GitHub Release

### Changed
- Release DMG now contains: `Vowrite.app` + `Applications` shortcut + `Install Vowrite.command`
- Error messages show specific failure reason (404, timeout, quota, invalid key, etc.)

## [0.1.7.1] — 2026-03-11

### Added
- **Smart formatting**: AI automatically adapts output format based on content structure — lists become bullet points, steps become numbered lists, casual speech stays as paragraphs
- **Language picker in Settings**: Language selection now accessible in the main Settings page (was previously missing from new UI)
- Warning displayed when a specific language is selected, recommending Auto-detect for multilingual users

### Fixed
- **System prompt protection**: System prompt is now read-only and hidden from user UI — prevents accidental deletion of core rules (language preservation, dictation behavior)
- **Chinese→English translation bug**: Fixed issue where speaking Chinese would output English text, caused by:
  - Language setting missing from new Settings UI (couldn't change back after onboarding)
  - Conflicting language rule in AI polish pipeline removed
- Legacy user-modified system prompts cleaned from UserDefaults on app launch

### Changed
- System prompt enhanced with smart formatting rules and stronger language preservation (final reminder pattern)
- AI polish language handling now solely controlled by system prompt (removed redundant inline rule from AIPolishService)

## [0.1.7.0] — 2026-03-11

### Added
- **F-001**: Stronger multilingual preservation in AI polish prompt (Chinese + English mixed text)
- **F-005**: Scene-aware smart formatting with 6 presets (email, code, chat, etc.)
- **F-010**: System prompt & user prompt configuration in Settings UI
- **F-011**: Multi-provider API configuration enhancement (easier setup for 6+ providers)
- **F-013**: Language settings with global default and Whisper API integration
- **F-014**: Personal dictionary for improved speech recognition (custom vocabulary)
- **F-016**: Input modes (Dictation / AI Polish / Translation)
- **F-017**: First-launch onboarding flow
- **F-018**: Redesigned recording overlay with mode indicator
- **F-019**: Quick settings panel accessible from menu bar
- **F-022**: About page with version info and links
- Sidebar navigation for Settings: Account / Settings / Personalization / About
- Account page redesign: card-based login UX, API key inline setup

### Changed
- Settings UI completely redesigned with sidebar navigation
- System prompt hidden from user settings (enforced internally)
- Model selection enforced via dropdown (no free-text input)

### Fixed
- Version display now uses compiled `AppVersion.current` (fixes SwiftPM builds)
- Google Sign-In session retention fix
- JSON-LD version corrected, Twitter Card upgraded to `summary_large_image`

### Removed
- F-020 file transcription (reverted — not ready for release)
- Google Sign-In UI temporarily hidden (pending backend OAuth)

## [0.1.6.0] — 2026-02-28

### Fixed
- Text injection engine rewritten using Maccy-proven paste approach (combinedSessionState + cgSessionEventTap)
- Fixed text insertion in Electron apps (Discord, VS Code, Slack)
- Fixed version number inconsistency across all UI locations

### Added
- ESC key to cancel recording instantly
- History view redesign: single-column scrollable layout with time display and date grouping
- Waveform animation: 13 bars, bell-curve distribution, 60fps smooth rendering
- DEV_GUIDE.md with build/deploy/troubleshooting documentation
- All version displays now read from Bundle.main (single source of truth)

### Changed
- Recording overlay: more compact design with proportional buttons
- Audio level detection: binary voice-activity mode for clearer visual feedback

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

[Unreleased]: https://github.com/Joevonlong/Vowrite/compare/v0.1.8.0...HEAD
[0.1.8.0]: https://github.com/Joevonlong/Vowrite/compare/v0.1.7.2...v0.1.8.0
[0.1.7.2]: https://github.com/Joevonlong/Vowrite/compare/v0.1.7.1...v0.1.7.2
[0.1.7.1]: https://github.com/Joevonlong/Vowrite/compare/v0.1.7.0...v0.1.7.1
[0.1.7.0]: https://github.com/Joevonlong/Vowrite/compare/v0.1.6.0...v0.1.7.0
[0.1.6.0]: https://github.com/Joevonlong/Vowrite/compare/v0.1.5.0...v0.1.6.0
[0.1.5.0]: https://github.com/Joevonlong/Vowrite/compare/v0.1.4.0...v0.1.5.0
[0.1.4.0]: https://github.com/Joevonlong/Vowrite/compare/v0.1.3.0...v0.1.4.0
[0.1.3.0]: https://github.com/Joevonlong/Vowrite/compare/v0.1.2.0...v0.1.3.0
[0.1.2.0]: https://github.com/Joevonlong/Vowrite/compare/v0.1.1.0...v0.1.2.0
[0.1.1.0]: https://github.com/Joevonlong/Vowrite/compare/v0.1.0.0...v0.1.1.0
[0.1.0.0]: https://github.com/Joevonlong/Vowrite/releases/tag/v0.1.0.0
