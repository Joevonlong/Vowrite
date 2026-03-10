# Release Process

## One-Command Release

```bash
./scripts/release.sh <version>
```

Example:
```bash
./scripts/release.sh 0.1.8.0
```

## What It Does (in order)

| Step | Action |
|------|--------|
| Pre-flight | Checks: gh CLI, clean git, tag is new, CHANGELOG has entry |
| 1. Version | Updates `Version.swift` + `Info.plist` |
| 2. Build | `swift build -c release`, copies binary to app bundle |
| 3. Sign | Ad-hoc code signing (`codesign --force --deep --sign -`) |
| 4. Package | Creates DMG with `Vowrite.app` + `Applications` symlink |
| 5. Commit | `git commit` + `git tag v{version}` |
| 6. Push | `git push` + `git push --tags` |
| 7. Release | Creates GitHub Release, uploads DMG, extracts notes from CHANGELOG |

## Before Running

1. **Write CHANGELOG entry** — Add a `## [x.y.z.w]` section to `CHANGELOG.md`
2. **Update link refs** — Add version comparison links at the bottom of CHANGELOG
3. **Commit all changes** — Working tree must be clean
4. **Dry run** (optional) — `./scripts/release.sh 0.1.8.0 --dry-run`

## Version Format

`MAJOR.MINOR.PATCH.BUILD` — see [VERSIONING.md](VERSIONING.md)

- `MAJOR` — Breaking changes
- `MINOR` — New features
- `PATCH` — Bug fixes, improvements
- `BUILD` — Hotfixes within a patch

## Code Signing

Currently **ad-hoc signed** (free, no Apple Developer account).

- Users must right-click → Open on first launch
- Future: Developer ID + Notarization ($99/year Apple Developer Program)

## DMG Contents

```
Vowrite.dmg
├── Vowrite.app          (signed app bundle)
└── Applications → /Applications  (symlink for drag-to-install)
```
