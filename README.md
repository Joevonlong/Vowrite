<p align="center">
  <img src="VowriteApp/Resources/AppIcon-source.png" alt="Vowrite" width="128">
</p>

# Vowrite 🎙️

> **AI Voice Keyboard for macOS** — Speak naturally, get polished text inserted at your cursor.

[🇨🇳 中文文档](README_CN.md)

Vowrite is a lightweight macOS menu bar app that turns your voice into clean, polished text — inserted right where your cursor is. Powered by OpenAI Whisper for transcription and GPT for text polishing.

No more typing. Just speak.

---

## ✨ Features

- 🎤 **Voice-to-Text** — Press a hotkey, speak, get text
- ✨ **AI Polish** — Automatically removes filler words, fixes grammar, adds punctuation
- 🌍 **Multilingual** — Chinese, English, and mixed-language support
- 📋 **Smart Injection** — Text appears directly at your cursor position
- 🎯 **Works Everywhere** — Tested in native apps, browsers, Discord, VS Code, and more
- 🎨 **Floating Overlay** — Compact recording bar with smooth waveform animation
- ⌨️ **Customizable Hotkey** — Default: `⌥ Space` (Option + Space)
- ⎋ **ESC to Cancel** — Press Escape to instantly cancel recording
- 📊 **History** — Browse and search past dictations
- 🔌 **Multi-Provider** — OpenAI, OpenRouter, Groq, Together AI, DeepSeek, or bring your own

## 🚀 Quick Start

### Download

Download the latest release from [GitHub Releases](https://github.com/Joevonlong/Vowrite/releases).

### Build from Source

```bash
cd VowriteApp
./build.sh
```

Or manually:

```bash
cd VowriteApp
swift build -c release
cp .build/arm64-apple-macosx/release/Vowrite Vowrite.app/Contents/MacOS/Vowrite
codesign -fs - --deep --entitlements Resources/Vowrite.entitlements Vowrite.app
open Vowrite.app
```

### Setup

1. Launch Vowrite — it appears in the menu bar as a 🎤 icon
2. Open **Settings** → enter your API key ([Get one from OpenAI](https://platform.openai.com/api-keys))
3. Grant **Microphone** and **Accessibility** permissions when prompted
4. Press `⌥ Space` to start recording, press again to stop
5. Text is automatically inserted at your cursor ✨

## 🔧 How It Works

```
🎤 Record → 📝 Transcribe → ✨ Polish → 📋 Insert
```

1. **Record** — Audio captured as AAC via AVAudioEngine
2. **Transcribe** — Sent to Whisper API for speech-to-text
3. **Polish** — GPT cleans up filler words, grammar, and punctuation
4. **Insert** — Text injected at your cursor via clipboard paste or Unicode typing

### Text Injection Methods

| Method | Speed | Requires |
|--------|-------|----------|
| **Clipboard Paste** (default) | ⚡ Instant | Accessibility permission |
| **Unicode Typing** (fallback) | Fast | Nothing — works everywhere |

Vowrite automatically detects permissions and picks the best method.

## 🔌 Supported Providers

| Provider | STT Model | Polish Model |
|----------|-----------|-------------|
| **OpenAI** | whisper-1 | gpt-4o-mini |
| OpenRouter | whisper-large-v3 | gpt-4o-mini |
| Groq | whisper-large-v3-turbo | llama-3.1-8b-instant |
| Together AI | whisper-large-v3 | Llama-3.1-8B-Instruct-Turbo |
| DeepSeek | whisper-1 | deepseek-chat |
| Custom | configurable | configurable |

## 📁 Project Structure

```
VowriteApp/
├── App/                        # App lifecycle & state
├── Core/
│   ├── Audio/                  # Microphone recording
│   ├── STT/                    # Speech-to-text (Whisper)
│   ├── AI/                     # Text polishing (GPT)
│   ├── TextInjection/          # Cursor text injection
│   ├── Hotkey/                 # Global hotkey management
│   └── Keychain/               # Secure API key storage
├── Views/                      # SwiftUI views
├── Models/                     # SwiftData models
├── Resources/                  # Info.plist, entitlements
└── build.sh                    # Build script
```

## 📋 Requirements

- macOS 14.0 (Sonoma) or later
- API key from a supported provider (OpenAI recommended)
- Microphone permission
- Accessibility permission (recommended, not required)

## 🗺️ Roadmap

- [x] **v0.1** — Core voice dictation
- [x] **v0.2** — Release packaging & error handling
- [x] **v0.3** — App icon & branding
- [ ] **v0.4** — Custom prompts, multiple output modes
- [ ] **v0.4** — Real-time streaming, local Whisper
- [ ] **v1.0** — Code signing, notarization, auto-update

See [full roadmap](ops/ROADMAP.md) for details.

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

## 🤝 Contributing

Contributions welcome! Please open an issue first to discuss what you'd like to change.

## 📝 Changelog

### v0.3 — App Icon
- Official app icon (waveform ring + text cursor design)
- Icon generation automation script
- Build pipeline integration

### v0.2 — Release Ready
- Release build optimization (debug logs disabled in production)
- User-friendly error messages
- Automated DMG packaging

### v0.1 — Initial Release
- Voice dictation with Whisper STT + GPT polish
- Menu bar app with floating recording overlay
- Customizable hotkey (default ⌥Space)
- Multi-provider support
- Dual text injection (clipboard paste + Unicode typing fallback)
- Dictation history with SwiftData
- Microphone selection & launch at login
