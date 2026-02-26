# Vowrite Development Roadmap

## v0.1 — macOS MVP (Current Sprint)

### Milestone 1: Foundation
- [ ] Xcode project setup (macOS menu bar app, SwiftUI)
- [ ] App lifecycle (menu bar icon, popover panel)
- [ ] Microphone permission flow
- [ ] Accessibility permission detection + guide

### Milestone 2: Core Pipeline
- [ ] AVAudioEngine recording → m4a file
- [ ] Global hotkey (Option+Space) — toggle mode
- [ ] Whisper API integration (audio → text)
- [ ] AI polish integration (raw → polished text)
- [ ] Clipboard injection (polished text → active app)

### Milestone 3: UX
- [ ] Recording overlay (floating indicator with waveform)
- [ ] Processing state indicator
- [ ] Success/error audio feedback
- [ ] Basic history list in popover

### Milestone 4: Settings & Polish
- [ ] Settings panel (API key, hotkey config)
- [ ] Launch at login
- [ ] Error handling (network, permissions, API limits)
- [ ] First-run onboarding

---

## v0.2 — Refinement
- [ ] History search and management
- [ ] Export (text, markdown)
- [ ] Custom AI polish styles (formal, casual, concise)
- [ ] Audio level visualization during recording
- [ ] Retry failed transcriptions

## v0.3 — iOS
- [ ] iOS Custom Keyboard Extension
- [ ] Shared core logic (SPM package)
- [ ] Main app for settings + history
- [ ] iCloud sync (optional)

## v1.0 — Advanced
- [ ] Personal dictionary (names, terms)
- [ ] Per-app tone adaptation
- [ ] Translation mode
- [ ] Select text + voice edit
- [ ] Voice commands (make shorter, change tone, etc.)
- [ ] Local Whisper fallback (offline mode)
