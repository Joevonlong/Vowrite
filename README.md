<p align="center">
  <img src="VowriteMac/Resources/AppIcon-source.png" alt="Vowrite" width="128">
</p>

<h1 align="center">Vowrite</h1>

<p align="center">
  <strong>AI Voice Keyboard for macOS & iOS</strong><br>
  Speak naturally. Get polished text at your cursor.
</p>

<p align="center">
  <a href="https://github.com/Joevonlong/Vowrite/releases"><img src="https://img.shields.io/badge/release-v0.2.0.0-blue?style=flat-square" alt="Release"></a>
  <a href="https://github.com/Joevonlong/Vowrite/releases"><img src="https://img.shields.io/github/downloads/Joevonlong/Vowrite/total?style=flat-square" alt="Downloads"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/Joevonlong/Vowrite?style=flat-square" alt="License"></a>
  <a href="https://github.com/Joevonlong/Vowrite/stargazers"><img src="https://img.shields.io/github/stars/Joevonlong/Vowrite?style=flat-square" alt="Stars"></a>
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B%20%7C%20iOS%2017%2B-blue?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/swift-5.10%2B-orange?style=flat-square&logo=swift&logoColor=white" alt="Swift">
</p>

<p align="center">
  <a href="README.md">English</a> · <a href="README_CN.md">中文</a> · <a href="README_DE.md">Deutsch</a>
</p>

---

<p align="center">
  <code>🎤 Record</code> → <code>📝 Transcribe</code> → <code>✨ Polish</code> → <code>📋 Insert</code>
</p>

Vowrite is a lightweight macOS menu bar app (+ iOS keyboard) that turns your voice into clean, polished text — inserted right where your cursor is. Powered by 20+ AI providers for transcription and text polishing.

No more typing. Just speak.

## ✨ Features

| | Feature | Description |
|---|---------|-------------|
| 🎤 | **Voice-to-Text** | Press a hotkey, speak, get text |
| ✨ | **AI Polish** | Removes filler words, fixes grammar, adds punctuation |
| 🌍 | **Multilingual** | Chinese, English, mixed-language, and 36+ languages via Deepgram |
| 📋 | **Smart Injection** | Text appears directly at your cursor position |
| 🎯 | **Works Everywhere** | Native apps, browsers, Discord, VS Code, and more |
| ⚡ | **Speculative LLM** | Pre-warms connections during recording — saves ~200–500ms per dictation |
| 🔌 | **20+ Providers** | OpenAI, Groq, DeepSeek, Deepgram, Gemini, Claude, iFlytek, MLX Server, and more |
| 🔑 | **Key Vault** | API keys stored per-provider in macOS Keychain — enter once, reuse everywhere |
| 📝 | **Text Replacement** | Auto-correct vocabulary with flex pattern matching (post-STT + post-LLM) |
| 🧠 | **Auto Dictionary** | Learns from your corrections — auto-adds words you fix to the dictionary |
| 🎨 | **Recording Indicator** | 5 built-in presets: Classic Bar, Orb Pulse, Ripple Ring, Spectrum Arc, Minimal Dot |
| 🔊 | **Sound Feedback** | Audio cues for start, success, and error states |
| ⌨️ | **Custom Hotkey** | Default: `⌥ Space` — fully configurable |
| 📊 | **History & Stats** | Browse past dictations, track time saved and words-per-minute |
| 📱 | **iOS Keyboard** | Voice input as a system-wide keyboard extension |

## 🎨 Customization

Vowrite is designed to be customizable:

- **[App Icon](docs/APP_ICON_GUIDE.md)** — Replace with your own icon
- **[Recording Indicator](docs/THEME_GUIDE.md)** — 5 built-in presets, more coming
- **[AI Providers](docs/PROVIDER_GUIDE.md)** — Add your own providers via `providers.json`

See the full [Customization Guide](docs/CUSTOMIZATION.md) for details.

## 🚀 Quick Start

### Download

Grab the latest `.dmg` from [**Releases**](https://github.com/Joevonlong/Vowrite/releases).

### Build from Source

```bash
git clone https://github.com/Joevonlong/Vowrite.git
cd Vowrite/VowriteMac
swift build        # build only
./build.sh         # build, sign, and launch
```

### Setup

1. Launch Vowrite — it appears in the menu bar as 🎤
2. Open **Settings** → pick a preset or enter your API keys (⭐ recommended: [Groq](https://console.groq.com/keys) STT + [DeepSeek](https://platform.deepseek.com/api_keys) Polish)
3. Grant **Microphone** and **Accessibility** permissions when prompted
4. Press `⌥ Space` to start recording, press again to stop
5. Text is automatically inserted at your cursor ✨

## 🔌 Supported Providers

### STT (Speech-to-Text)

| Provider | Model | Protocol | Notes |
|----------|-------|----------|-------|
| **⭐ Groq** | whisper-large-v3-turbo | OpenAI-compatible | Fast, free tier |
| **OpenAI** | whisper-1, gpt-4o-transcribe | OpenAI | Official |
| **Deepgram** | Nova-3, Nova-2 | Native (Token auth + binary) | 36+ languages |
| **Volcengine** | — | OpenAI-compatible | ByteDance |
| **Qwen** | — | OpenAI-compatible | Alibaba Cloud |
| **SiliconFlow** | SenseVoice | OpenAI-compatible | Chinese-optimized |
| **iFlytek** | — | WebSocket (HMAC-SHA256) | 23 Chinese dialects |
| **Sherpa** | — | Offline (sherpa-onnx) | Fully on-device (scaffold) |
| **Custom** | configurable | OpenAI-compatible | Any endpoint |

### Polish (Text Polishing)

| Provider | Default Model | Notes |
|----------|---------------|-------|
| **⭐ DeepSeek** | deepseek-chat | Cost-effective |
| **OpenAI** | gpt-4o-mini | All-in-one |
| **Gemini** | gemini-2.0-flash | Google |
| **Claude** | claude-sonnet | Anthropic native API |
| **Zhipu GLM** | glm-4-flash | OpenAI-compatible |
| **Groq** | llama-3.1-8b | Fast inference |
| **Kimi** | kimi-k2.5 | Moonshot |
| **MiniMax** | MiniMax-Text-02 | — |
| **Volcengine** | — | ByteDance |
| **Qwen** | — | Alibaba Cloud |
| **SiliconFlow** | Qwen/DeepSeek/GLM | Multi-model |
| **Ollama** | local models | 100% offline |
| **MLX Server** | local models | Apple Silicon native, no API key |
| **OpenRouter** | gpt-4o-mini | Multi-model gateway |
| **Together AI** | Llama-3.1-8B | Open source models |
| **Custom** | configurable | Any OpenAI-compatible endpoint |

## 🔧 How It Works

```
Voice → STT Provider → AI Polish → Cursor Injection
```

**Speculative pipeline:** Connections are pre-warmed during recording, and STT requests are pre-built — so polished text appears ~200–500ms faster than sequential processing.

**Text injection** uses clipboard + simulated Cmd+V via CGEvent, working reliably across all apps including Electron (Discord, VS Code, Slack).

## 📁 Project Structure

```
Vowrite/
├── VowriteKit/                 # Shared core library (macOS + iOS)
│   └── Sources/VowriteKit/
│       ├── Audio/              # Microphone recording (AVAudioEngine)
│       ├── Services/           # STT adapters, AI Polish, Connection Tester
│       ├── Config/             # providers.json registry, API config, presets, Key Vault
│       ├── Engine/             # DictationEngine — platform-agnostic orchestrator
│       ├── Models/             # SwiftData models (DictationRecord, Mode, Replacement, etc.)
│       ├── Protocols/          # Platform abstractions (TextOutput, Permissions, etc.)
│       └── Replacement/        # ReplacementManager, flex pattern matching, auto-learning
├── VowriteMac/                 # macOS app (menu bar + settings window)
│   └── Sources/
│       ├── App/                # App lifecycle, state, window management
│       ├── Platform/           # macOS-specific: hotkeys, text injection, overlay, Sparkle
│       └── Views/              # SwiftUI views (settings, history, onboarding, etc.)
├── VowriteIOS/                 # iOS app (tab-based UI)
│   └── Sources/
│       ├── App/                # App lifecycle, state
│       ├── Platform/           # iOS-specific: clipboard output, haptics, permissions
│       └── Views/              # SwiftUI views (home, recording, settings, etc.)
└── docs/                       # Website (GitHub Pages → vowrite.com)
```

## 📋 Requirements

### macOS
- macOS 14.0 (Sonoma) or later
- API key from a supported provider
- Microphone permission
- Accessibility permission *(recommended, for cursor injection)*

### iOS
- iOS 17.0 or later
- API key from a supported provider
- Microphone permission

## 🤖 For AI Agents

This section is for coding agents, including Claude Code and Codex, working on this codebase.

### Quick Start

```bash
git clone https://github.com/Joevonlong/Vowrite.git
cd Vowrite
scripts/bootstrap-agent-platform.sh
cd VowriteMac && swift build
```

### Read First

- **`AGENTS.md`** — Authoritative product rules, worktree protocol, build commands, and handoff contract
- **`CLAUDE.md`** — Thin Claude Code import of `AGENTS.md`
- **`CONTRIBUTING.md`** — Contribution guidelines (if present)
- **`CHANGELOG.md`** — Release history

### Running Tests

```bash
ops/scripts/test.sh
```

`ops/scripts/test.sh` runs VowriteKit unit tests plus build, quality, security, bundle, parity, and agent-platform checks.

### Module Guide

| Module | What it does |
|--------|-------------|
| `VowriteKit/Audio/` | Microphone recording via AVAudioEngine → temp .m4a |
| `VowriteKit/Services/` | STT adapters (OpenAI, Deepgram, iFlytek, etc.) + AIPolishService (streaming GPT) |
| `VowriteKit/Config/` | `providers.json` registry, `APIProvider`, `ProviderRegistry`, presets, Key Vault |
| `VowriteKit/Engine/` | `DictationEngine` — platform-agnostic orchestrator (record → transcribe → polish → output) |
| `VowriteKit/Models/` | SwiftData and domain models such as `DictationRecord`, `Mode`, and `OutputStyle` |
| `VowriteKit/Config/ReplacementManager.swift` | Text replacement rules, flex matching, and auto-learning |
| `VowriteMac/Platform/` | macOS-only: `HotkeyManager` (Carbon), `TextInjector` (CGEvent), `MacOverlayController`, Sparkle |
| `VowriteIOS/` | iOS container app |
| `VowriteKeyboard/` | iOS keyboard extension |

### Adding a New Provider

1. Add the `providers.json` entry and an `APIProvider` case plus `providerID` mapping
2. For OpenAI-compatible STT, verify the provider supports Vowrite's multipart `/audio/transcriptions` contract before selecting the shared adapter
3. For a non-standard protocol, add an `STTAdapter` under `VowriteKit/Sources/VowriteKit/Services/Adapters/` and register its ID in `WhisperService`

**See [`docs/PROVIDER_GUIDE.md`](docs/PROVIDER_GUIDE.md) for the full reference** — field schema, auth styles, complete examples, and reference adapter implementations.

### Adding a New STT Adapter

1. Create a new file in `VowriteKit/Sources/VowriteKit/Services/Adapters/` (for example, `MySTTAdapter.swift`)
2. Conform to the current `STTAdapter` protocol, including model, language, prompt, key, base URL, and provider inputs
3. Register the adapter in the STT router (`WhisperService`)

### Release Process

```bash
ops/scripts/release.sh v0.2.1.0 "Short description"
scripts/publish-release.sh --tag v0.2.1.0
```

The release script performs local preparation only: macOS changelog promotion → version bump (`Info.plist` + `Version.swift`) → release build → DMG packaging/signing → appcast → git commit/tag → pinned publication intent. After explicit authorization, `publish-release.sh` atomically publishes the pinned `main` and tag and creates or resumes the matching GitHub Release. The pipeline does not create an iOS version.

### Conventions

- **Commits:** `<type>: <description>` — types: feat, fix, docs, refactor, chore, security, style, test
- **Branches:** `main` for releases; `feature/F-{ID}-{slug}` for feature work
- **Versioning:** 4-segment `MAJOR.MINOR.PATCH.BUILD`
- **No external Swift dependencies** — only system frameworks

## 🗺️ Roadmap

See the [full roadmap](ops/ROADMAP.md) for upcoming features.

## 📝 Changelog

See [CHANGELOG.md](CHANGELOG.md) or [GitHub Releases](https://github.com/Joevonlong/Vowrite/releases).

## 🤝 Contributing

Contributions welcome! Please [open an issue](https://github.com/Joevonlong/Vowrite/issues) first to discuss what you'd like to change.

## 📄 License

[MIT](LICENSE)

---

<p align="center">
  Made with 🎤 by <a href="https://github.com/Joevonlong">Joe Long</a>
</p>
