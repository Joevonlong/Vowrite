<p align="center">
  <img src="VowriteMac/Resources/AppIcon-source.png" alt="Vowrite" width="128">
</p>

<h1 align="center">Vowrite</h1>

<p align="center">
  <strong>KI-Sprachtastatur für macOS & iOS</strong><br>
  Natürlich sprechen. Polierter Text an deinem Cursor.
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
  <code>🎤 Aufnahme</code> → <code>📝 Transkription</code> → <code>✨ Polieren</code> → <code>📋 Einfügen</code>
</p>

Vowrite ist eine schlanke macOS-Menüleisten-App (+ iOS-Tastatur), die deine Sprache in sauberen, polierten Text verwandelt — direkt an deiner Cursor-Position eingefügt. Unterstützt 15+ KI-Anbieter für Transkription und Textoptimierung.

Nicht mehr tippen. Einfach sprechen.

## ✨ Funktionen

| | Funktion | Beschreibung |
|---|----------|-------------|
| 🎤 | **Sprache-zu-Text** | Tastenkürzel drücken, sprechen, Text erscheint |
| ✨ | **KI-Polierung** | Entfernt Füllwörter, korrigiert Grammatik, setzt Satzzeichen |
| 🌍 | **Mehrsprachig** | Chinesisch, Englisch, gemischt und 36+ Sprachen via Deepgram |
| 📋 | **Intelligente Eingabe** | Text erscheint direkt an der Cursor-Position |
| 🎯 | **Überall einsetzbar** | Native Apps, Browser, Discord, VS Code und mehr |
| ⚡ | **Spekulatives LLM** | Vorwärmen der Verbindungen während der Aufnahme — spart ~200–500ms pro Diktat |
| 🔌 | **15+ Anbieter** | OpenAI, Groq, DeepSeek, Deepgram, Gemini, Claude, iFlytek, MLX Server und mehr |
| 🔑 | **Schlüsseltresor** | API-Keys pro Anbieter im macOS-Schlüsselbund — einmal eingeben, überall nutzen |
| 📝 | **Textersetzung** | Auto-Korrektur mit flexiblem Musterabgleich (nach STT + nach LLM) |
| 🧠 | **Auto-Wörterbuch** | Lernt aus deinen Korrekturen — fügt korrigierte Wörter automatisch hinzu |
| 🎨 | **Aufnahme-Indikator** | Orb-Pulse atmende Lichtkugel-Animation |
| 🔊 | **Klang-Feedback** | Akustische Signale für Start, Erfolg und Fehler |
| ⌨️ | **Eigenes Tastenkürzel** | Standard: `⌥ Leertaste` — frei konfigurierbar |
| 📊 | **Verlauf & Statistik** | Vergangene Diktate durchsuchen, gesparte Zeit und Wörter-pro-Minute verfolgen |
| 📱 | **iOS-Tastatur** | Spracheingabe als systemweite Tastaturerweiterung |

## 🚀 Schnellstart

### Download

Lade die neueste `.dmg` von [**Releases**](https://github.com/Joevonlong/Vowrite/releases) herunter.

### Aus dem Quellcode bauen

```bash
git clone https://github.com/Joevonlong/Vowrite.git
cd Vowrite/VowriteMac
swift build        # nur kompilieren
./build.sh         # kompilieren, signieren und starten
```

### Einrichtung

1. Starte Vowrite — es erscheint als 🎤 in der Menüleiste
2. Öffne **Einstellungen** → wähle eine Voreinstellung oder gib deine API-Keys ein (⭐ empfohlen: [Groq](https://console.groq.com/keys) STT + [DeepSeek](https://platform.deepseek.com/api_keys) Polish)
3. Erteile **Mikrofon**- und **Bedienungshilfen**-Berechtigungen
4. Drücke `⌥ Leertaste` zum Starten der Aufnahme, erneut zum Stoppen
5. Text wird automatisch an der Cursor-Position eingefügt ✨

## 🔌 Unterstützte Anbieter

### STT (Sprache-zu-Text)

| Anbieter | Modell | Protokoll | Hinweis |
|----------|--------|-----------|---------|
| **⭐ Groq** | whisper-large-v3-turbo | OpenAI-kompatibel | Schnell, kostenloser Tarif |
| **OpenAI** | whisper-1, gpt-4o-transcribe | OpenAI | Offiziell |
| **Deepgram** | Nova-3, Nova-2 | Nativ (Token-Auth + Binär) | 36+ Sprachen |
| **Volcengine** | — | OpenAI-kompatibel | ByteDance |
| **Qwen** | — | OpenAI-kompatibel | Alibaba Cloud |
| **SiliconFlow** | SenseVoice | OpenAI-kompatibel | Chinesisch-optimiert |
| **iFlytek** | — | WebSocket (HMAC-SHA256) | 23 chinesische Dialekte |
| **Sherpa** | — | Offline (sherpa-onnx) | Vollständig auf dem Gerät (Gerüst) |
| **Benutzerdefiniert** | konfigurierbar | OpenAI-kompatibel | Jeder Endpunkt |

### Polish (Textoptimierung)

| Anbieter | Standard-Modell | Hinweis |
|----------|----------------|---------|
| **⭐ DeepSeek** | deepseek-chat | Kosteneffizient |
| **OpenAI** | gpt-4o-mini | All-in-One |
| **Gemini** | gemini-2.0-flash | Google |
| **Claude** | claude-sonnet | Anthropic-native API |
| **Zhipu GLM** | glm-4-flash | OpenAI-kompatibel |
| **Groq** | llama-3.1-8b | Schnelle Inferenz |
| **Kimi** | kimi-k2.5 | Moonshot |
| **MiniMax** | MiniMax-Text-02 | — |
| **Volcengine** | — | ByteDance |
| **Qwen** | — | Alibaba Cloud |
| **SiliconFlow** | Qwen/DeepSeek/GLM | Multi-Modell |
| **Ollama** | Lokale Modelle | 100% offline |
| **MLX Server** | Lokale Modelle | Apple Silicon nativ, kein API-Key |
| **OpenRouter** | gpt-4o-mini | Multi-Modell-Gateway |
| **Together AI** | Llama-3.1-8B | Open-Source-Modelle |
| **Benutzerdefiniert** | konfigurierbar | Jeder OpenAI-kompatible Endpunkt |

## 🔧 Funktionsweise

```
Sprache → STT-Anbieter → KI-Polierung → Cursor-Einfügung
```

**Spekulative Pipeline:** Verbindungen werden während der Aufnahme vorgewärmt und STT-Anfragen vorgebaut — polierter Text erscheint ~200–500ms schneller als bei sequentieller Verarbeitung.

**Texteinfügung** nutzt Zwischenablage + simuliertes Cmd+V via CGEvent und funktioniert zuverlässig in allen Apps, einschließlich Electron (Discord, VS Code, Slack).

## 📁 Projektstruktur

```
Vowrite/
├── VowriteKit/                 # Gemeinsame Kernbibliothek (macOS + iOS)
│   └── Sources/VowriteKit/
│       ├── Audio/              # Mikrofonaufnahme (AVAudioEngine)
│       ├── Services/           # STT-Adapter, KI-Polish, Verbindungstest
│       ├── Config/             # providers.json-Registry, API-Konfiguration, Voreinstellungen, Schlüsseltresor
│       ├── Engine/             # DictationEngine — plattformübergreifender Orchestrator
│       ├── Models/             # SwiftData-Modelle (DictationRecord, Mode, Replacement, etc.)
│       ├── Protocols/          # Plattformabstraktionen (TextOutput, Permissions, etc.)
│       └── Replacement/        # ReplacementManager, flexibler Musterabgleich, Auto-Lernen
├── VowriteMac/                 # macOS-App (Menüleiste + Einstellungsfenster)
│   └── Sources/
│       ├── App/                # App-Lebenszyklus, Zustand, Fensterverwaltung
│       ├── Platform/           # macOS-spezifisch: Hotkeys, Texteinfügung, Overlay, Sparkle
│       └── Views/              # SwiftUI-Views (Einstellungen, Verlauf, Onboarding, etc.)
├── VowriteIOS/                 # iOS-App (Tab-basierte UI)
│   └── Sources/
│       ├── App/                # App-Lebenszyklus, Zustand
│       ├── Platform/           # iOS-spezifisch: Zwischenablage-Ausgabe, Haptik, Berechtigungen
│       └── Views/              # SwiftUI-Views (Home, Aufnahme, Einstellungen, etc.)
└── docs/                       # Website (GitHub Pages → vowrite.com)
```

## 📋 Voraussetzungen

### macOS
- macOS 14.0 (Sonoma) oder neuer
- API-Schlüssel eines unterstützten Anbieters
- Mikrofon-Berechtigung
- Bedienungshilfen-Berechtigung *(empfohlen, für Cursor-Einfügung)*

### iOS
- iOS 17.0 oder neuer
- API-Schlüssel eines unterstützten Anbieters
- Mikrofon-Berechtigung

## 🤖 Für KI-Agenten

Dieser Abschnitt richtet sich an KI/LLM-Agenten (Claude Code, Cursor, Copilot, etc.), die an dieser Codebasis arbeiten.

### Schnellstart

```bash
git clone https://github.com/Joevonlong/Vowrite.git
cd Vowrite/VowriteMac
swift build                     # Build verifizieren
```

### Zuerst lesen

- **`CLAUDE.md`** — Projektkonventionen, Architektur, Build-Befehle, Commit-Format, Abschlussprotokoll
- **`CONTRIBUTING.md`** — Beitragsrichtlinien (falls vorhanden)
- **`Vowrite/CHANGELOG.md`** — Release-Historie

### Tests ausführen

```bash
cd Vowrite && ops/scripts/test.sh
```

Kein Unit-Test-Target — Tests sind skriptbasiert (Build-Verifizierung, Sicherheitsscan, Bundle-Validierung).

### Modul-Übersicht

| Modul | Funktion |
|-------|----------|
| `VowriteKit/Audio/` | Mikrofonaufnahme via AVAudioEngine → temporäre .m4a |
| `VowriteKit/Services/` | STT-Adapter (OpenAI, Deepgram, iFlytek, etc.) + AIPolishService (Streaming-GPT) |
| `VowriteKit/Config/` | `providers.json`-Registry, `APIProvider`, `ProviderRegistry`, Voreinstellungen, Schlüsseltresor |
| `VowriteKit/Engine/` | `DictationEngine` — plattformübergreifender Orchestrator (Aufnahme → Transkription → Polish → Ausgabe) |
| `VowriteKit/Models/` | SwiftData-Modelle: `DictationRecord`, `Mode`, `ReplacementRule` |
| `VowriteKit/Replacement/` | `ReplacementManager` — Textersetzungsregeln, flexibler Abgleich, Auto-Lernen |
| `VowriteMac/Platform/` | macOS-spezifisch: `HotkeyManager` (Carbon), `TextInjector` (CGEvent), `MacOverlayController`, Sparkle |
| `VowriteIOS/` | iOS-App + Tastaturerweiterung |

### Neuen Anbieter hinzufügen

1. `VowriteKit/Sources/VowriteKit/Config/providers.json` bearbeiten — neuen Eintrag mit `id`, `name`, `baseURL`, `capabilities` (stt/polish) und `models` hinzufügen
2. Wenn der Anbieter eine Standard-OpenAI-kompatible API nutzt, ist das alles — die `ProviderRegistry` erledigt den Rest
3. Wenn der Anbieter ein nicht-standardmäßiges Protokoll nutzt (wie Deepgrams Binär-Upload oder iFlytek WebSocket), erstelle einen neuen `STTAdapter` in `VowriteKit/Services/`

### Neuen STT-Adapter hinzufügen

1. Neue Datei in `VowriteKit/Sources/VowriteKit/Services/` erstellen (z.B. `MySTTAdapter.swift`)
2. `STTAdapter`-Protokoll implementieren — `transcribe(audioURL:language:)` → `String`
3. Adapter im STT-Router (`WhisperService`) registrieren

### Release-Prozess

```bash
cd Vowrite && ops/scripts/release.sh v0.2.1.0 "Kurze Beschreibung"
git push origin main --tags
gh release create v0.2.1.0 releases/Vowrite-v0.2.1.0.dmg --title "Vowrite v0.2.1.0 — Beschreibung"
```

Das Release-Skript erledigt: Changelog-Update → Versionsanhebung (Info.plist + SettingsView.swift) → Release-Build → DMG-Paketierung → Git-Commit + annotierter Tag.

### Konventionen

- **Commits:** `<type>: <description>` — Typen: feat, fix, docs, refactor, chore, security, style, test
- **Branches:** `main` für Releases; `feature/F-{ID}-{slug}` für Feature-Arbeit
- **Versionierung:** 4-Segment `MAJOR.MINOR.PATCH.BUILD`
- **Keine externen Swift-Abhängigkeiten** — nur System-Frameworks

## 🗺️ Roadmap

Siehe die [vollständige Roadmap](ops/ROADMAP.md).

## 📝 Änderungsprotokoll

Siehe [CHANGELOG.md](CHANGELOG.md) oder [GitHub Releases](https://github.com/Joevonlong/Vowrite/releases).

## 🤝 Mitwirken

Beiträge sind willkommen! Bitte [erstelle zuerst ein Issue](https://github.com/Joevonlong/Vowrite/issues), um deine geplanten Änderungen zu besprechen.

## 📄 Lizenz

[MIT](LICENSE)

---

<p align="center">
  Made with 🎤 by <a href="https://github.com/Joevonlong">Joe Long</a>
</p>
