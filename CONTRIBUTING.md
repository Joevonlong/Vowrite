# Contributing to Vowrite

Thank you for your interest in contributing to Vowrite! 🎤✨

## Getting Started

### Prerequisites

- **macOS 14+ (Sonoma)** on Apple Silicon
- **Xcode 16+** with Swift 5.10+
- **Git** with SSH access to GitHub

### Fork and Clone

1. Click **Fork** on [the Vowrite repository](https://github.com/Joevonlong/Vowrite) to create your own copy.
2. Clone your fork locally:

```bash
git clone git@github.com:<your-username>/Vowrite.git
cd Vowrite
```

3. Add the upstream remote so you can keep your fork up to date:

```bash
git remote add upstream git@github.com:Joevonlong/Vowrite.git
git fetch upstream
```

### Build from Source

There are two ways to build the project:

**Option A — SPM build only** (fast compile check, no app bundle):

```bash
cd VowriteMac
swift build
```

This compiles the project via Swift Package Manager. Useful for quickly verifying that your changes compile.

**Option B — Full build, sign, and launch** (recommended for testing):

```bash
cd VowriteMac
./build.sh
```

The build script compiles via SPM, packages into `Vowrite.app`, code-signs with entitlements, and launches the app. Use this when you need to test the running application.

### Submitting a Pull Request

1. **Create a feature branch** from `main`:
   ```bash
   git checkout main
   git pull upstream main
   git checkout -b feature/your-feature
   ```
2. **Make your changes** following the conventions below.
3. **Verify the build:**
   ```bash
   cd VowriteMac && swift build
   ```
4. **Run the test suite** (especially if core modules changed):
   ```bash
   cd Vowrite && ops/scripts/test.sh
   ```
5. **Commit** with a clear message (see [Commit Messages](#commit-messages)):
   ```bash
   git add <files>
   git commit -m "feat: describe your change"
   ```
6. **Push** your branch to your fork:
   ```bash
   git push origin feature/your-feature
   ```
7. **Open a Pull Request** against the `main` branch of the upstream repository. Include a description of what changed and why.

### Project Structure

```
Vowrite/
├── VowriteKit/       # Shared cross-platform code (models, services, utilities)
├── VowriteMac/       # macOS app (menu bar, settings, overlay)
├── VowriteIOS/       # iOS keyboard extension + container app
├── demos/            # Remotion demo videos
├── docs/             # Landing page (GitHub Pages)
└── ops/              # Scripts (release, test, clean)
```

## How to Contribute

### Reporting Bugs

Open an [issue](https://github.com/Joevonlong/Vowrite/issues) with:

- macOS version and chip (Intel/Apple Silicon)
- Steps to reproduce
- Expected vs actual behavior
- Console logs if available (`Console.app` → filter "Vowrite")

### Suggesting Features

Start a [discussion](https://github.com/Joevonlong/Vowrite/discussions) or open an issue tagged `enhancement`. Describe:

- The problem you're solving
- Your proposed solution
- Any alternatives you've considered

### Submitting Code

See [Submitting a Pull Request](#submitting-a-pull-request) above for the full workflow.

## Conventions

### Commit Messages

Format: `<type>: <description>`

| Type | Use for |
|------|---------|
| `feat` | New features |
| `fix` | Bug fixes |
| `docs` | Documentation only |
| `refactor` | Code restructuring (no behavior change) |
| `chore` | Build, tooling, dependencies |
| `security` | Security fixes |
| `style` | Formatting, whitespace |
| `test` | Test additions or fixes |

Examples:
```
feat: add Deepgram STT provider support
fix: resolve Settings window not opening from menu bar
docs: update README with new provider list
```

### Code Style

- **Swift 5.10+** idioms — prefer `async/await`, structured concurrency
- **No external Swift dependencies** — only system frameworks (Carbon, AVFoundation, Security)
- **Cross-platform code** goes in `VowriteKit/`; platform-specific in `VowriteMac/` or `VowriteIOS/`
- Use `VW` design tokens (`VW.Spacing`, `VW.Radius`, `VW.Colors`) for UI constants

### Versioning

4-segment: `MAJOR.MINOR.PATCH.BUILD`

- **BUILD** — bug fixes, infra (no tag/changelog)
- **PATCH** — feature batches (tag + changelog)
- **MINOR** — product milestones
- **MAJOR** — breaking changes

### Branch Model

- `main` — development trunk (all feature PRs target main; NOT auto-deployed to users)
- `feature/F-{ID}-{slug}` — feature work (squash merge back to main)
- `hotfix/vX.Y.Z` — temporary, only for emergency fixes on released versions (created from stable tag)
- No `develop` branch. Releases are tag-based, not branch-based.

## Release Model

Vowrite uses a **beta-first, trunk-based release model** (inspired by [OpenClaw](https://github.com/openclaw/openclaw)):

- **`main`** is the development trunk — merging to main does NOT release to users
- Releases use **tag tracks**, not branches:
  - **Beta:** `vX.Y.Z.W-beta.N` — test builds, delivered via `appcast-beta.xml`
  - **Stable:** `vX.Y.Z.W` — validated releases, delivered via `appcast.xml` (Sparkle auto-update)
- Flow: features merge to main → beta tag → self-test → fix if needed → stable tag → users get update

### Release Commands

```bash
# Beta release (for testing)
cd Vowrite && ops/scripts/release.sh --beta v0.2.1.0-beta.1 "Beta description"
git push origin main --tags

# Stable release (user-facing, after beta validation)
cd Vowrite && ops/scripts/release.sh v0.2.1.0 "Release description"
git push origin main --tags
```

### Hotfix (Emergency)

If a critical bug is found in the stable release but `main` has untested features:

1. Create a hotfix branch from the stable tag: `git checkout -b hotfix/vX.Y.Z <stable-tag>`
2. Fix the bug, tag, and release
3. Cherry-pick the fix back to `main`
4. Delete the hotfix branch

## Architecture Overview

**Data flow:**
```
Hotkey → AudioEngine → STT Provider → AI Polish → TextInjector → Cursor
```

- **STT Providers:** OpenAI Whisper, Groq, Deepgram, Volcengine, Qwen, Ollama, SherpaOnnx (local)
- **Polish Providers:** OpenAI, DeepSeek, Claude, Gemini, Kimi, Zhipu GLM, Volcengine, Qwen, SiliconFlow, MiniMax, MLX (local)
- **Text Injection:** Clipboard + CGEvent `Cmd+V` simulation (works with all apps)

## Permissions

The app requires:

1. **Microphone** — audio recording
2. **Accessibility** — CGEvent keystroke simulation
3. **Network** — API calls to configured providers

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).

---

Questions? Open an issue or reach out. We appreciate every contribution! 🎵
