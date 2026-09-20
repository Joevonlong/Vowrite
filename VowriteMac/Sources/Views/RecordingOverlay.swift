import VowriteKit
import SwiftUI
import AppKit
import BuiltinVoiceEffects

struct RecordingIndicatorView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Group {
            if let effect = BuiltinVoiceEffectSelection.shared.selectedEffect {
                BuiltinVoiceEffectOverlay(appState: appState, effect: effect)
                    .padding(.top, 12)
            } else {
                switch IndicatorPreset.current {
                case .classicBar: RecordingBarView(appState: appState).padding(.top, 12)
                case .orbPulse: OrbPulseIndicator(appState: appState)
                case .rippleRing: RippleRingIndicator(appState: appState)
                case .spectrumArc: SpectrumArcIndicator(appState: appState)
                case .minimalDot: MinimalDotIndicator(appState: appState)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct BuiltinVoiceEffectOverlay: View {
    @ObservedObject var appState: AppState
    let effect: BuiltinVoiceEffect
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var durationText: String {
        let total = Int(appState.recordingDuration)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private var sessionBadge: (icon: String, label: String)? {
        if appState.engine.isInTranslateSession, let raw = appState.engine.sessionTranslationTarget {
            return ("globe", "→ \(SupportedLanguage(rawValue: raw)?.shortLabel ?? raw.uppercased())")
        }
        if appState.engine.isInPerAppModeSession, let name = appState.engine.sessionModeOverrideName {
            return ("theatermasks", name)
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            BuiltinVoiceEffectPreview(
                effect: effect,
                frame: BuiltinVoiceEffectFrame(
                    phase: appState.state == .recording ? .listening : .processing,
                    time: reduceMotion ? 0 : Date.timeIntervalSinceReferenceDate,
                    level: reduceMotion ? 0.5 : Double(appState.audioLevel),
                    reducedMotion: reduceMotion
                )
            )
            .frame(height: 96)

            if appState.state == .recording {
                HStack(spacing: 12) {
                    overlayButton("Cancel recording", icon: "xmark", primary: false) { appState.cancelRecording() }
                    Text(durationText)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.78))
                        .frame(maxWidth: .infinity)
                    overlayButton("Finish recording", icon: "checkmark", primary: true) { appState.stopRecording() }
                }
            } else if appState.state == .processing {
                HStack(spacing: 10) {
                    ProgressView().progressViewStyle(OverlayProcessingProgressStyle(diameter: 15))
                    Text("Processing").font(.system(size: 12, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(.white)
            }
        }
        .padding(8)
        .frame(width: 320, height: 148)
        .background(Color(white: 0.035), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(white: 0.38), lineWidth: 1))
        .overlay(alignment: .topTrailing) {
            if let badge = sessionBadge {
                Label(badge.label, systemImage: badge.icon)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .foregroundStyle(VW.Colors.Text.primary)
                    .background(VW.Colors.Action.soft, in: Capsule())
                    .overlay(Capsule().stroke(VW.Colors.Border.standard))
                    .frame(maxWidth: 156)
                    .help(badge.label)
                    .offset(x: -8, y: -10)
            }
        }
    }

    private func overlayButton(_ label: String, icon: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 28)
                .foregroundStyle(primary ? Color.black : Color.white)
                .background(primary ? Color.white : Color(white: 0.26), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
    }
}

/// The compact capsule exposes only the existing recording actions. Processing
/// remains non-interactive because the engine has no processing-cancel contract.
struct RecordingBarView: View {
    @ObservedObject var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isCompact: Bool { OverlayStyle.current == .compact }
    private var width: CGFloat { OverlayStyle.current.barSize.width }
    private var height: CGFloat { OverlayStyle.current.barSize.height }
    private var durationText: String {
        let total = Int(appState.recordingDuration)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private var sessionBadge: (icon: String, label: String)? {
        if appState.engine.isInTranslateSession, let raw = appState.engine.sessionTranslationTarget {
            return ("globe", "→ \(SupportedLanguage(rawValue: raw)?.shortLabel ?? raw.uppercased())")
        }
        if appState.engine.isInPerAppModeSession, let name = appState.engine.sessionModeOverrideName {
            return ("theatermasks", name)
        }
        return nil
    }

    var body: some View {
        Group {
            switch appState.state {
            case .recording: recordingBar
            case .processing: processingBar
            default: EmptyView()
            }
        }
        .animation(reduceMotion ? nil : VW.Anim.easeStandard, value: appState.state)
    }

    private var recordingBar: some View {
        HStack(spacing: 8) {
            capsuleButton("Cancel recording", icon: "xmark", primary: false) { appState.cancelRecording() }
            VStack(spacing: 2) {
                WaveformView(level: appState.audioLevel, maximumHeight: isCompact ? 22 : 20)
                    .frame(maxWidth: .infinity)
                    .frame(height: isCompact ? 22 : 20)
                    .accessibilityLabel("Recording")
                if !isCompact {
                    Text(durationText).font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .help("Recording · \(durationText)")
            capsuleButton("Finish recording", icon: "checkmark", primary: true) { appState.stopRecording() }
        }
        .padding(.horizontal, 8)
        .frame(width: width, height: height)
        .background(Color(white: 0.035), in: Capsule())
        .overlay(Capsule().stroke(Color(white: 0.38), lineWidth: 1))
        .overlay(alignment: .topTrailing) {
            if let badge = sessionBadge {
                Label(badge.label, systemImage: badge.icon)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .foregroundStyle(VW.Colors.Text.primary)
                    .background(VW.Colors.Action.soft, in: Capsule())
                    .overlay(Capsule().stroke(VW.Colors.Border.standard))
                    .frame(maxWidth: 156)
                    .help(badge.label)
                    .offset(x: -8, y: -10)
            }
        }
    }

    private func capsuleButton(_ label: String, icon: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: isCompact ? 13 : 15, weight: .semibold))
                .frame(width: isCompact ? 28 : 32, height: isCompact ? 28 : 32)
                .foregroundStyle(primary ? Color.black : Color.white)
                .background(primary ? Color.white : Color(white: 0.26), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
    }

    private var processingBar: some View {
        HStack(spacing: 12) {
            ProgressView().progressViewStyle(OverlayProcessingProgressStyle())
            Text("Processing").font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(.white)
        .frame(width: width, height: height)
        .background(Color(white: 0.035), in: Capsule())
        .overlay(Capsule().stroke(Color(white: 0.38), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Processing your recording")
    }
}

/// Visual amplitude is driven by the engine's measured audio level. No random
/// samples or autonomous animation imply speech when the microphone is quiet.
struct WaveformView: View {
    let level: Float
    var maximumHeight: CGFloat = 28
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<13, id: \.self) { index in
                let distance = abs(CGFloat(index) - 6) / 6
                let amplitude = CGFloat(min(1, max(0, level))) * (1 - distance * 0.65)
                Capsule()
                    .fill(Color.white)
                    .frame(width: 3, height: 3 + amplitude * (maximumHeight - 3))
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: level)
        .accessibilityHidden(true)
    }
}

/// High-contrast progress for a dark, non-activating recording overlay.
/// A custom style avoids AppKit dimming an inactive native spinner.
struct OverlayProcessingProgressStyle: ProgressViewStyle {
    var diameter: CGFloat = 16

    func makeBody(configuration: Configuration) -> some View {
        OverlayProcessingRing(diameter: diameter)
    }
}

private struct OverlayProcessingRing: View {
    let diameter: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1)
            ZStack {
                Circle().stroke(Color.white.opacity(0.3), lineWidth: 2)
                Circle().trim(from: 0, to: 0.72)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(reduceMotion ? -90 : phase * 360 - 90))
            }
            .frame(width: diameter, height: diameter)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Processing")
    }
}
