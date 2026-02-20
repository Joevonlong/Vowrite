# Voxa 🎙️

**AI Voice Keyboard for macOS** — Speak naturally, get polished text inserted at your cursor.

Voxa is a lightweight menu bar app that records your voice, transcribes it using OpenAI's Whisper API, polishes the text with GPT, and inserts the result directly into whatever app you're typing in.

## Features

- 🎤 **Voice-to-text** — Press a hotkey, speak, get text
- ✨ **AI Polish** — Removes filler words, fixes grammar, adds punctuation
- 🌍 **Multilingual** — Chinese, English, mixed language support
- 📋 **Smart paste** — Text appears at your cursor position automatically
- 🔄 **Graceful fallback** — If AI polish fails, raw transcript is used
- 🎯 **Unicode typing fallback** — Works even without Accessibility permission
- 🎨 **Floating overlay** — Minimal recording bar with waveform visualization
- ⌨️ **Customizable hotkey** — Default: `⌥ Space` (Option + Space)
- 📊 **History** — Browse past dictations with SwiftData persistence
- 🔌 **Multi-provider** — OpenAI, OpenRouter, Groq, Together AI, DeepSeek, or custom

## Requirements

- macOS 14.0 (Sonoma) or later
- An API key from a supported provider (OpenAI recommended)
- Microphone permission
- Accessibility permission (recommended, for clipboard paste)

## Build & Run

```bash
cd VoxaApp
./build.sh
```

Or manually:

```bash
cd VoxaApp
swift build
cp .build/arm64-apple-macosx/debug/Voxa Voxa.app/Contents/MacOS/Voxa
codesign -fs - --deep --entitlements Resources/Voxa.entitlements Voxa.app
open Voxa.app
```

## Setup

1. Launch Voxa — it appears in the menu bar as a 🎤 icon
2. Go to **Settings** → enter your API key
3. Grant **Microphone** and **Accessibility** permissions when prompted
4. Press `⌥ Space` to start recording, press again to stop
5. Text is automatically inserted at your cursor

## How It Works

1. **Record** — Audio captured as AAC (m4a) via AVAudioEngine
2. **Transcribe** — Sent to OpenAI Whisper API (`whisper-1`)
3. **Polish** — Raw transcript cleaned up by GPT (`gpt-4o-mini`)
4. **Inject** — Text pasted into the active app via:
   - Clipboard + Cmd+V (with Accessibility permission)
   - Unicode character typing (fallback, no permissions needed)

## Text Injection

Voxa uses two methods to insert text:

- **Clipboard paste** (preferred): Copies text to clipboard, simulates Cmd+V via CGEvent. Requires Accessibility permission.
- **Unicode typing** (fallback): Types each character individually via CGEvent Unicode input. No special permissions needed, slightly slower.

If Accessibility permission isn't granted, Voxa automatically falls back to Unicode typing.

## Supported Providers

| Provider | STT Model | Polish Model |
|----------|-----------|-------------|
| OpenAI | whisper-1 | gpt-4o-mini |
| OpenRouter | openai/whisper-large-v3 | openai/gpt-4o-mini |
| Groq | whisper-large-v3-turbo | llama-3.1-8b-instant |
| Together AI | whisper-large-v3 | Llama-3.1-8B-Instruct-Turbo |
| DeepSeek | whisper-1 | deepseek-chat |
| Custom | configurable | configurable |

## Project Structure

```
VoxaApp/
├── App/
│   ├── VoxaApp.swift          # App entry point
│   ├── AppState.swift         # Main state machine
│   ├── WindowHelper.swift     # Window management
│   └── PermissionManager.swift # Permission checks
├── Core/
│   ├── Audio/AudioEngine.swift        # Mic recording
│   ├── STT/WhisperService.swift       # Speech-to-text API
│   ├── AI/AIPolishService.swift       # Text polish API
│   ├── TextInjection/TextInjector.swift # Cursor injection
│   ├── Hotkey/HotkeyManager.swift     # Global hotkey
│   └── Keychain/KeychainHelper.swift  # API key storage
├── Views/
│   ├── VoxaMenuView.swift     # Menu bar dropdown
│   ├── MenuBarView.swift      # Menu bar icon
│   ├── SettingsView.swift     # Settings + API config
│   ├── MainWindowView.swift   # Main window
│   ├── HistoryView.swift      # Dictation history
│   ├── RecordingOverlay.swift # Floating recording bar
│   └── HotkeyRecorderView.swift # Hotkey capture
├── Models/
│   └── DictationRecord.swift  # SwiftData model
├── Resources/
│   ├── Info.plist
│   └── Voxa.entitlements
├── Package.swift
└── build.sh
```

## License

Private project.

## Version History

### v0.1 — Initial Release
- Core voice dictation with Whisper STT
- AI text polishing with GPT
- Menu bar app with floating recording overlay
- Customizable hotkey (default ⌥Space)
- Multi-provider support (OpenAI, OpenRouter, Groq, etc.)
- Dual text injection (clipboard paste + Unicode typing fallback)
- Dictation history with SwiftData
- Microphone selection
- Launch at login option
