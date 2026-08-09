---
name: vowrite-release
description: "Prepare and execute a Vowrite macOS beta or stable release with explicit mutation, publication, and tracking gates. Use when the user asks to release or cut a version."
---

# Vowrite release

A release mutates version files, commits, tags, appcasts, artifacts, and—only through the authorized publication wrapper—GitHub. Run every command below from the clean product repository main integration checkout, never from the surrounding workspace root or a feature worktree. Do not infer release authorization from ordinary feature completion.

## 1. Freeze the release candidate

Work from a clean product `main` with no active unintegrated release write-set. Record the full local and remote SHAs, last tag, requested version, release track, included commits, and integration owner. Fetch before comparing; do not substitute a dynamic `HEAD` in the report.

Vowrite uses `MAJOR.MINOR.PATCH.BUILD`; beta tags append `-beta.N`. The current release script is macOS-only. It updates:

- `VowriteMac/Resources/Info.plist`;
- `VowriteKit/Sources/VowriteKit/Version.swift` as the macOS app version;
- `CHANGELOG.md` for stable releases;
- `docs/appcast.xml` or `docs/appcast-beta.xml`;
- the release commit, annotated tag, DMG, and pinned publication intent.

It does not create an iOS version or iOS tag. `CHANGELOG-IOS.md` remains an accumulating iOS backlog and is never promoted by the macOS release.

## 2. Preflight

Verify the requested version is new and consistent with the changelog plan. Classify every commit since the last tag by Mac/iOS/shared/meta path and confirm iOS-only work is recorded in `CHANGELOG-IOS.md` while Mac-visible work is in `CHANGELOG.md`.

Run `ops/scripts/test-agent-platform.sh`, `ops/scripts/test.sh`, and `scripts/check-parity.sh`. Verify signing identity, Sparkle key/tooling, `gh` authentication if GitHub publication is requested, and repository cleanliness. Stop on any hard failure.

## 3. Execute the local release transaction

The integration owner runs:

```bash
ops/scripts/release.sh [--beta] vX.Y.Z.W[-beta.N] "description"
```

Answer its changelog and release gates according to the user's explicit authorization. The script performs no network mutation: it prepares a pinned release intent after the local commit, tag, artifact, and appcast exist. Capture the release commit, tag target, artifact path/hash, appcast entry, and signing result.

If it fails after mutation, follow the script's rollback output and re-check status before retrying. Never overwrite an existing tag silently.

## 4. Verify and publish

Re-run the relevant smoke checks against the built artifact. Confirm the tag points to the release commit and the DMG/appcast signature agrees. Publish only when the user explicitly authorized remote publication; the wrapper and repository pre-push gate require the exact prepared intent:

```bash
scripts/publish-release.sh --tag vX.Y.Z.W[-beta.N]
```

The wrapper atomically pushes only the pinned `main` commit and annotated tag, then creates or resumes the pinned GitHub Release asset. Verify remote ancestry, tag resolution, and the GitHub asset afterward. Never invoke a direct release `git push`, publish feature branches, delete refs, or widen the prepared intent.

## 5. Synchronize workspace tracking

In the separate workspace repository, update `development.md`, `FEATURES.md`, `DASHBOARD.md`, `TODO.md`, feature specs, and website version references that actually changed. Use a workspace task/integration owner rather than editing tracking from a product worker.

Completion means local artifacts, Git state, remote state, GitHub Release state, and tracking all match. Report any deliberately deferred publication or manual installation/smoke gate as remaining, not done.
