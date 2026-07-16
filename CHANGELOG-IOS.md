# Changelog — iOS

All notable iOS-relevant changes are tracked here.

The format is based on [Keep a Changelog](https://keepachangelog.com).

> **Status:** iOS does not yet have a public distribution channel. Entries
> accumulate under `[Unreleased]` until the first iOS release ships (TestFlight
> or App Store). At that point the section will be promoted to a versioned
> entry and this file will become a regular per-release changelog.
>
> See `CHANGELOG.md` for macOS releases.
> See `docs/superpowers/specs/2026-05-04-platform-release-separation-design.md`
> in the workspace repo for the routing policy.

## [Unreleased]

### Added

- **F-082 Model catalog refresh + new providers**: The iOS Settings provider/model pickers gain the same 2026-07 refresh as macOS — Claude Sonnet 5, GPT-5.6, Gemini 3.x, Qwen 3.7, GLM-5.2, MiniMax M3, Doubao Seed 2.1 — plus new providers xAI (Grok), Cerebras (free tier), and Baidu Qianfan, and OpenRouter speech-to-text. All shared-catalog changes (thinking pre-disabled, retired IDs removed) apply identically to the keyboard's dictation pipeline.
- **F-077 Command template library**: The Modes section gains a "From Template" entry offering the same 15 built-in command templates as macOS, pre-filling the Mode editor. Note: iOS cannot capture the host app's selected text today, so selection-based commands only reach full value on macOS until Speak-to-Edit lands (I-030).

- **F-079 Language region variants**: Language pickers in Settings, Personalization, and the Mode editor gain a second-level region choice (中文 简体/繁體台灣/繁體香港, English US/UK/AU, Español, Português, Français variants), matching macOS. Traditional-Chinese variants bias recognition and polish output accordingly.

- **F-080 Personalization visibility**: Personalization gains a Learning section mirroring macOS — learned-rule/vocabulary counts, the three most recent learned corrections, the learning master toggle, and Clear Learned Data. Counts are per-device; auto-learning itself currently runs on macOS only (corrections learned there don't sync to iOS).

- **F-078 Markdown output style**: The shared style catalog gains a built-in "Markdown" output style (GitHub-flavored: headings, lists, bold, inline code, fenced code blocks from spoken cues). It appears automatically in the iOS style picker and the keyboard picks it up like any other style.

- **Voice/Keyboard Mode Toggle (F-075)**: A two-segment pill toggle in the top-right corner of the keyboard extension switches between voice dictation and a full custom QWERTY keyboard. Voice mode preserves all existing behavior (dictation, translation, long-press chip selection). Keyboard mode supports letters, numbers, and symbols with shift/caps-lock state, continuous delete, and a globe key in the bottom row for input method switching. The delete button is relocated to a new bottom row (voice idle state) alongside a return key, preserving the full long-press bulk-delete behavior (F-067).

- **F-074 Vocabulary CSV import/export**: Personalization → Personal Vocabulary now has Import (↓) and Export (↑) toolbar buttons in the section header. Exported files share the same single-column CSV format as macOS, so vocabulary maintained on either platform round-trips cleanly. Imported words sync to the iOS keyboard extension via the existing App Group reload path — no app restart required.

### Changed

- **F-072 Polish output style is more assertive (Typeless-inspired)**: The shared polish prompt now treats your dictation as a rough draft. Output is more concise and structured — short paragraphs by default, bullets when you enumerate two or more items, the main point surfaced first when you buried it. Mixed-language preservation (中英混合) is unchanged. If you want a near-passthrough record, the iOS keyboard's Dictation mode disables polish entirely.

### Performance

- **F-073 Polish skips reasoning on thinking-by-default models**: Same shared improvement as macOS — polish requests to reasoning models (DeepSeek V4-pro, Qwen 3.5/3.6, GPT-5.5, Gemini 2.5, Kimi K2.6, Doubao thinking, GLM-5 family, MiniMax M2/M2.5/M2.7, etc.) skip chain-of-thought, typically saving 5–30 seconds per polish on the iOS keyboard.

### Fixed

- **Stored DeepSeek legacy aliases migrate automatically before the upstream shutdown**: same one-time migration as macOS (`deepseek-chat` / `deepseek-reasoner` → `deepseek-v4-flash`, upstream sunset 2026-07-24), registered in the iOS app entry point so keyboard dictation keeps working without touching settings.
- **A failed AI polish or translation now shows a warning banner instead of silently typing the raw transcript**: If the polish/translate provider fails (e.g. an API key with no remaining credit), the keyboard still inserts the raw transcription as a fallback — but previously gave zero indication, so a "translation" that was actually the untranslated original looked like a success. The keyboard now shows a transient orange banner ("润色失败，已输入原文" / "翻译失败，已输入原文") for ~3 seconds after inserting the fallback text. Distinct from the red error state, which still means nothing was inserted. The failure is also logged visibly (os.Logger) instead of a debug-only print.

- **Stale dictation can no longer be typed into the wrong app**: the keyboard and the background recording service now tag every recording with a session id. Dismissing the keyboard while a dictation is finishing (or failing) up used to leave that result sitting around; the next time you tapped the mic, the very first status check could catch the *old* result and paste it into whatever app you'd since switched to, while silently dropping the new recording. Mismatched sessions are now discarded instead of inserted. Dismissing the keyboard while actively recording also stops the microphone immediately instead of leaving it running in the background.

- **Keyboard UI matches the Typeless reference layout, with full light/dark adaptation**: Voice mode now shows a compact dark "换行" pill plus a rounded-rect delete key (no more edge-to-edge white bar); keyboard mode gives the return key a prominent inverted accent treatment, trims the space bar, and adds the `拼` input-method hint. The record pill and return key now use an inverting accent (white-on-dark in dark mode, black-on-white in light mode) so no element is ever an invisible white-on-white or black-on-black; all key fills and text ride the system gray/label ramp and follow the system appearance. Keys adopt a softer continuous-corner squircle. (Previously the record pill and return key were hardcoded dark and went unreadable in light mode.)

- **Voice-mode "换行" is now truly centered under the mic**: it is a fixed-width pill horizontally centered on screen so it lines up with the record pill directly above it, with the delete key pinned independently to the right. (Previously it was an HStack centered as a group, which pushed 换行 left-of-center — matching the Typeless reference, 换行 must be screen-centered and delete must not shift it.)

- **System dictation microphone hidden (F-076)**: the bottom-right system dictation mic is suppressed by declaring the keyboard multilingual + ASCII-capable in `Info.plist` (`PrimaryLanguage = mul`, `IsASCIICapable = YES`) — the same approach Typeless uses; iOS then renders only the next-keyboard globe in its system dock, no dictation mic. The keyboard backdrop stays clear so the system keyboard backdrop shows through as **one uniform tone edge-to-edge** (no custom opaque override, no two-tone seam), and the keyboard draws **no globe of its own** (the system dock already provides one — drawing our own duplicated it). A build-time guard (`ops/scripts/test.sh`) fails the suite if the plist declaration is reverted. Note: changing `Info.plist` extension attributes requires removing and re-adding the keyboard in iOS Settings for the change to take effect.

- **Translate-mode override no longer leaks into the next dictation**: if the recording file failed to open right after starting a one-shot translate recording, the one-shot Mode override wasn't cleared, so the *next* plain dictation could silently run as a translation. That failure path now clears the override, matching every other recording exit.

- **Background recording now defaults to a 5-minute session on first activation, not an indefinite one**: a first-time user (or a fresh install) previously got an "Always on" mic session because the unset duration preference and the explicit "Always" duration shared the same stored value (0). Users who have explicitly chosen "Always" keep that setting.

- **Keyboard no longer hangs forever if Vowrite is killed in the background**: if the main app process dies while a dictation is recording or processing, the keyboard now detects the lost service heartbeat and shows "Vowrite stopped in background" instead of freezing on the recording/processing screen indefinitely.

- **API keys save once you're done typing, not on every keystroke**: Settings no longer writes a partial key to Keychain on each character typed or pasted. Keys now save when you submit, move to another field, or leave the Settings screen.

### Removed
