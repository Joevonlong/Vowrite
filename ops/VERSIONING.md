# Versioning, Changelog & Commit Standards

This document defines **all** versioning, changelog, and commit conventions for Vowrite.
All contributors and automation scripts must follow these rules.

---

## 1. Version Number Format

**4-segment:** `MAJOR.MINOR.PATCH.BUILD`

| Segment | Name | When to Increment | Git Tag | Changelog Entry |
|---------|------|-------------------|---------|-----------------|
| 1st | MAJOR | Product era change, fundamental redesign, 1.0 launch | ✅ | ✅ |
| 2nd | MINOR | Product stage milestone (MVP→Beta→RC) | ✅ | ✅ |
| 3rd | PATCH | Accumulated batch of user-facing features | ✅ | ✅ |
| 4th | BUILD | Bugfixes, infra improvements, provider additions, polish | ✅ | ✅ |

> **Global standard:** See `~/Dev_Workspace/VERSIONING.md` for cross-project rules.

### Rules

1. **BUILD** — Bugfixes, infrastructure, provider additions, polish. Create tag + changelog entry.
2. **PATCH** — Bump when shipping a meaningful batch of user-facing features. A PATCH bump should feel like "this is a noticeable update worth announcing". Don't bump for every single feature. Reset BUILD to 0.
3. **MINOR** — Only when reaching a defined product milestone (0.1=MVP, 0.2=Beta, etc.). Reset PATCH and BUILD to 0.
4. **MAJOR** — Extremely rare. 0.x = pre-release, 1.0 = first stable public release. Reset all others to 0.

### Anti-patterns

- ❌ Bumping PATCH for a single feature addition (use BUILD)
- ❌ Bumping MINOR just because PATCH reached .9
- ❌ Skipping BUILD for small changes and going straight to next PATCH

### Current Version

```
v0.1.8.1
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

## 7. Beta Versions

### Format

```
X.Y.Z.W-beta.N
```

Where `N` is the beta iteration number (1, 2, 3...).

### Examples

```
v0.1.9.0-beta.1   First beta of 0.1.9.0
v0.1.9.0-beta.2   Second beta (bugfixes from beta.1 feedback)
v0.1.9.0           Stable release (same content as final beta, minus -beta suffix)
```

### Beta vs Stable

| | Beta | Stable |
|---|---|---|
| **Purpose** | Early testing, gathering feedback | Production-ready release |
| **Audience** | Testers, power users | All users |
| **Appcast** | `docs/appcast-beta.xml` | `docs/appcast.xml` |
| **GitHub Release** | `--prerelease` flag | Normal release |
| **CHANGELOG** | Optional (entries kept in [Unreleased]) | Required |
| **Git tag** | `v0.1.9.0-beta.1` | `v0.1.9.0` |

### Beta → Stable Promotion

To promote a beta to stable, simply release the same version without the `-beta.N` suffix:

```bash
# Beta
ops/scripts/release.sh v0.1.9.0-beta.1 "Beta: new feature X"

# Promote to stable (after beta testing is done)
ops/scripts/release.sh v0.1.9.0 "New feature X"
```

### Pre-release Tags (Other)

```
v0.2.0.0-rc1      Release candidate
```

---

## 8. Branch Strategy

```
main              ← Default branch. Daily development + tagged releases.
  └─ feature/xxx  ← Feature branches for larger changes.
```

| Branch | Purpose | Push directly? |
|--------|---------|---------------|
| `main` | Development + releases (tagged) | ✅ Small fixes, docs, chores |
| `feature/xxx` | Larger features or experiments | ✅ Freely, then squash merge to main |

Releases are identified by **git tags**, not by branches.

### Feature workflow

```bash
git checkout main && git pull
git checkout -b feature/my-feature
# ... develop and commit freely ...
git checkout main
git merge --squash feature/my-feature
git commit -m "feat: short description"
git push origin main
git branch -d feature/my-feature
```

### Release workflow

```bash
ops/scripts/release.sh v0.1.6.0 "Short description"
git push origin main --tags
gh release create v0.1.6.0 releases/Vowrite-v0.1.6.0.dmg --title "..."
```

---

## Quick Reference

```
Daily work:     git checkout main
                feat: add new feature → commit → push
                (add notable items to [Unreleased] in CHANGELOG.md)

Big feature:    git checkout -b feature/xxx → develop → squash merge to main

Release:        ops/scripts/release.sh v0.1.6.0 "description"
                → auto: version bump + changelog + build + commit + tag
                → manual: git push origin main --tags + gh release create
```
