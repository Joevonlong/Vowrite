# Vowrite Core Process Overview

All development, testing, and release activities follow this process. Each phase has corresponding checklists and scripts.

---

## Process Overview

```
Develop → Test → Cleanup → Build → Sign → Package → Release → Notify
 │        │       │        │       │       │        │        │
 ▼        ▼       ▼        ▼       ▼       ▼        ▼        ▼
Code    Feature  Security  Release  codesign  DMG    GitHub   Website
Changes  Verify  Review    Build   +Notarize  Gen   Release  Update
```

---

## Phase 1: Development

### Branch Strategy
- `main` — Stable branch, only accepts tested code
- `dev` — Daily development (optional, small projects can develop directly on main)
- `feature/xxx` — Feature branches (for larger features)

### Language Standards

The project targets the international market. **The official language is English.** The following content must be in English:

| Content | Requirement |
|---------|-------------|
| Git Commit Messages | English (type label + English description) |
| Release Notes / Description | English |
| Bug Reports (GitHub Issues) | English |
| GitHub Repo Description, README, Wiki | English |
| Documentation for final publication | English |
| Code Comments | English |

> 📝 Daily communication (Discord, chat) can be in Chinese, but all content committed to the repository must be in English.

### Commit, Versioning & Changelog Standards

All conventions are defined in **[`ops/VERSIONING.md`](VERSIONING.md)**. Key points:

- **Commit format:** `<type>: <short description in English>`
- **Version releases:** `v0.1.6.0: short summary`
- **Changelog:** Maintain `[Unreleased]` section in `CHANGELOG.md` during development
- **Release:** Run `ops/scripts/release.sh` to automate version bump + changelog + tag + build

```
Types:
- feat: new feature
- fix: bug fix
- refactor: refactoring
- docs: documentation
- chore: build/tooling/misc
- security: security-related
```

### Development Build
```bash
cd VowriteApp && ./build.sh
```

---

## Phase 2: Testing

### Automated Tests
```bash
ops/scripts/test.sh
```

### Manual Test Matrix

| Test Item | Description | Pass |
|-----------|-------------|------|
| OpenAI STT | whisper-1 transcription for Chinese/English | ☐ |
| AI Polish | gpt-4o-mini polishing | ☐ |
| Polish failure fallback | Uses raw text when offline or out of quota | ☐ |
| Clipboard injection | With Accessibility permission | ☐ |
| Unicode injection | Without Accessibility permission | ☐ |
| Hotkey | Default ⌥Space + custom | ☐ |
| Menu bar | Icon/menu/status display | ☐ |
| Recording bar | Display/waveform/doesn't steal focus | ☐ |
| History | Save/view | ☐ |
| Microphone switching | Multi-microphone selection | ☐ |
| Long recording | >60 seconds recording | ☐ |
| First launch | Guidance when no API Key | ☐ |
| Error handling | No network/no permission/timeout | ☐ |

---

## Phase 3: Security Cleanup

See `CHECKLIST_SECURITY.md`. Must be executed before each release.

Core requirements:
- No API Key leaks in code or Git history
- NSLog debug messages disabled in release builds
- Keychain storage is secure
- No hardcoded credentials

---

## Phase 4: Build

### Release Build
```bash
ops/scripts/release.sh <version>
# e.g.: ops/scripts/release.sh v0.1.5.0
```

The script automatically performs:
1. `swift build -c release` optimized compilation
2. Copy binary to Vowrite.app
3. Code signing (signs + notarizes with Developer ID if available, otherwise ad-hoc)
4. Package DMG
5. Generate Changelog
6. Git commit + tag

---

## Phase 5: Release

### Current Phase: GitHub Release
1. `ops/scripts/release.sh` completes packaging
2. Create Release on GitHub with DMG attached
3. Update RELEASE_NOTES.md

### Future Phase: Signing + Notarization
1. Register as Apple Developer ($99/year)
2. Sign with Developer ID
3. `xcrun notarytool submit` for notarization
4. `xcrun stapler staple` to staple the notarization ticket
5. Package DMG for distribution

### Distribution Channels
- [ ] GitHub Releases (primary)
- [ ] Website download page
- [ ] Homebrew Cask (future)

---

## Phase 6: Post-Release

### Notifications
- Update website download link and version number
- Update version information in README.md
- (Future) Push automatic updates via Sparkle

### Monitoring
- Check GitHub Issues
- Collect user feedback
- Monitor crash reports (integrate Sentry etc. in the future)

---

## Quick Reference

| What I Want To Do | What To Run |
|-------------------|-------------|
| Daily development build | `cd VowriteApp && ./build.sh` |
| Run tests | `ops/scripts/test.sh` |
| Release a new version | `ops/scripts/release.sh v0.x.y.z` |
| Clean build artifacts | `ops/scripts/clean.sh` |
| Check security | Review `ops/CHECKLIST_SECURITY.md` |
| Pre-release check | Review `ops/CHECKLIST_RELEASE.md` |
