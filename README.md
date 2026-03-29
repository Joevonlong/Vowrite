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

Vowrite is a lightweight macOS menu bar app (+ iOS keyboard) that turns your voice into clean, polished text — inserted right where your cursor is. Powered by 15+ AI providers for transcription and text polishing.

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
| 🔌 | **15+ Providers** | OpenAI, Groq, DeepSeek, Deepgram, Gemini, Claude, iFlytek, MLX Server, and more |
| 🔑 | **Key Vault** | API keys stored per-provider in macOS Keychain — enter once, reuse everywhere |
| 📝 | **Text Replacement** | Auto-correct vocabulary with flex pattern matching (post-STT + post-LLM) |
| 🧠 | **Auto Dictionary** | Learns from your corrections — auto-adds words you fix to the dictionary |
| 🎨 | **Recording Indicator** | Orb Pulse breathing light animation during recording |
| 🔊 | **Sound Feedback** | Audio cues for start, success, and error states |
| ⌨️ | **Custom Hotkey** | Default: `⌥ Space` — fully configurable |
| 📊 | **History & Stats** | Browse past dictations, track time saved and words-per-minute |
| 📱 | **iOS Keyboard** | Voice input as a system-wide keyboard extension |

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

This section is for AI/LLM agents (Claude Code, Cursor, Copilot, etc.) working on this codebase.

### Quick Start

```bash
git clone https://github.com/Joevonlong/Vowrite.git
cd Vowrite/VowriteMac
swift build                     # verify build
```

### Read First

- **`CLAUDE.md`** — Project conventions, architecture, build commands, commit format, completion protocol
- **`CONTRIBUTING.md`** — Contribution guidelines (if present)
- **`Vowrite/CHANGELOG.md`** — Release history

### Running Tests

```bash
cd Vowrite && ops/scripts/test.sh
```

No unit test target — testing is script-based (build verification, security scanning, bundle validation).

### Module Guide

| Module | What it does |
|--------|-------------|
| `VowriteKit/Audio/` | Microphone recording via AVAudioEngine → temp .m4a |
| `VowriteKit/Services/` | STT adapters (OpenAI, Deepgram, iFlytek, etc.) + AIPolishService (streaming GPT) |
| `VowriteKit/Config/` | `providers.json` registry, `APIProvider`, `ProviderRegistry`, presets, Key Vault |
| `VowriteKit/Engine/` | `DictationEngine` — platform-agnostic orchestrator (record → transcribe → polish → output) |
| `VowriteKit/Models/` | SwiftData models: `DictationRecord`, `Mode`, `ReplacementRule` |
| `VowriteKit/Replacement/` | `ReplacementManager` — text replacement rules, flex matching, auto-learning |
| `VowriteMac/Platform/` | macOS-only: `HotkeyManager` (Carbon), `TextInjector` (CGEvent), `MacOverlayController`, Sparkle |
| `VowriteIOS/` | iOS app + keyboard extension |

### Adding a New Provider

1. Edit `VowriteKit/Sources/VowriteKit/Config/providers.json` — add a new entry with `id`, `name`, `baseURL`, `capabilities` (stt/polish), and `models`
2. If the provider uses a standard OpenAI-compatible API, that's all — the `ProviderRegistry` handles the rest
3. If the provider uses a non-standard protocol (like Deepgram's binary upload or iFlytek's WebSocket), create a new `STTAdapter` conforming to the `STTAdapter` protocol in `VowriteKit/Services/`

### Adding a New STT Adapter

1. Create a new file in `VowriteKit/Sources/VowriteKit/Services/` (e.g., `MySTTAdapter.swift`)
2. Conform to the `STTAdapter` protocol — implement `transcribe(audioURL:language:)` → `String`
3. Register the adapter in the STT router (`WhisperService`)

### Release Process

```bash
cd Vowrite && ops/scripts/release.sh v0.2.1.0 "Short description"
git push origin main --tags
gh release create v0.2.1.0 releases/Vowrite-v0.2.1.0.dmg --title "Vowrite v0.2.1.0 — Description"
```

The release script handles: changelog update → version bump (Info.plist + SettingsView.swift) → release build → DMG packaging → git commit + annotated tag.

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
