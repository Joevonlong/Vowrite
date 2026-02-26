# Pre-Release Checklist

**Every item must be confirmed before each release.** Do not release until all items pass.

Version: __________ Date: __________

---

## Code Quality

- [ ] All functional tests pass (see test matrix in PROCESS.md)
- [ ] `swift build -c release` compiles with no warnings (or warnings have been assessed)
- [ ] No TODO/FIXME remaining on critical paths
- [ ] New code has necessary comments

## Security

- [ ] Review `CHECKLIST_SECURITY.md`
- [ ] No sensitive information leaked in Git history
- [ ] Debug logs are downgraded in release builds

## Version Information

- [ ] `CFBundleShortVersionString` updated in `Info.plist`
- [ ] Version number updated in `AboutTab`
- [ ] `RELEASE_NOTES.md` updated
- [ ] `README.md` version history updated
- [ ] Git tag created and matches version number

## Build & Packaging

- [ ] `ops/scripts/release.sh` executed successfully
- [ ] DMG file mounts and drag-to-install works correctly
- [ ] First launch after installation works properly
- [ ] Permission request flow works correctly after installation

## Signing & Notarization (When Developer ID Is Available)

- [ ] Code signature is valid (`codesign --verify`)
- [ ] Notarization passed (`xcrun notarytool`)
- [ ] Stapling complete (`xcrun stapler staple`)
- [ ] Users can double-click to open after download (no "unidentified developer" warning)

## Language Check

- [ ] Commit messages are in English
- [ ] Release notes / description are in English
- [ ] README updates are in English
- [ ] New code comments are in English
- [ ] GitHub Issue descriptions are in English

## Release

- [ ] GitHub Release created with DMG attached
- [ ] Release Notes content is accurate
- [ ] Website download link updated (if applicable)
- [ ] Previous version downloads remain accessible

---

**Sign-off:** __________ **Date:** __________
