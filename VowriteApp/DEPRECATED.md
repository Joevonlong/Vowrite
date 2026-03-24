# ⚠️ VowriteApp — Legacy (Deprecated)

> **Status:** Deprecated since multi-platform refactor (2026-03-19)
> **Replacement:** VowriteKit (shared core) + VowriteMac (macOS app) + VowriteIOS (iOS app)

## Why is this still here?

The release scripts (`scripts/release.sh` and `ops/scripts/release.sh`) still reference
`VowriteApp/` for building the macOS release binary, app bundle, and code signing.

**Before this directory can be removed:**
1. Migrate release scripts to build from `VowriteMac/` instead
2. Set up proper Xcode project or SPM-based app bundle creation for VowriteMac
3. Verify code signing, Sparkle embedding, and DMG packaging work with new paths
4. Update all CI/CD references

## What's duplicated?

All files under `VowriteApp/Core/` and `VowriteApp/Views/` have been migrated to:
- `VowriteKit/Sources/` — shared business logic
- `VowriteMac/Sources/` — macOS-specific views and platform code

**Do NOT edit files in VowriteApp/ for new features.** All new development goes into
VowriteKit/VowriteMac/VowriteIOS.
