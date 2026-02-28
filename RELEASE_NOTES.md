# Vowrite Release Notes

---

## v0.1.5.0 — Version Line Restructure

**Release Date:** 2026-02-28

### Changes
- **Version line restructured** — All prior development consolidated under v0.1.x.x; v0.2.0.0 reserved for next major feature
- **4-segment versioning adopted** — MAJOR.MINOR.PATCH.BUILD format across the entire project
- **Documentation cleanup** — All release notes, ops docs, and scripts translated to English
- **Fixed version references** — Info.plist, SettingsView, README, and all ops docs updated
- **Fixed release script** — Corrected temp directory name typo ("voxa-dmg" → "vowrite-dmg"), added 4-segment version validation
- **Roadmap updated** — Reflects actual completed milestones with new version numbers

---

## v0.1.4.0 — Rebrand: Voxa → Vowrite

**Release Date:** 2026-02-27

### Changes
- **Project renamed** — Voxa → Vowrite, all code, docs, and config updated
- **Bundle Identifier** — `com.voxa.app` → `com.vowrite.app`
- **GitHub repository** — Migrated to [github.com/Joevonlong/Vowrite](https://github.com/Joevonlong/Vowrite)
- **Website** — Version and download links updated

### ⚠️ Upgrade Notes
- Due to Bundle Identifier change, you must re-add Vowrite in **System Settings → Accessibility**
- Keychain API keys need to be re-entered (keychain item name changed)

---

## v0.1.3.0 — Text Injection Rewrite + Waveform Animation

**Release Date:** 2026-02-27

### Fixes
- **Text injection engine rewrite** — Adopted the paste approach proven by Maccy (12k+ stars)
  - Uses `CGEventSource(.combinedSessionState)` + `.cgSessionEventTap`
  - Added left modifier flag (`0x000008`)
  - Added `setLocalEventsFilterDuringSuppressionState` to prevent keyboard event interference
  - Fixed text insertion failures in Discord, VS Code, and other Electron apps
  - Fixed timing issues where target app wasn't properly activated before pasting

### New Features
- **ESC to cancel** — Press Escape during recording to cancel immediately
- **Developer guide** — Added `DEV_GUIDE.md` with build/deploy flow, text injection docs, troubleshooting

### UI Improvements
- **Waveform animation redesign**
  - 13 bars with bell-curve height distribution (tallest in center)
  - Bars animate vigorously when sound is detected, giving clear "I'm listening" feedback
  - Smooth 60fps rendering + slow target updates (~4Hz) for fluid, non-jittery animation
  - Bars shrink to dots when silent
- **Recording overlay** — More compact layout, larger clear buttons, centered waveform

### Technical Details
- Text injection simplified from multi-fallback strategy (AX API → Cmd+V → Unicode) to a single reliable approach (clipboard + Cmd+V)
- Audio level detection changed to binary mode: above noise floor = sound detected, no linear volume mapping

### ⚠️ Developer Notes
- Ad-hoc signed apps require `codesign --force --sign -` after each binary replacement to maintain TCC permissions
- Apps signed with an Apple Developer certificate do not have this issue

---

## v0.1.2.0 — App Icon

**Release Date:** 2026-02-27

### New
- **App icon** — Waveform ring + text cursor design, coral-pink to amber-orange gradient, flat cartoon style
- **Icon automation script** `scripts/generate-icon.sh` — Generates all macOS icon sizes from a 1024×1024 PNG and packages as .icns
- **Build integration** — `build.sh` auto-detects new icon and converts
- **Icon guide** — `docs/APP_ICON_GUIDE.md`

### Improvements
- Added `CFBundleIconFile` to `Info.plist`

---

## v0.1.1.0 — Release Ready

**Release Date:** 2026-02-26

### Improvements

#### Release Build Optimization
- All `NSLog` and `print` debug statements wrapped with `#if DEBUG`
- No debug output in release mode, improving performance and security

#### User-Friendly Error Messages
- "No speech detected" → Clear retry prompt
- "No API key set" → Directs user to settings
- "insufficient_quota" → Suggests top-up
- Network errors → Connection failure message
- Recording failures → Microphone permission check prompt
- Generic errors → Friendly retry message

---

## v0.1.0.0 — Initial Release

**Release Date:** 2026-02-26

### 🎉 First Usable Version

Vowrite is a macOS menu bar voice input tool. Press a hotkey to speak, and AI automatically converts speech to text and inserts it at your cursor.

### Core Features
- **Speech-to-text** — OpenAI Whisper API, supports Chinese, English, and mixed input
- **AI text polishing** — GPT removes filler words, fixes grammar, adds punctuation
- **Smart cursor injection** — Clipboard paste (default) or Unicode character-by-character (fallback)
- **Menu bar app** — Lives in the menu bar, no Dock icon, floating recording bar with waveform
- **Customizable hotkey** — Default: `⌥ Space` (Option + Space)
- **Multi-provider support** — OpenAI, OpenRouter, Groq, Together AI, DeepSeek, or custom
- **Dictation history** — SwiftData persistence
- **Microphone selection** and **Launch at Login**
- **Secure storage** — API keys stored in Keychain

### Requirements
- macOS 14.0 (Sonoma) or later
- API key (OpenAI recommended)
- Microphone permission
- Accessibility permission (recommended, not required)
