# Vowrite Architecture

## System Flow

```
User presses Option+Space
        ↓
   Start Recording (AVAudioEngine → m4a buffer)
        ↓
   User releases / presses again
        ↓
   Stop Recording → Save audio file
        ↓
   Send to Whisper API → Raw transcript
        ↓
   Send to GPT-4o-mini → Polished text
        ↓
   Clipboard Injection:
     1. Save current clipboard
     2. Set polished text to clipboard
     3. Simulate Cmd+V
     4. Restore original clipboard
        ↓
   Save to history (SwiftData)
        ↓
   Done ✓ (audio feedback)
```

## Module Responsibilities

### AudioEngine
- AVAudioEngine for recording
- Output: temporary .m4a file
- Handles microphone permissions
- Provides audio level metering for UI visualization

### WhisperService
- Sends audio file to OpenAI Whisper API (`/v1/audio/transcriptions`)
- Model: `whisper-1`
- Auto language detection (supports mixed language)
- Returns raw transcript text

### AIPolishService
- Sends raw transcript to GPT-4o-mini
- System prompt handles:
  - Filler word removal (um, uh, 嗯, 啊, 那个)
  - Self-correction detection (keeps only final intent)
  - Repetition removal
  - Punctuation and paragraph formatting
  - Natural expression improvement (without over-editing)
- Streaming response for faster perceived speed

### TextInjector
- Primary: Clipboard injection (Cmd+V simulation)
  1. NSPasteboard.general save
  2. Set new string
  3. CGEvent post Cmd+V
  4. Async restore original clipboard (200ms delay)
- Requires Accessibility permission for CGEvent

### HotkeyManager
- Global hotkey registration via Carbon API / MASShortcut
- Default: Option+Space
- Modes: push-to-talk (hold) / toggle (press to start, press to stop)

### HistoryStore
- SwiftData with Note model
- Fields: id, rawTranscript, polishedText, duration, language, createdAt
- Local only, no sync

## Key Decisions

| Decision | Choice | Why |
|----------|--------|-----|
| Menu bar app | Yes | Always accessible, no dock clutter |
| Clipboard injection | Over AX API | Works with ALL apps reliably |
| Whisper API | Over local | Best multilingual quality |
| GPT-4o-mini | Over GPT-4o | Fast enough, much cheaper |
| SwiftData | Over Core Data | Modern, less boilerplate |
| m4a format | Over wav | 10x smaller, Whisper supports it |

## Permissions Required

1. **Microphone** — Recording audio (NSMicrophoneUsageDescription)
2. **Accessibility** — Simulating Cmd+V keystroke (System Settings → Privacy)
3. **Speech Recognition** — Not needed (using Whisper API, not Apple Speech)

## Error Handling Strategy

- Network failure → Show error in overlay, keep audio file for retry
- API rate limit → Queue and retry with backoff
- Microphone busy → Notify user, suggest closing other apps
- Accessibility denied → Show setup guide overlay
