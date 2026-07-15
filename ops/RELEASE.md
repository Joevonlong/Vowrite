# Release Process

> **Canonical pipeline:** `ops/scripts/release.sh` (platform-aware, Sparkle appcast + EdDSA signing).
> The legacy `scripts/release.sh` was removed 2026-07 — it skipped the appcast and CFBundleVersion bump and auto-pushed without confirmation.

## Commands

```bash
# Beta (updates appcast-beta.xml)
cd Vowrite && ops/scripts/release.sh --beta v0.2.2.0-beta.1 "Beta description"

# Stable (updates appcast.xml)
cd Vowrite && ops/scripts/release.sh v0.2.2.0 "Release description"

git push origin main --tags
```

## What the script does (in order)

1. **Preflight** — lists commits since last tag, classifies per platform (mac/ios/shared/mixed/meta), asks 3 confirmation gates (see CLAUDE.md "Multiplatform Release Policy")
2. **CHANGELOG** — promotes `[Unreleased]` to the new version section
3. **Version bump** — `Resources/Info.plist` (CFBundleShortVersionString + CFBundleVersion) and `VowriteKit/Sources/VowriteKit/Version.swift`
4. **Build** — `swift build -c release`, assemble `Vowrite.app`
5. **Sign** — codesign with entitlements (self-signed cert `vowrite` keychain)
6. **Package** — DMG with Applications symlink + install.sh
7. **Sparkle** — EdDSA-sign the DMG, update `docs/appcast.xml` (or `appcast-beta.xml`)
8. **Git** — commit, annotated tag
9. **GitHub Release** — uploads DMG, notes from CHANGELOG

Details on gates and CHANGELOG routing: `ops/CHECKLIST_RELEASE.md` and root `CLAUDE.md`.

## Version format

`MAJOR.MINOR.PATCH.BUILD` — see [VERSIONING.md](VERSIONING.md). BUILD bumps get no tag/changelog; PATCH+ gets tag + changelog entry.

## Code signing

Currently self-signed (users right-click → Open on first launch). Future: Developer ID + notarization.
