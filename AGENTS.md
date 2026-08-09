# AGENTS.md — Vowrite product repo

This is the **Vowrite product repo**. If you are working inside the full workspace, the complete rule set lives one level up in `../AGENTS.md` (workspace root) — read that file; it is the single source of truth. This file exists so that agent sessions launched *inside* this repo (or in a standalone clone) still know the iron rules.

## Iron rules (non-negotiable)

1. **Branching:** `main` is the trunk. All feature/fix work happens on branches: `feature/F-{ID}-{slug}` or `fix/{short-description}`, squash-merged back to main. Never commit code work directly to `main` (a git pre-commit hook blocks `.swift` changes on main). Trivial changes only (typos, doc-only, single-line config) may go straight to main.
2. **No AI authorship trailers:** never add `Co-Authored-By: Claude/Codex/...` or similar. The commit author is always the human developer.
3. **Commits:** `<type>: <description>` — types: feat, fix, docs, refactor, chore, security, style, test. Prefer platform scopes: `feat(mac):`, `feat(ios):`, `feat(kit):`, `feat(ops):`. All commits in English.
4. **Headless/orchestrated sessions** (Claude `--print`, `codex exec`) MUST NOT: merge to main, push, switch or delete branches, or update tracking documents. Commit on the given branch and report.
5. **CHANGELOG routing:** `VowriteMac/`-only → `CHANGELOG.md`; `VowriteIOS/`/`VowriteKeyboard/`-only → `CHANGELOG-IOS.md`; shared `VowriteKit/` changes → `CHANGELOG.md` when Mac users perceive a difference (conservative default: `CHANGELOG.md`).
6. **iOS parity:** every VowriteMac feature must be evaluated for iOS parity (`scripts/check-parity.sh`) before being marked done.

## Build & test

```bash
cd VowriteMac && swift build      # build only
cd VowriteMac && ./build.sh       # build + sign + launch
ops/scripts/test.sh               # full test suite (Kit tests + quality/security checks)
```

## Layout (summary)

- `VowriteKit/` — shared cross-platform library (audio, STT, AI polish, config, models; no external deps)
- `VowriteMac/` — macOS menu bar app (SPM; external dep: Sparkle)
- `VowriteIOS/` + `VowriteKeyboard/` — iOS app and keyboard extension (Xcode projects)
- `ops/scripts/` — release.sh, beta-build.sh, test.sh · `scripts/` — check-parity.sh etc.

Full protocols (Task Initiation, Completion, release tracks, provider integration, multi-agent SSOT layout): `../AGENTS.md` at the workspace root.
