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

- **F-074 Vocabulary CSV import/export**: Personalization → Personal Vocabulary now has Import (↓) and Export (↑) toolbar buttons in the section header. Exported files share the same single-column CSV format as macOS, so vocabulary maintained on either platform round-trips cleanly. Imported words sync to the iOS keyboard extension via the existing App Group reload path — no app restart required.

### Changed

- **F-072 Polish output style is more assertive (Typeless-inspired)**: The shared polish prompt now treats your dictation as a rough draft. Output is more concise and structured — short paragraphs by default, bullets when you enumerate two or more items, the main point surfaced first when you buried it. Mixed-language preservation (中英混合) is unchanged. If you want a near-passthrough record, the iOS keyboard's Dictation mode disables polish entirely.

### Fixed

### Removed
