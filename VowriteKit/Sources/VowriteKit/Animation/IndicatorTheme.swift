import Foundation

/// Built-in recording indicator presets.
public enum IndicatorPreset: String, CaseIterable, Codable, Sendable {
    case classicBar
    case orbPulse
    case rippleRing
    case spectrumArc
    case minimalDot

    public var displayName: String {
        switch self {
        case .classicBar: return "Classic Bar"
        case .orbPulse: return "Orb Pulse"
        case .rippleRing: return "Ripple Ring"
        case .spectrumArc: return "Spectrum Arc"
        case .minimalDot: return "Minimal Dot"
        }
    }

    public var iconName: String {
        switch self {
        case .classicBar: return "waveform"
        case .orbPulse: return "circle.radiowaves.left.and.right"
        case .rippleRing: return "dot.radiowaves.right"
        case .spectrumArc: return "waveform.badge.magnifyingglass"
        case .minimalDot: return "circle.fill"
        }
    }

    private static let key = StorageKeys.indicatorPreset

    public static var current: IndicatorPreset {
        get {
            // VowriteStorage.defaults, not UserDefaults.standard directly — this
            // used to bypass the Kit's storage abstraction. On macOS the two are
            // the same suite so this is a no-op change there; on iOS the two can
            // diverge (App Group vs. standard), where the old code would have
            // silently split the preference between the container app and the
            // keyboard extension. See StorageMigration for the compensating
            // migration entry.
            guard let raw = VowriteStorage.defaults.string(forKey: key),
                  let preset = IndicatorPreset(rawValue: raw) else { return .classicBar }
            return preset
        }
        set {
            VowriteStorage.defaults.set(newValue.rawValue, forKey: key)
        }
    }
}
