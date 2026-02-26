# Vowrite Development Guide

## Build & Deploy

### Compile
```bash
cd /Users/unclejoe/Dev_Workspace/Vowrite/VowriteApp
swift build
```

### Deploy to Vowrite.app
```bash
# 1. Copy binary
cp .build/arm64-apple-macosx/debug/Vowrite Vowrite.app/Contents/MacOS/Vowrite

# 2. Re-sign (required! Otherwise Accessibility permissions will be invalidated)
codesign --force --sign - Vowrite.app

# 3. If deploying for the first time or permissions are invalidated:
#    System Settings → Privacy & Security → Accessibility → Add Vowrite.app
```

### ⚠️ Important: Re-sign After Every Binary Replacement

For ad-hoc signed apps, the codesign hash changes after each binary replacement. macOS TCC (privacy permission system) will treat it as a "new app", invalidating previously granted Accessibility permissions.

**Solution**: Run `codesign --force --sign -` after replacing the binary. This way the identifier is read from Info.plist (`com.vowrite.app`) and remains stable. If permissions are still invalidated, you'll need to remove and re-add Vowrite in the Accessibility settings.

---

## Text Injection Approach (Core Feature)

### Final Approach: Clipboard + Cmd+V (Maccy Approach)

Based on the proven implementation from Maccy (GitHub 12k+ stars clipboard manager).

**Key Parameters (Do Not Change!)**:

| Parameter | Correct Value | Incorrect Value (Previous Pitfall) |
|-----------|---------------|-------------------------------------|
| CGEventSource | `.combinedSessionState` | ~~`.hidSystemState`~~ |
| Event tap | `.cgSessionEventTap` | ~~`.cghidEventTap`~~ |
| Modifier flags | `.maskCommand \| 0x000008` | ~~Only `.maskCommand`~~ |
| Local event suppression | `setLocalEventsFilterDuringSuppressionState` | ~~None~~ |

### Core Code
```swift
let source = CGEventSource(stateID: .combinedSessionState)
source?.setLocalEventsFilterDuringSuppressionState(
    [.permitLocalMouseEvents, .permitSystemDefinedEvents],
    state: .eventSuppressionStateSuppressionInterval
)
let cmdFlag = CGEventFlags(rawValue: UInt64(CGEventFlags.maskCommand.rawValue) | 0x000008)
let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
keyDown?.flags = cmdFlag
keyUp?.flags = cmdFlag
keyDown?.post(tap: .cgSessionEventTap)
keyUp?.post(tap: .cgSessionEventTap)
```

### Previously Attempted but Unreliable Approaches

| Approach | Issue |
|----------|-------|
| AX API direct insertion (`kAXSelectedTextAttribute`) | Works for native apps, but Electron apps (Discord, VS Code) don't support it |
| `postToPid()` | Unreliable, events often fail to reach the target process |
| `.cghidEventTap` | Unreliable for cross-process on macOS 14+ |
| Unicode character-by-character input | Too slow, Chinese support uncertain |

---

## Permission Checklist

Vowrite requires the following system permissions to function properly:

- [x] **Microphone** — For recording (automatically requested on first launch)
- [x] **Accessibility** — For CGEvent keystroke simulation (must be added manually)
- [ ] **Input Monitoring** — Some systems may require this (if Accessibility alone is insufficient)

### Verifying Permissions Are Active

Call `AXIsProcessTrusted()` in the app — it should return `true`. If it returns `false`, you need to re-add Vowrite in the Accessibility settings.

---

## Overlay (RecordingOverlay) Notes

- Uses `NonActivatingPanel` (`.nonactivatingPanel` style), which doesn't steal focus from the target app
- `canBecomeMain` returns `false`
- After hiding the overlay, the system automatically returns focus to the previous app
- **No need to manually activate the target app** — the system handles focus restoration automatically (though the code still does activate as a safety measure)

---

## Troubleshooting

### Text Cannot Be Inserted Into Target App

1. Check if `AXIsProcessTrusted()` is `true`
2. Check if the binary was replaced without re-signing
3. Check if Accessibility permissions include Vowrite
4. Check console logs: `log show --predicate 'process == "Vowrite"' --last 5m | grep TextInjector`

### Cannot Paste in Specific Apps

- Electron apps (Discord, Slack, VS Code): Cmd+V approach works, AX API approach does not
- Password fields: All approaches fail under Secure Input mode (this is a system limitation)
- Terminal: May require Cmd+V instead of other approaches

---

*Last updated: 2026-02-27*
*Reference: Maccy (github.com/p0deje/Maccy) Clipboard.swift paste() method*
