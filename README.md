<p align="center">
  <img src="VowriteApp/Resources/AppIcon-source.png" alt="Vowrite" width="128">
</p>

<h1 align="center">Vowrite</h1>

<p align="center">
  <strong>AI Voice Keyboard for macOS</strong><br>
  Speak naturally. Get polished text at your cursor.
</p>

<p align="center">
  <a href="https://github.com/Joevonlong/Vowrite/releases"><img src="https://img.shields.io/github/v/release/Joevonlong/Vowrite?style=flat-square&label=release" alt="Release"></a>
  <a href="https://github.com/Joevonlong/Vowrite/releases"><img src="https://img.shields.io/github/downloads/Joevonlong/Vowrite/total?style=flat-square" alt="Downloads"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/Joevonlong/Vowrite?style=flat-square" alt="License"></a>
  <a href="https://github.com/Joevonlong/Vowrite/stargazers"><img src="https://img.shields.io/github/stars/Joevonlong/Vowrite?style=flat-square" alt="Stars"></a>
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/swift-5.9%2B-orange?style=flat-square&logo=swift&logoColor=white" alt="Swift">
</p>

<p align="center">
  <a href="README.md">English</a> · <a href="README_CN.md">中文</a> · <a href="README_DE.md">Deutsch</a>
</p>

---

<p align="center">
  <code>🎤 Record</code> → <code>📝 Transcribe</code> → <code>✨ Polish</code> → <code>📋 Insert</code>
</p>

Vowrite is a lightweight macOS menu bar app that turns your voice into clean, polished text — inserted right where your cursor is. Powered by Whisper for transcription and GPT for text polishing.

No more typing. Just speak.

## ✨ Features

| | Feature | Description |
|---|---------|-------------|
| 🎤 | **Voice-to-Text** | Press a hotkey, speak, get text |
| ✨ | **AI Polish** | Removes filler words, fixes grammar, adds punctuation |
| 🌍 | **Multilingual** | Chinese, English, and mixed-language support |
| 📋 | **Smart Injection** | Text appears directly at your cursor position |
| 🎯 | **Works Everywhere** | Native apps, browsers, Discord, VS Code, and more |
| 🎨 | **Floating Overlay** | Compact recording bar with smooth waveform animation |
| ⌨️ | **Custom Hotkey** | Default: `⌥ Space` — fully configurable |
| ⎋ | **ESC to Cancel** | Instantly cancel any recording |
| 📊 | **History** | Browse and search past dictations |
| 🔌 | **Multi-Provider** | OpenAI, Groq, DeepSeek, and more |

## 🚀 Quick Start

### Download

Grab the latest `.dmg` from [**Releases**](https://github.com/Joevonlong/Vowrite/releases).

### Build from Source

```bash
git clone https://github.com/Joevonlong/Vowrite.git
cd Vowrite/VowriteApp
./build.sh
```

### Setup

1. Launch Vowrite — it appears in the menu bar as 🎤
2. Open **Settings** → enter your API key ([get one from OpenAI](https://platform.openai.com/api-keys))
3. Grant **Microphone** and **Accessibility** permissions when prompted
4. Press `⌥ Space` to start recording, press again to stop
5. Text is automatically inserted at your cursor ✨

## 🔌 Supported Providers

| Provider | STT Model | Polish Model |
|----------|-----------|-------------|
| **OpenAI** | whisper-1 | gpt-4o-mini |
| OpenRouter | whisper-large-v3 | gpt-4o-mini |
| Groq | whisper-large-v3-turbo | llama-3.1-8b-instant |
| Together AI | whisper-large-v3 | Llama-3.1-8B-Instruct-Turbo |
| DeepSeek | whisper-1 | deepseek-chat |
| Custom | configurable | configurable |

## 🔧 How It Works

```
Voice → Whisper STT → GPT Polish → Cursor Injection
```

**Text injection** automatically selects the best method:

| Method | Speed | Requires |
|--------|-------|----------|
| Clipboard Paste *(default)* | ⚡ Instant | Accessibility permission |
| Unicode Typing *(fallback)* | Fast | No permissions needed |

## 📁 Project Structure

```
VowriteApp/
├── App/                    # App lifecycle & state
├── Core/
│   ├── Audio/              # Microphone recording (AVAudioEngine)
│   ├── STT/                # Speech-to-text (Whisper API)
│   ├── AI/                 # Text polishing (GPT)
│   ├── TextInjection/      # Cursor text injection
│   ├── Hotkey/             # Global hotkey management
│   └── Keychain/           # Secure API key storage
├── Views/                  # SwiftUI views
├── Models/                 # SwiftData models
└── Resources/              # Info.plist, entitlements, icons
```

## 📋 Requirements

- macOS 14.0 (Sonoma) or later
- API key from a supported provider
- Microphone permission
- Accessibility permission *(recommended, not required)*

## 🗺️ Roadmap

See the [full roadmap](ops/ROADMAP.md) for upcoming features.

## 📝 Changelog

See [RELEASE_NOTES.md](RELEASE_NOTES.md) or [GitHub Releases](https://github.com/Joevonlong/Vowrite/releases).

## 🤝 Contributing

Contributions welcome! Please [open an issue](https://github.com/Joevonlong/Vowrite/issues) first to discuss what you'd like to change.

## 📄 License

[AGPL-3.0](LICENSE)

---

<p align="center">
  Made with 🎤 by <a href="https://github.com/Joevonlong">Joe Long</a>
</p>
