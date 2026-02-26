# Version Numbering and Changelog Standards

---

## Version Number Format

Uses a **four-segment version number**: `vMAJOR.MINOR.PATCH.BUILD`

| Segment | Name | When to Increment | Example |
|---------|------|-------------------|---------|
| 1st | MAJOR | Incompatible major changes, significant architecture changes | v1.0.0.0 → v2.0.0.0 |
| 2nd | MINOR | New feature modules, major feature launches | v0.1.0.0 → v0.2.0.0 |
| 3rd | PATCH | Feature improvements, multiple small updates accumulated for one release | v0.1.1.0 → v0.1.2.0 |
| 4th | BUILD | Daily small updates: bug fixes, UI tweaks, copy changes, etc. | v0.1.1.1 → v0.1.1.2 |

### Rules

1. **Daily incremental updates** → Only increment BUILD (4th segment), e.g., `v0.1.1.1` → `v0.1.1.2`
2. **Accumulated small updates** forming meaningful improvements → Increment PATCH (3rd segment), reset BUILD to zero, e.g., `v0.1.1.5` → `v0.1.2.0`
3. **New feature module launch** → Increment MINOR (2nd segment), reset last two segments to zero
4. **Major architecture change** → Increment MAJOR (1st segment), reset last three segments to zero

### Current Version Line

```
v0.x.x.x — Early development stage, rapid feature iteration
v1.0.0.0 — First official release (signed + notarized + website)
```

### Pre-release Tags (Optional)

```
v0.2.0.0-beta    Beta version
v0.2.0.0-rc1     Release candidate
```

---

## RELEASE_NOTES Format

- **PATCH and above**: Add a full entry in `RELEASE_NOTES.md`
- **BUILD updates**: No separate entry; merge into the next PATCH release. Daily commit messages should be clear enough

This avoids incremental updates cluttering up the changelog.

---

## Tag Standards

- **PATCH and above**: Create a Git tag, e.g., `v0.1.2.0`
- **BUILD updates**: No tag, just regular commits
- Use annotated tags: `git tag -a v0.1.2.0 -m "v0.1.2 — Feature description"`
- Tags go on the release commit, not on intermediate commits

---

## Changelog Standards

Each PATCH+ version's changes are recorded in `RELEASE_NOTES.md` with this format:

```markdown
## vX.Y.Z — Title

**Release Date:** YYYY-MM-DD

### New Features
- feat: description

### Fixes
- fix: description (including fix summaries from BUILD period)

### Improvements
- refactor/chore: description

### Known Issues
- description
```

---

## Version Number Update Locations

For each release (PATCH+), version numbers must be updated in sync at the following locations:

1. `VowriteApp/Resources/Info.plist` → `CFBundleShortVersionString`
2. `VowriteApp/Views/SettingsView.swift` → Version display in `AboutTab`
3. `RELEASE_NOTES.md` → New version entry
4. `README.md` → Version history section
5. `Git tag`

BUILD updates only need a commit; syncing all the above locations is not required.

`ops/scripts/release.sh` handles most of this automatically, but please confirm in the checklist.
