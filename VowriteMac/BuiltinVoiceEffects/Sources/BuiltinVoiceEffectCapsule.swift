import SwiftUI

public enum BuiltinVoiceEffectCapsuleSize: Equatable, Sendable {
    case compact
    case normal

    public var dimensions: CGSize {
        switch self {
        case .compact: CGSize(width: 184, height: 40)
        case .normal: CGSize(width: 232, height: 48)
        }
    }
}

public struct BuiltinVoiceEffectCapsule: View {
    public let effect: BuiltinVoiceEffect
    public let frame: BuiltinVoiceEffectFrame
    public let size: BuiltinVoiceEffectCapsuleSize
    public let durationText: String?
    private let onCancel: () -> Void
    private let onFinish: () -> Void

    public init(
        effect: BuiltinVoiceEffect,
        frame: BuiltinVoiceEffectFrame,
        size: BuiltinVoiceEffectCapsuleSize,
        durationText: String? = nil,
        onCancel: @escaping () -> Void = {},
        onFinish: @escaping () -> Void = {}
    ) {
        self.effect = effect
        self.frame = frame
        self.size = size
        self.durationText = durationText
        self.onCancel = onCancel
        self.onFinish = onFinish
    }

    public var body: some View {
        Group {
            if frame.phase == .processing {
                processingContent
            } else {
                recordingContent
            }
        }
        .padding(.horizontal, 6)
        .frame(width: size.dimensions.width, height: size.dimensions.height)
        .background(Color(white: 0.035), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 0.75))
        .shadow(color: .black.opacity(0.24), radius: 5, y: 2)
    }

    private var recordingContent: some View {
        HStack(spacing: 6) {
            capsuleButton("Cancel recording", icon: "xmark", primary: false, action: onCancel)
            VStack(spacing: 0) {
                effectPreview
                if size == .normal, let durationText {
                    Text(durationText)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.72))
                        .frame(height: 10)
                }
            }
            .frame(maxWidth: .infinity)
            .help(durationText.map { "Recording · \($0)" } ?? "Recording")
            capsuleButton("Finish recording", icon: "checkmark", primary: true, action: onFinish)
        }
    }

    private var processingContent: some View {
        HStack(spacing: 6) {
            effectPreview
                .frame(maxWidth: .infinity)
            CapsuleProcessingRing()
            Text(size == .compact ? "Working" : "Processing")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Processing your recording")
    }

    private var effectPreview: some View {
        BuiltinVoiceEffectPreview(effect: effect, frame: frame)
            .frame(height: 28)
            .clipped()
            .accessibilityLabel("Recording with \(effect.name)")
    }

    private func capsuleButton(
        _ label: String,
        icon: String,
        primary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
                .foregroundStyle(primary ? Color.black : Color.white)
                .background(primary ? Color.white : Color(white: 0.24), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
    }
}

private struct CapsuleProcessingRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1)
            ZStack {
                Circle().stroke(Color.white.opacity(0.25), lineWidth: 1.5)
                Circle().trim(from: 0, to: 0.72)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .rotationEffect(.degrees(reduceMotion ? -90 : phase * 360 - 90))
            }
            .frame(width: 14, height: 14)
        }
    }
}
