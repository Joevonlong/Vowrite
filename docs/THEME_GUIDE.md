# Recording Indicator Theme Guide

This guide covers Vowrite's recording indicator system — the visual feedback shown while recording and processing audio.

## Built-in Presets

Vowrite ships with 5 recording indicator presets:

| Preset | Icon | Style | Key Characteristics |
|--------|------|-------|--------------------|
| **Classic Bar** | `waveform` | Floating capsule bar | Waveform visualization, duration display, cancel/confirm buttons |
| **Orb Pulse** | `circle.radiowaves.left.and.right` | Breathing orb | Orange radial gradient, audio-reactive scaling, breathing animation |
| **Ripple Ring** | `dot.radiowaves.right` | Concentric ripples | Cyan rings expanding outward, audio controls ripple density |
| **Spectrum Arc** | `waveform.badge.magnifyingglass` | Semicircular bars | 12 bars in a 180-degree arc, each bar responds to audio level |
| **Minimal Dot** | `circle.fill` | Single dot | Size + color dual signal (cyan-to-red), accessibility-friendly |

## Switching Presets

1. Open **Settings** (click the menu bar icon > Settings)
2. Go to the **General** tab
3. Scroll to **Recording Indicator**
4. Click a preset to select it

The change takes effect immediately on the next recording.

## Technical Architecture

Each indicator follows a three-layer rendering model:

### 1. Icon Layer
The center element — typically a microphone icon during recording, switching to an ellipsis during processing.

### 2. Animation Layer
Audio-reactive animations driven by `appState.audioLevel` (0.0 to 1.0):
- **Recording state:** Animations respond to real-time audio input
- **Processing state:** Steady, non-reactive animation (breathing, rotating, etc.)
- **Idle state:** Returns `EmptyView()` — the overlay is hidden

### 3. Glow / Effect Layer
Background effects like blurs, shadows, and gradients that add depth and visual polish.

### Design Tokens

All indicators use centralized design tokens from `VW` (defined in `DesignTokens.swift`):

```swift
VW.Anim.easeStandard    // State transitions (0.2s ease-in-out)
VW.Anim.springQuick      // Interactive feedback (0.3s spring)
VW.Colors.Overlay.*      // Overlay-specific colors
```

## Custom Theme Packs

> Coming in Phase 2

Theme packs will allow bundling custom indicator configurations:

```json
{
  "name": "My Custom Theme",
  "version": 1,
  "indicator": {
    "type": "dotLottie",
    "recording": "recording.lottie",
    "processing": "processing.lottie"
  },
  "colors": {
    "primary": "#00BCD4",
    "glow": "#00BCD480"
  }
}
```

## dotLottie Custom Themes

> Coming in Phase 2

Future versions will support importing `.lottie` files as custom recording indicators. This will allow designers to create fully custom animations without writing SwiftUI code.

## Contributing a New Built-in Preset

Want to add a new indicator preset to Vowrite? Here's how:

### 1. Add the preset case

In `VowriteKit/Sources/VowriteKit/Animation/IndicatorTheme.swift`:

```swift
public enum IndicatorPreset: String, CaseIterable, Codable, Sendable {
    // ... existing cases
    case yourPreset
}
```

Add `displayName` and `iconName` in the corresponding switch statements. Use an SF Symbol for `iconName`.

### 2. Create the indicator view

Create `VowriteMac/Sources/Views/YourPresetIndicator.swift`:

```swift
import SwiftUI
import VowriteKit

struct YourPresetIndicator: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Group {
            switch appState.state {
            case .recording:
                recordingView    // Audio-reactive, uses appState.audioLevel
            case .processing:
                processingView   // Steady animation, no audio reactivity
            default:
                EmptyView()
            }
        }
        .animation(VW.Anim.easeStandard, value: appState.state)
    }
}
```

**Requirements:**
- Must handle `recording`, `processing`, and idle states
- Recording state must respond to `appState.audioLevel` (0.0–1.0)
- Use `.animation()` modifiers rather than `Timer` where possible
- Use `VW.Anim.*` design tokens for state transitions

### 3. Wire it up

1. **RecordingOverlay.swift** — Add a case in `RecordingIndicatorView`'s switch
2. **MacOverlayController.swift** — Add overlay size in `overlaySize`
3. **GeneralPage.swift** — Add a preview thumbnail in `indicatorPreview(for:)`

### 4. Submit a PR

- Include a screenshot or GIF showing both recording and processing states
- Note the overlay size you chose and why
- Test with different audio levels (silence, speaking, loud)
