# AGENTS.md — Vowrite product repository

Build & run:

    cd VowriteMac && ./build.sh      # build, sign, launch
    cd VowriteMac && swift build     # build only

Test:

    ops/scripts/test.sh              # unit tests + build/quality/security/bundle checks
    cd VowriteKit && swift test      # unit tests only

Layout: `VowriteKit/` (shared macOS+iOS library) · `VowriteMac/` (macOS menu-bar app) · `VowriteIOS/` (iOS app) · `VowriteKeyboard/` (iOS keyboard extension) · `ops/` (test/release automation) · `scripts/` (`check-parity.sh`, `install.sh`) · `docs/` (website).

Conventions:

- Commits: `<type>: <description>` (feat, fix, docs, refactor, chore, security, style, test). No AI authorship trailers.
- Branches: `feature/F-XXX-slug` or `fix/slug`; pull requests target `main`; never push to `main` directly.
- macOS feature changes: run `scripts/check-parity.sh` and evaluate iOS parity before opening a PR.
- AI coding agents follow the same branch + PR rules as everyone else.

## Changelog routing

Vowrite ships macOS today; iOS has no public distribution channel yet, so the two changelogs stay separate. `ops/scripts/release.sh` promotes `[Unreleased]` in `CHANGELOG.md` only.

| Change scope | Goes to |
|---|---|
| `VowriteMac/` only | `CHANGELOG.md` |
| `VowriteIOS/` or `VowriteKeyboard/` only | `CHANGELOG-IOS.md` |
| `VowriteKit/` — macOS users see a behavioral difference | `CHANGELOG.md` |
| `VowriteKit/` — macOS users see no difference | `CHANGELOG-IOS.md` |
| Cross-platform | Both, with per-platform prose |
| `docs/`, `ops/`, `scripts/`, root `*.md` | Neither |

When uncertain whether macOS users perceive a shared-code change, prefer `CHANGELOG.md`. `AppVersion.current` and every `v*` tag track macOS only; iOS-only changes bump no version.

See CONTRIBUTING.md for the contribution workflow, DEV_GUIDE.md for build/deploy and provider implementation details, and docs/PROVIDER_GUIDE.md for the provider registry contract.
