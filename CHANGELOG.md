# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com),
and this project uses [4-segment versioning](ops/VERSIONING.md) (`MAJOR.MINOR.PATCH.BUILD`).

## [Unreleased]

### Changed

- **F-072 Polish output style is more assertive (Typeless-inspired)**: The default polish prompt now treats your dictation as a rough draft to be edited, not a transcript to preserve. Output is more concise and structured — short paragraphs by default, bullets when you enumerate two or more items, the main point surfaced first when you buried it. Language preservation across mixed-language speech (e.g. 中英混合) is unchanged. If you prefer a near-passthrough record of what you said, switch to `Dictation` mode (Cmd+1).

## [0.2.1.2] — 2026-05-04

### Added

- **F-070 iOS keyboard zone-based long-press mode picker**: Long-press on the keyboard mic pill now reveals a zone-based selection layout (matching the mockup) instead of the dual-arc menu. Slide into a zone and release to commit; layout is overlap-free and easier to discover.
- **F-071 Polish prompt externalization + user-prompt edit-lock hardening**: Base polish prompts moved out of `PromptConfig` into external resource files for easier iteration without recompiling. User-prompt editing is now locked while a recording is in flight to prevent the prompt from changing mid-pipeline.

### Fixed

- **Translate banner overlap (recording circle)**: The translate banner no longer overlaps the recording circle glow on the keyboard.
- **Keyboard translate banner locale + hint overlap**: Translate banner now respects the user's locale and no longer overlaps the hint label.
- **Long-press mode picker gesture**: "松开以取消" no longer overlaps the gesture target; gesture handling tightened.
- **iOS keyboard silent reset**: When no speech is detected, the keyboard silently resets to standby instead of surfacing a confusing error state.

## [0.2.1.1] — 2026-05-02

### Added

- **VowriteKitTests target**: First automated test target. Six XCTest files covering `Mode` Codable roundtrip + F-063 backward-compat decode, `ModeConfig` field mapping and `withStyleOverride` behaviour, `OutputStyle` Codable roundtrip, `ReplacementRule` Codable roundtrip + ID uniqueness, builtin data integrity (Clean mode UUID stability, builtin shortcut index uniqueness, `OutputStyle.noneId` resolution), and the empty-rules early-return path of `ReplacementManager.apply`. `ops/scripts/test.sh` now invokes `swift test` between the Kit build and the Mac build.

### Changed

- **WindowHelper**: dropped redundant `openSettings()` / `openHistory()` wrappers that only delegated to `openMainWindow()`. Five call sites (`VowriteApp` Settings command, `MenuBarView` History/Settings buttons, `VowriteMenuView` Settings/History entries) now call `openMainWindow()` directly.

### Fixed

- **ModelContainer init failure no longer crashes the app**: `AppState.init` on Mac and iOS now falls back to an in-memory store and surfaces a "history temporarily unavailable" banner in `HistoryView` instead of `fatalError`. iOS banner additionally calls out that keyboard extension records are also affected because the keyboard extension reads the App Group SwiftData store directly.
- **About page shows the real app icon** instead of the SF Symbol `mic.circle.fill` placeholder. Pulled directly from `NSApp.applicationIconImage` so it always matches the bundled `AppIcon.icns`. `build.sh` icon regeneration logic also tightened: `.icns` is now rebuilt whenever `Resources/AppIcon-source.png` is newer than the existing `.icns` (previously only ran on first generation), so brand refreshes propagate without a manual clean.

### Removed

- **MiniMax OAuth flow**: removed `MiniMaxOAuthService`, `MiniMaxOAuthCard`, and the `minimax_intl`/`minimax_cn` cases in `OAuthRefreshManager.performRefresh`. `clientID` was never obtained from MiniMax developer support, so the flow was never functional. `MiniMaxOAuthCard` was also a 100% orphan (zero instantiation sites). `PresentationContextBridge` was extracted to its own file because `OpenAICodexOAuthService` still uses it. New `MiniMaxOAuthPurge.runIfNeeded()` one-shot clears stale OAuth tokens and `auth.method.minimax_*` keys on next launch.

## [0.2.1.0] — 2026-05-02

### Added — Translation Suite

- **F-063 Translate Mode (macOS)**: Dedicated global hotkey (default `⇧⌥ Space`) starts a translation recording without disturbing the user's current Mode. New `Mode.isTranslation` / `Mode.targetLanguage` fields with custom `Codable` decoding for backward compatibility. `DictationEngine.sessionModeOverride` injects an isolated Translate Mode for the single recording. Translation prompt replaces the polish prompt (`PromptConfig.translationSystemPrompt`); fallback emits the source transcript with a warning if translation fails. Settings shows a second hotkey row with conflict validation, the Mode editor lays out dynamically based on Translate vs Dictation, and the recording overlay shows a target-language badge.
- **F-064 iOS Translation Parity**: `VowriteKeyboard` long-press on the mic pill reveals a dual-arc menu (Dictate / Translate); slide-up to choose, release to commit. Translation recordings show a "Translating to {target}" banner across the keyboard top. `BackgroundRecordingIPC.sessionModeOverrideId` mirrors macOS; `BackgroundRecordingService.effectiveModeConfig` is wired through 14 lifecycle points so the override survives across IPC boundaries. iOS `ModeEditorSheet` mirrors macOS layout (Mode Type toggle, Source/Target Language pickers, collapsible Advanced systemPrompt).
- **F-066 Translation Language Quick Settings**: New "Translation" section in macOS `GeneralPage` and iOS `SettingsView` exposes Source / Target Language pickers bound directly to the built-in Translate mode (`Mode.language` / `Mode.targetLanguage`). No new UserDefaults key — single source of truth shared with the Mode editor and the translation pipeline.
- **F-067 iOS Keyboard Bulk Delete**: TopBar delete key long-press (0.4s) opens a dark popup beneath the button. Dragging onto the popup escalates tier (word → line → paragraph → all) using accumulated dwell time; `TimelineView` updates the label live. Release commits the batch by re-scanning `documentContextBeforeInput` for the appropriate boundary and calling `deleteBackward` per grapheme. Tier transitions emit a selection haptic; commit emits a success haptic. Reuses the F-064 `DragGesture(0)` + `DispatchWorkItem` + named coordinate-space skeleton.

### Added — Website

- **Dedicated Translation feature page** (`docs/translate.html`): Full-page explainer covering the multilingual recognition + translation flow — hero with rotating live translation demo, end-to-end pipeline diagram, dual-trigger explanation (Mac hotkey + iOS arc menu), Source/Target quick-settings showcase, language matrix, real-world use cases, and a comparison vs Apple Translate / Google Translate / DeepL Voice. Top nav gains a "Translate" entry across all pages. Index page Features grid adds a 🌐 Translation card linking to the new page. Full EN / ZH / DE i18n coverage.

## [0.2.0.1] — 2026-05-01

### Added — Local & Customization

- **F-048 Sherpa local ASR (scaffold + Settings UI)**: `SherpaSTTAdapter`, `SherpaModelManager`, `SherpaEngine` C wrapper, 3 model definitions, macOS + iOS Local Models settings panel, tar.bz2 download/extract. Full runtime still pending sherpa-onnx XCFramework.
- **F-051 Text Replacement & Correction**: `ReplacementManager` with trigger→replacement rules, Chinese/English flex pattern matching, dual-position replacement (post-STT + post-LLM), LLM vocabulary injection, macOS and iOS UI.
- **F-052 Recording Indicator (3 new presets)**: Ripple Ring / Spectrum Arc / Minimal Dot — 5 themes total including Classic Bar and Orb Pulse.
- **F-053 Auto-learn Vocabulary**: DictationEngine extracts hotwords after recording and writes them to VocabularyManager.
- **F-054 Correction Monitor**: Detects Cmd+Z undo and records the correction into DictationRecord.
- **F-055 Long-text optimization**: 16kHz mono audio upload, SpeculativePolish SSE streaming with `onPartial` callback, STT 60s timeout for long sessions.
- **F-056 User docs**: `docs/CUSTOMIZATION.md`, `docs/PROVIDER_GUIDE.md`, `docs/THEME_GUIDE.md`; README adds Customization section.
- **F-057 iOS keyboard UI redesign**: 3-state UI (idle / recording / processing), SwiftUI Link for iOS 18 keyboard activation, URL Scheme auto-return to host app, ActivationOverlay fallback.

### Added — OAuth (macOS only)

- **F-058 Provider OAuth infrastructure**: Shared `PKCEHelper` / `OAuthTokenStore` / `OAuthRefreshManager` / `CredentialManager` + MiniMax Coding Plan login + 4-state Settings UI on macOS.
- **F-059 OpenAI Codex OAuth**: `OpenAICodexOAuthService` (PKCE S256) + ChatGPT Plus/Pro subscription login.
- **F-060 Kimi Code OAuth**: `KimiCodeOAuthService` (RFC 8628 Device Flow) + Device Flow Sheet UI + transparent base URL switching.

### Changed

- **F-062 Provider catalog refresh**: 19 providers reviewed, 14 updated. `providers.json` schema bumped v1 → v2. Fixes: MiniMax baseURL `api.minimax.chat` → `api.minimax.io` (old domain dead); Volcengine model ID format (`.` → `-`) and removal of fictional `2-0-mini`/`lite` IDs; Groq `qwen-qwq-32b` retired; Kimi standardized on `kimi-k2.6` (dot-form ID). Additions: DeepSeek V4-flash/V4-pro, GPT-5.4-mini/5.5/5.4-nano, Claude 4-6/4-7/haiku-4-5, Gemini 2.5-pro/flash-lite, Doubao Seed 1.6/1.8/2.0-pro, Kimi K2.6, MiniMax M2.7, Qwen 3.6 series, GLM-4.6/5/5.1. Volcengine STT temporarily disabled (`capabilities.stt = false`) pending F-063.

### Fixed

- **macOS 26 SIGSEGV crash on AVAudioFile create**: F-055's 16kHz forced installTap format triggered a system-frame SIGSEGV on macOS 26. Reverted to native input format; also fixed `onPartial` `@Published` data race (commit `2201409`).
- **BUG-010: OAuth credentials wired into request paths**: F-058/F-059/F-060 OAuth tokens were stored but never used by polish/STT call sites. `APIEndpointConfiguration.key` / `resolvedBaseURL` / `hasKey` switched to OAuth-aware fields; new `resolvedModel` rewrites Kimi → `kimi-for-coding` on coding-plan paths; Kimi coding-plan User-Agent + `X-Msh-*` headers now injected (commit `627eaa5`).
- **BUG-012: macOS post-paste path hardening**: `CorrectionMonitor.captureElement` now guards AX `CFTypeRef` with `CFGetTypeID` instead of force-cast (avoids trap on Electron/Catalyst hosts); `showToast` `NSPanel` styleMask gains `.borderless` for macOS 26 stricter validation (commit `c316482`).
- **deepseek-v4 model ID correction**: F-062 introduced a non-existent bare `deepseek-v4` ID (404 on call). Removed; `deepseek-v4-flash` and `deepseek-v4-pro` retained (commit `75a9ff7`).
- **iOS keyboard fixes**: System light/dark appearance now followed; broken suspend trick replaced with activation overlay; IPC first-tap race condition gets a grace period; mic tap with empty config no longer crashes.
- **iOS build warnings**: Deprecated API and actor isolation warnings cleared.

### Removed

- **iOS OAuth UI**: F-058/F-059/F-060 OAuth ships macOS-only; iOS-side OAuth Card views were not shipped (commit `5619912`).

## [0.2.0.0] — 2026-03-29

### Added

**STT Providers (4 new):**
- **STT Adapter Architecture** (F-039): `STTAdapter` protocol with OpenAI, Volcengine, and Qwen adapters — WhisperService refactored from monolithic service to pluggable router.
- **Deepgram STT** (F-040): Nova-3 and Nova-2 models with native Deepgram protocol (Token auth + raw binary upload), 36+ language support.
- **Sherpa Offline ASR** (F-048): Scaffold with `SherpaSTTAdapter`, `SherpaModelManager`, and 3 model definitions — pending sherpa-onnx XCFramework integration for fully offline speech recognition.
- **iFlytek STT** (F-049): WebSocket streaming with HMAC-SHA256 authentication, PCM 16kHz framed upload, 23 Chinese dialect support.

**Polish Providers (4 new):**
- **Gemini Polish** (F-043): Google Gemini integration with gemini-2.0-flash default and 3 preset models.
- **Claude Polish** (F-044): Anthropic native Messages API with SSE streaming and x-api-key authentication.
- **Zhipu GLM Polish** (F-047): glm-4-flash default with 3 preset models, OpenAI-compatible API.
- **MLX Server** (F-050): Local inference via oMLX/mlx-lm/vllm-mlx on localhost:8010/v1 — no API key required, 4 preset models with RAM usage hints.

**Core Capabilities (5 new):**
- **Provider Registry** (F-041): `providers.json` + `ProviderDefinition` + `ProviderRegistry` — adding a new provider is now a JSON edit. APIProvider reduced from 329 to 135 lines.
- **Prompt Context Variables** (F-045): `{selected}` and `{clipboard}` placeholders in prompts with AX API 200ms timeout protection, plus built-in Command mode.
- **Think Tag Cleanup** (F-046): `strippingThinkTags()` String extension — automatically removes `<think>...</think>` blocks from LLM output.
- **Text Replacement & Dictionary Correction** (F-051): `ReplacementManager` with trigger→replacement rules, flex pattern matching for Chinese/English, dual-position replacement (post-STT + post-LLM), LLM vocabulary injection, macOS and iOS UI.
- **Auto Dictionary Learning** (F-053): macOS only — paste-then-AX two-snapshot comparison detects user corrections and auto-adds them to Replacement dictionary with Toast notification.

**Speed:**
- **Speculative LLM** (F-033): Pre-warms HTTP connections during recording and pre-builds STT requests — saves ~200–500ms per dictation cycle.
- **ASR Hotword Boosting** (F-034): Tag cloud UI (`WrappingHStack`) for managing hotwords, single/batch add, 8 seed examples on first install.

**UI/UX (5 new):**
- **Scene Management UI** (F-029 Phase 2): Card grid layout with edit sheet and full CRUD for managing scenes.
- **Sound Feedback System** (F-035): Pure-code WAV generation for start/success/error sounds, `warmUp()` preload, and General settings toggle.
- **Design Tokens** (F-036): `VW` enum with `Spacing`, `Radius`, `Anim`, and `Colors` — migrated SettingsComponents and RecordingOverlay.
- **Recording Indicator Engine** (F-052): Orb Pulse breathing light orb with declarative SwiftUI animation.
- **Enhanced Overview** (F-038): 2×2 stats grid with time saved and words-per-minute metrics.

**Platform:**
- **Multi-platform architecture**: Refactored into VowriteKit (shared core) + VowriteMac + VowriteIOS — all three targets build independently.
- **iOS Keyboard Extension** (F-032): Complete keyboard extension with voice input, mode/style switching, and text insertion via `textDocumentProxy`.
- **iOS Container App**: Dashboard, Settings, Personalization, History, Onboarding, and Keyboard Setup Guide views.
- **iOS Parity**: F-029, F-033, F-035, F-038, F-045 ported to iOS keyboard extension.
- **Settings Reorganization** (F-037): Sidebar expanded from 6 to 7 pages (Overview, General, History, API Keys, Models, Personalization, About).
- **Volcengine & Qwen providers** (F-038): Full STT + Polish support with KeyVault integration.

### Changed
- **WhisperService** refactored from monolithic service to adapter-based router pattern (F-039).
- **APIProvider** reduced from 329 to 135 lines via `providers.json` data-driven registry (F-041).
- **README** updated for multi-platform architecture and 15+ providers.

### Removed
- **VowriteApp (legacy) deleted**: All 38 Swift files (6795 lines) fully superseded by VowriteKit (37 files) + VowriteMac (24 files). VowriteKit also added 12 new files (Protocols, DictationEngine, IPC, etc.) that VowriteApp never had. Freed ~370MB including build cache.
- **ops scripts migrated**: `clean.sh`, `beta-build.sh`, `test.sh` now reference VowriteKit/VowriteMac instead of VowriteApp.

### Fixed
- Rebuilt iOS xcodeproj (resolved ID conflicts and missing build phases).
- Restored Sparkle auto-update toggle in macOS Settings after refactor.
- Fixed iOS voice input (`AVAudioRecorder.record()` returning false).
- Fixed iOS input UI — empty input handling, duplicate bottom bar, setting button active/inactive states.
- Fixed keyboard extension compile errors and Xcode build errors.

## [0.1.9.2] — 2026-03-25

### Fixed
- **Sparkle auto-update toggle**: Fixed "Automatic Updates" toggle not responding in About page — `MacUpdateManager` refactored to `ObservableObject` with Combine KVO bindings for proper SwiftUI reactivity.
- **Updater not starting**: Changed `startingUpdater: false` → `true` so Sparkle performs background update checks on app launch.
- **"Check Now" button**: Now disables during an active check to prevent duplicate requests.

### Added
- **Auto-update infrastructure complete** (F-026): EdDSA-signed appcast.xml with v0.1.9.1 entry, enabling end-to-end Sparkle updates via GitHub Releases + GitHub Pages.
- **release.sh automation**: Automatic EdDSA DMG signing, appcast.xml generation, CFBundleVersion auto-increment, and interactive GitHub Release creation.

## [0.1.9.1] — 2026-03-24

### Added
- **New Providers** (F-030): Added SiliconFlow, Kimi, and MiniMax support:
  - **SiliconFlow (硅基流动)** — STT (SenseVoice) + Polish (Qwen/DeepSeek/GLM)
  - **Kimi (月之暗面)** — Polish only (kimi-k2.5, moonshot series)
  - **MiniMax** — Polish only (MiniMax-Text-02)
- **SiliconFlow + Kimi preset**: One-click setup with SiliconFlow SenseVoice STT + Kimi kimi-k2.5 Polish.
- Model descriptions for all new provider models in the settings UI.

### Changed
- **Provider header logic centralized**: Extracted provider-specific HTTP headers into `APIProvider.applyHeaders(to:)` — cleaner code, easier to extend.
- Added `isOpenAICompatible` marker on `APIProvider` for future non-OpenAI protocol support.

### Removed
- **F-031 (Provider Protocol Abstraction) cancelled**: After evaluation, all current and planned providers use OpenAI-compatible APIs. Protocol abstraction is over-engineering at this stage — will be introduced when a non-OpenAI protocol (e.g. 讯飞 WebSocket) is actually needed.

## [0.1.9.0] — 2026-03-18

### Added
- **Key Vault** (F-028): API keys are now stored per-provider in macOS Keychain. Enter once, reuse everywhere — no more duplicate key entries for STT and Polish.
- **Unified Split Config** (F-028): STT and Polish always have independent provider/model selection. Removed the confusing "single provider" vs "dual provider" toggle.
- **API Presets** (F-028): 3 built-in presets (⭐ Recommended: Groq STT + DeepSeek Polish, OpenAI All-in-One, Local Ollama) for one-click API setup.
- **Personalization Quick Presets** (F-029): 5 preference presets (Business, Casual, Academic, Creative, Technical) that fill your custom prompt with one click.
- **Save/Edit/Lock for Preferences** (F-029): Your custom preferences now have clear save/edit/lock states — no more wondering if changes took effect.
- **"How it works" guide** (F-029): Inline explanation of how preferences and modes work together.

### Changed
- **Settings UI redesign** (F-029): Card-based sections, adaptive layout, improved dark/light mode support.
- **Onboarding updated** for new API config flow.

### Removed
- **Scene system removed** (F-029): Output Scene was redundant with the Mode system. Replaced by Quick Presets for preferences + Mode for output formatting.
- **DualAPIConfig removed** (F-028): Superseded by the cleaner Unified Split Config.
- **Old SettingsView removed**: Replaced by integrated MainWindowView settings pages.

## [0.1.8.3] — 2026-03-15

### Fixed
- **Custom model picker**: Selecting "Custom..." in model pickers now correctly shows a text input field. Previously the picker would revert selection due to a missing tag binding.

## [0.1.8.2] — 2026-03-15

### Fixed
- **Settings window not opening**: Clicking "Settings..." in the menu bar now reliably opens the settings window. Replaced unreliable `showSettingsWindow:` selector with direct `NSWindow` creation, fixing a race condition where the activation policy check would hide the window before it appeared.

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

[Unreleased]: https://github.com/Joevonlong/Vowrite/compare/v0.2.1.2...HEAD
[0.2.1.2]: https://github.com/Joevonlong/Vowrite/compare/v0.2.1.1...v0.2.1.2
[0.2.1.1]: https://github.com/Joevonlong/Vowrite/compare/v0.2.1.0...v0.2.1.1
[0.2.1.0]: https://github.com/Joevonlong/Vowrite/compare/v0.2.0.1...v0.2.1.0
[0.2.0.1]: https://github.com/Joevonlong/Vowrite/compare/v0.2.0.0...v0.2.0.1
[0.2.0.0]: https://github.com/Joevonlong/Vowrite/compare/v0.1.9.2...v0.2.0.0
[0.1.9.2]: https://github.com/Joevonlong/Vowrite/compare/v0.1.9.1...v0.1.9.2
[0.1.9.1]: https://github.com/Joevonlong/Vowrite/compare/v0.1.9.0...v0.1.9.1
[0.1.9.0]: https://github.com/Joevonlong/Vowrite/compare/v0.1.8.3...v0.1.9.0
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
