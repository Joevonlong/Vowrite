# Versioning, Changelog & Commit Standards

This document defines **all** versioning, changelog, and commit conventions for Vowrite.
All contributors and automation scripts must follow these rules.

---

## 1. Version Number Format

**4-segment:** `MAJOR.MINOR.PATCH.BUILD`

| Segment | Name | When to Increment | Git Tag | Changelog Entry |
|---------|------|-------------------|---------|-----------------|
| 1st | MAJOR | Incompatible architecture changes | ✅ | ✅ |
| 2nd | MINOR | New feature module launches | ✅ | ✅ |
| 3rd | PATCH | Accumulated improvements, meaningful release | ✅ | ✅ |
| 4th | BUILD | Daily: bug fixes, UI tweaks, copy changes | ❌ | ❌ (add to `[Unreleased]`) |

### Rules

1. **BUILD** — Increment only the 4th segment. No tag, no changelog entry. Add notable items to `[Unreleased]` in `CHANGELOG.md`.
2. **PATCH** — Increment 3rd segment, reset BUILD to 0. Create tag + changelog entry.
3. **MINOR** — Increment 2nd segment, reset PATCH and BUILD to 0. Create tag + changelog entry.
4. **MAJOR** — Increment 1st segment, reset all others to 0. Create tag + changelog entry.

### Current Version

```
v0.1.5.0
```

### Version Line

```
v0.x.x.x — Early development, rapid iteration
v1.0.0.0 — First official public release (signed + notarized + website)
```

---

## 2. Commit Message Convention

All commit messages **must be in English**.

### Format

```
<type>: <short description>
```

### Types

| Type | When to Use | Example |
|------|-------------|---------|
| `feat` | New feature | `feat: add real-time streaming transcription` |
| `fix` | Bug fix | `fix: resolve clipboard paste timing on Electron apps` |
| `docs` | Documentation only | `docs: update README badges` |
| `refactor` | Code restructure, no behavior change | `refactor: extract audio engine into separate module` |
| `chore` | Build, tooling, config | `chore: update release script for 4-segment versioning` |
| `security` | Security fix or improvement | `security: remove hardcoded API key from tests` |
| `style` | Code style, formatting | `style: fix indentation in SettingsView` |
| `test` | Tests | `test: add unit tests for WhisperService` |

### Version Release Commits

When releasing a PATCH+ version, the commit message format is:

```
v0.1.6.0: <short summary of the release>
```

This makes version releases clearly identifiable in `git log`.

---

## 3. Changelog Standard

### File: `CHANGELOG.md` (repository root)

Format follows [Keep a Changelog](https://keepachangelog.com).

### Categories (use only these 6)

| Category | When to Use |
|----------|-------------|
| `Added` | New features |
| `Changed` | Changes to existing features |
| `Fixed` | Bug fixes |
| `Removed` | Removed features |
| `Deprecated` | Soon-to-be-removed features |
| `Security` | Security fixes |

### Workflow

**During development (BUILD level):**
1. Write clear commit messages following the convention above
2. For notable changes, add a bullet to the `[Unreleased]` section in `CHANGELOG.md`

**When releasing (PATCH+ level):**
1. Run `ops/scripts/release.sh v0.1.6.0`
2. Script automatically:
   - Renames `[Unreleased]` → `[0.1.6.0] — YYYY-MM-DD`
   - Creates new empty `[Unreleased]` section
   - Updates version in `Info.plist` and `SettingsView.swift`
   - Commits as `v0.1.6.0: <description>`
   - Creates annotated git tag `v0.1.6.0`
   - Builds and packages DMG
3. After script: push with tags, create GitHub Release

### Entry Format

```markdown
## [0.1.6.0] — 2026-03-15

### Added
- Real-time streaming transcription via WebSocket

### Fixed
- Clipboard paste failing in Safari 18.2

### Changed
- Reduced audio buffer size for lower latency
```

### Bottom Links

Always maintain comparison links at the bottom of `CHANGELOG.md`:

```markdown
[Unreleased]: https://github.com/Joevonlong/Vowrite/compare/v0.1.6.0...HEAD
[0.1.6.0]: https://github.com/Joevonlong/Vowrite/compare/v0.1.5.0...v0.1.6.0
```

---

## 4. Version Number Update Locations

For each PATCH+ release, update version in **all** of these:

| Location | Field |
|----------|-------|
| `VowriteApp/Resources/Info.plist` | `CFBundleShortVersionString` |
| `VowriteApp/Views/SettingsView.swift` | Version display in AboutTab |
| `CHANGELOG.md` | New version entry |
| Git tag | `v0.1.x.0` |
| GitHub Release | Created with changelog content |

BUILD updates: commit only, no version sync needed.

---

## 5. Git Tag Standard

- **PATCH+ releases only** — no tags for BUILD updates
- **Annotated tags:** `git tag -a v0.1.6.0 -m "v0.1.6.0 — Short description"`
- **Tag on the release commit** (the `v0.1.6.0:` commit), not on intermediate commits
- **Push with tags:** `git push origin main --tags`

---

## 6. GitHub Release Standard

- Created for every PATCH+ release
- **Title:** `Vowrite v0.1.6.0 — Short Description`
- **Body:** Copy the changelog entry for this version
- **Assets:** Attach the DMG file
- Release is created automatically by `release.sh` (or manually via `gh release create`)

---

## 7. Pre-release Tags (Optional)

```
v0.2.0.0-beta     Beta version
v0.2.0.0-rc1      Release candidate
```

---

## 8. Branch Strategy

```
main              ← Release-only. Each commit = a squash-merged version release.
  └─ develop      ← Integration branch. All features merge here first.
       └─ feature/xxx  ← Individual feature branches.
```

| Branch | Purpose | Push directly? | Merges to |
|--------|---------|---------------|-----------|
| `main` | Production releases | ❌ Never | — |
| `develop` | Daily integration | ✅ Small fixes OK | `main` (squash merge via release.sh) |
| `feature/xxx` | Individual features | ✅ Freely | `develop` (squash merge) |

### Feature workflow

```bash
git checkout develop && git pull
git checkout -b feature/my-feature
# ... develop and commit freely ...
git checkout develop
git merge --squash feature/my-feature
git commit -m "feat: short description"
git push origin develop
git branch -d feature/my-feature
```

### Release workflow

```bash
git checkout develop
ops/scripts/release.sh v0.1.6.0 "Short description"
# Script auto: commit on develop → squash merge to main → tag → switch back to develop
git push origin main develop --tags
gh release create v0.1.6.0 releases/Vowrite-v0.1.6.0.dmg --title "..."
```

---

## Quick Reference

```
Daily work:     git checkout develop
                feat: add new feature → commit → push to develop
                (add notable items to [Unreleased] in CHANGELOG.md)

Big feature:    git checkout -b feature/xxx → develop → squash merge back

Release:        git checkout develop
                ops/scripts/release.sh v0.1.6.0 "description"
                → auto: version bump + changelog + build + merge to main + tag
                → manual: git push origin main develop --tags + gh release create
```
