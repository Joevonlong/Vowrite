# Vowrite Text Injection Issue — Full Analysis Report

## 1. Problem Description

After speech recognition completes, text cannot be inserted at the cursor position in the target application. The clipboard has content, but the text is not pasted/typed into the input field.

---

## 2. Current Vowrite Implementation

### Flow
1. User presses hotkey → `startRecording()` → `saveFrontmostApp()` records the currently active app
2. Display recording overlay (NonActivatingPanel)
3. User speaks → presses hotkey again to stop
4. Send audio to Whisper API → get text → AI polish
5. Hide overlay
6. Call `textInjector.inject(text)` → activate previous app → inject text

### Current Injection Strategy (Modified Version)
- **Method A (Primary)**: Accessibility API direct insertion — `AXUIElementSetAttributeValue(kAXSelectedTextAttribute)`
- **Method B (Fallback)**: Clipboard + Cmd+V — `NSPasteboard` set content → `CGEvent` simulate Cmd+V
- **Method C (Fallback)**: Unicode character-by-character input — `CGEvent` send individual characters

---

## 3. All Possible Failure Causes

### ❌ Permission Issues (Most Likely Cause)

| Cause | Description | Impact |
|-------|-------------|--------|
| **Accessibility permission not granted** | Vowrite is not allowed in System Settings → Privacy & Security → Accessibility | AX API calls return failure; CGEvent cannot send keyboard events to other processes |
| **Input Monitoring permission not granted** | Not allowed in Privacy & Security → Input Monitoring | CGEvent keyboard events cannot reach the target app |
| **AXIsProcessTrusted() returns false** | App is not trusted by the system | All AX and CGEvent methods fail completely |
| **Ad-hoc signing** | App uses ad-hoc signing without a Team ID | TCC permission records become invalid after each binary replacement, requiring re-authorization |

### ❌ Code-Level Issues

| Cause | Description |
|-------|-------------|
| **Incorrect CGEventSource usage** | Vowrite uses `.hidSystemState`, while Maccy (industry benchmark) uses `.combinedSessionState` |
| **Incorrect CGEvent posting target** | Vowrite uses `.cghidEventTap`, while Maccy uses `.cgSessionEventTap` |
| **Missing left/right marker bits for modifier flags** | Maccy additionally includes `0x000008` (NX_COMMANDMASK), indicating the specific left Command key |
| **Not suppressing local keyboard events** | Maccy calls `setLocalEventsFilterDuringSuppressionState` during pasting to prevent interference |
| **Target app not truly activated** | `app.activate()` is asynchronous and doesn't guarantee the app has focus when it returns |
| **AX method ineffective for web apps** | In Chrome/Safari and other browsers, `kAXSelectedTextAttribute` in text fields may not be writable |

### ❌ Timing Issues

| Cause | Description |
|-------|-------------|
| **Focus doesn't return to target app after overlay closes** | Although NonActivatingPanel is used, focus may return to the Vowrite main process after hiding |
| **Clipboard restored too early** | Previously set to 1.5s; if the target app reads the clipboard slowly, it will fail |
| **Focus already changed when recording starts** | If the user starts recording via the menu bar (instead of hotkey), Vowrite may already be the foreground app |

### ❌ System/Environment Issues

| Cause | Description |
|-------|-------------|
| **macOS security policy upgrades** | macOS 14+ has stricter restrictions on cross-process CGEvent injection |
| **Target app rejects programmatic input** | Some apps (e.g., Terminal, some Electron apps) don't accept external CGEvents |
| **Secure Input mode** | If the target app has Secure Input enabled (e.g., password fields), all injection methods are blocked |

---

## 4. Industry Benchmark Research

### 1. Maccy (Clipboard Manager, GitHub 12k+ stars) — Source Code Analysis

**Core paste code** (`Clipboard.swift` → `paste()` method):

```swift
func paste() {
    Accessibility.check()
    
    let cmdFlag = CGEventFlags(rawValue: UInt64(KeyChord.pasteKeyModifiers.rawValue) | 0x000008)
    var vCode = Sauce.shared.keyCode(for: KeyChord.pasteKey)
    
    if KeyboardLayout.current.commandSwitchesToQWERTY && cmdFlag.contains(.maskCommand) {
        vCode = KeyChord.pasteKey.QWERTYKeyCode
    }
    
    let source = CGEventSource(stateID: .combinedSessionState)
    source?.setLocalEventsFilterDuringSuppressionState(
        [.permitLocalMouseEvents, .permitSystemDefinedEvents],
        state: .eventSuppressionStateSuppressionInterval
    )
    
    let keyVDown = CGEvent(keyboardEventSource: source, virtualKey: vCode, keyDown: true)
    let keyVUp = CGEvent(keyboardEventSource: source, virtualKey: vCode, keyDown: false)
    keyVDown?.flags = cmdFlag
    keyVUp?.flags = cmdFlag
    keyVDown?.post(tap: .cgSessionEventTap)
    keyVUp?.post(tap: .cgSessionEventTap)
}
```

**Key Differences**:

| Element | Vowrite (Current) | Maccy (Correct Approach) |
|---------|-------------------|--------------------------|
| CGEventSource | `.hidSystemState` | `.combinedSessionState` |
| Event tap | `.cghidEventTap` | `.cgSessionEventTap` |
| Modifier flags | Only `.maskCommand` | `.maskCommand \| 0x000008` (includes left/right marker) |
| Local event suppression | None | `setLocalEventsFilterDuringSuppressionState` |
| Focus restoration | Manual activate + polling | System automatically restores after popup closes |

**Maccy's Flow** (much simpler than Vowrite):
1. User selects an item in the Maccy popup
2. `Clipboard.copy(item)` — writes content to clipboard
3. `popup.close()` — **closes the popup first**, letting the system automatically return focus to the previous app
4. `Clipboard.paste()` — then sends Cmd+V

**Key Insight: Maccy doesn't need to manually activate the target app!** It relies on the system automatically restoring focus after closing the popup.

### 2. Superwhisper (Commercial Voice Input Tool)

The most similar product to Vowrite. Based on its feature description:
- Uses "Push to talk" mode
- Text is directly input into the currently focused application
- Supports all apps (including Cursor, browsers, etc.)

Superwhisper is closed source, but based on behavior analysis, it most likely uses the **clipboard + Cmd+V** approach (similar to Maccy), because:
- Users report clipboard content briefly changes after pasting
- It requires Accessibility permissions

### 3. macOS Native Dictation

Apple's own dictation feature uses a completely different underlying approach:
- Uses **Input Method Kit (IMK)** as a system-level input method
- Communicates directly with text fields through the `NSTextInputClient` protocol
- No clipboard needed, no keystroke simulation
- Third-party apps cannot use this approach (requires registration as a system input method)

### 4. Approach Feasibility Summary

| Approach | Reliability | Compatibility | Complexity | Notes |
|----------|-------------|---------------|------------|-------|
| **Clipboard + Cmd+V** (Maccy approach) | ⭐⭐⭐⭐⭐ | All apps | Low | Industry-proven, most reliable |
| AX API direct value setting | ⭐⭐⭐ | Native apps | Medium | Browsers/Electron may not support |
| CGEvent Unicode input | ⭐⭐ | Most apps | Low | Slow, Chinese support uncertain |
| Input Method Kit | ⭐⭐⭐⭐⭐ | All apps | Very High | Requires input method registration, massive development effort |
| AppleScript paste | ⭐⭐⭐ | Apps supporting AS | Low | Not universal |

---

## 5. Conclusions and Fix Recommendations

### Root Causes (High Probability)

1. **Permission issues** — Ad-hoc signed apps lose TCC permissions after each binary replacement, requiring re-authorization
2. **Incorrect CGEvent parameters** — Using the wrong EventSource and EventTap types

### Recommended Fix

**Adopt Maccy's paste approach** (verified by a 12k+ stars project):

1. Use `CGEventSource(stateID: .combinedSessionState)`
2. Use `.cgSessionEventTap` instead of `.cghidEventTap`
3. Add `0x000008` left key marker to modifier flags
4. Call `setLocalEventsFilterDuringSuppressionState` before pasting
5. **Close the overlay first → wait for system focus restoration → then paste**, instead of manually activating

### Permission Checklist

- [ ] System Settings → Privacy & Security → **Accessibility** → Add Vowrite
- [ ] System Settings → Privacy & Security → **Input Monitoring** → Add Vowrite (if available)
- [ ] After each Vowrite.app binary replacement, re-confirm permissions (due to ad-hoc signing)

---

*Analysis date: 2026-02-27*
*Reference source code: Maccy v0.32+ (GitHub: p0deje/Maccy)*
