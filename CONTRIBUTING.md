# Contributing to Vowrite

Thank you for your interest in contributing to Vowrite! 🎤✨

## Getting Started

### Prerequisites

- **macOS 14+ (Sonoma)** on Apple Silicon
- **Xcode 16+** with Swift 5.10+
- **Git** with SSH access to GitHub

### Build from Source

```bash
git clone git@github.com:Joevonlong/Vowrite.git
cd Vowrite/VowriteMac
./build.sh
```

The build script compiles via SPM, packages into `Vowrite.app`, code-signs, and launches.

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

1. **Fork** the repository
2. **Create a feature branch:** `git checkout -b feature/your-feature`
3. **Make your changes** following the conventions below
4. **Test:** `cd Vowrite && ops/scripts/test.sh`
5. **Commit** with a clear message (see conventions)
6. **Push** and open a Pull Request against `main`

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

- `main` — stable, tagged releases only
- `feature/F-{ID}-{slug}` — all feature work (squash merge back)

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
