<p align="center">
  <img src="VowriteApp/Resources/AppIcon-source.png" alt="Vowrite" width="128">
</p>

<h1 align="center">Vowrite</h1>

<p align="center">
  <strong>KI-Sprachtastatur für macOS</strong><br>
  Natürlich sprechen. Polierter Text an deinem Cursor.
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
  <code>🎤 Aufnahme</code> → <code>📝 Transkription</code> → <code>✨ Polieren</code> → <code>📋 Einfügen</code>
</p>

Vowrite ist eine schlanke macOS-Menüleisten-App, die deine Sprache in sauberen, polierten Text verwandelt — direkt an deiner Cursor-Position eingefügt. Angetrieben von Whisper für die Transkription und GPT für die Textoptimierung.

Nicht mehr tippen. Einfach sprechen.

## ✨ Funktionen

| | Funktion | Beschreibung |
|---|----------|-------------|
| 🎤 | **Sprache-zu-Text** | Tastenkürzel drücken, sprechen, Text erscheint |
| ✨ | **KI-Polierung** | Entfernt Füllwörter, korrigiert Grammatik, setzt Satzzeichen |
| 🌍 | **Mehrsprachig** | Chinesisch, Englisch und gemischte Sprachen |
| 📋 | **Intelligente Eingabe** | Text erscheint direkt an der Cursor-Position |
| 🎯 | **Überall einsetzbar** | Native Apps, Browser, Discord, VS Code und mehr |
| 🎨 | **Schwebendes Overlay** | Kompakte Aufnahmeleiste mit flüssiger Wellenform-Animation |
| ⌨️ | **Eigenes Tastenkürzel** | Standard: `⌥ Leertaste` — frei konfigurierbar |
| ⎋ | **ESC zum Abbrechen** | Aufnahme jederzeit sofort abbrechen |
| 📊 | **Verlauf** | Vergangene Diktate durchsuchen |
| 🔌 | **Multi-Provider** | OpenAI, Groq, DeepSeek und mehr |

## 🚀 Schnellstart

### Download

Lade die neueste `.dmg` von [**Releases**](https://github.com/Joevonlong/Vowrite/releases) herunter.

### Aus dem Quellcode bauen

```bash
git clone https://github.com/Joevonlong/Vowrite.git
cd Vowrite/VowriteApp
./build.sh
```

### Einrichtung

1. Starte Vowrite — es erscheint als 🎤 in der Menüleiste
2. Öffne **Einstellungen** → gib deinen API-Schlüssel ein ([von OpenAI holen](https://platform.openai.com/api-keys))
3. Erteile **Mikrofon**- und **Bedienungshilfen**-Berechtigungen
4. Drücke `⌥ Leertaste` zum Starten der Aufnahme, erneut zum Stoppen
5. Text wird automatisch an der Cursor-Position eingefügt ✨

## 🔌 Unterstützte Anbieter

| Anbieter | STT-Modell | Polier-Modell |
|----------|-----------|-------------|
| **OpenAI** | whisper-1 | gpt-4o-mini |
| OpenRouter | whisper-large-v3 | gpt-4o-mini |
| Groq | whisper-large-v3-turbo | llama-3.1-8b-instant |
| Together AI | whisper-large-v3 | Llama-3.1-8B-Instruct-Turbo |
| DeepSeek | whisper-1 | deepseek-chat |
| Benutzerdefiniert | konfigurierbar | konfigurierbar |

## 🔧 Funktionsweise

```
Sprache → Whisper-Transkription → GPT-Polierung → Cursor-Einfügung
```

**Texteinfügung** wählt automatisch die beste Methode:

| Methode | Geschwindigkeit | Voraussetzung |
|---------|----------------|---------------|
| Zwischenablage *（Standard）* | ⚡ Sofort | Bedienungshilfen-Berechtigung |
| Unicode-Zeicheneingabe *（Fallback）* | Schnell | Keine Berechtigung nötig |

## 📋 Voraussetzungen

- macOS 14.0 (Sonoma) oder neuer
- API-Schlüssel eines unterstützten Anbieters
- Mikrofon-Berechtigung
- Bedienungshilfen-Berechtigung *(empfohlen, nicht erforderlich)*

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
