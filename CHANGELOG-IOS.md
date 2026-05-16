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

- **Voice/Keyboard Mode Toggle (F-075)**: A two-segment pill toggle in the top-right corner of the keyboard extension switches between voice dictation and a full custom QWERTY keyboard. Voice mode preserves all existing behavior (dictation, translation, long-press chip selection). Keyboard mode supports letters, numbers, and symbols with shift/caps-lock state, continuous delete, and a globe key in the bottom row for input method switching. The delete button is relocated to a new bottom row (voice idle state) alongside a return key, preserving the full long-press bulk-delete behavior (F-067).

- **F-074 Vocabulary CSV import/export**: Personalization → Personal Vocabulary now has Import (↓) and Export (↑) toolbar buttons in the section header. Exported files share the same single-column CSV format as macOS, so vocabulary maintained on either platform round-trips cleanly. Imported words sync to the iOS keyboard extension via the existing App Group reload path — no app restart required.

### Changed

- **F-072 Polish output style is more assertive (Typeless-inspired)**: The shared polish prompt now treats your dictation as a rough draft. Output is more concise and structured — short paragraphs by default, bullets when you enumerate two or more items, the main point surfaced first when you buried it. Mixed-language preservation (中英混合) is unchanged. If you want a near-passthrough record, the iOS keyboard's Dictation mode disables polish entirely.

### Performance

- **F-073 Polish skips reasoning on thinking-by-default models**: Same shared improvement as macOS — polish requests to reasoning models (DeepSeek V4-pro, Qwen 3.5/3.6, GPT-5.5, Gemini 2.5, Kimi K2.6, Doubao thinking, GLM-5 family, MiniMax M2/M2.5/M2.7, etc.) skip chain-of-thought, typically saving 5–30 seconds per polish on the iOS keyboard.

### Fixed

- **Keyboard UI matches the Typeless reference layout, with full light/dark adaptation**: Voice mode now shows a compact dark "换行" pill plus a rounded-rect delete key (no more edge-to-edge white bar); keyboard mode gives the return key a prominent inverted accent treatment, trims the space bar, and adds the `拼` input-method hint. The record pill and return key now use an inverting accent (white-on-dark in dark mode, black-on-white in light mode) so no element is ever an invisible white-on-white or black-on-black; all key fills and text ride the system gray/label ramp and follow the system appearance. Keys adopt a softer continuous-corner squircle. (Previously the record pill and return key were hardcoded dark and went unreadable in light mode.)

- **Voice-mode "换行" is now truly centered under the mic**: it is a fixed-width pill horizontally centered on screen so it lines up with the record pill directly above it, with the delete key pinned independently to the right. (Previously it was an HStack centered as a group, which pushed 换行 left-of-center — matching the Typeless reference, 换行 must be screen-centered and delete must not shift it.)

- **System dictation microphone suppressed**: the keyboard now declares itself multilingual + ASCII-capable (`PrimaryLanguage = mul`, `IsASCIICapable = YES`) so iOS no longer renders its system dictation mic in the bottom keyboard dock — matching the behavior of comparable dictation keyboards.

### Removed
