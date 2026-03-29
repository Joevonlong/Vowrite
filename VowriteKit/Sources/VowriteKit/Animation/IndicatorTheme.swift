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

    private static let key = "indicatorPreset"

    public static var current: IndicatorPreset {
        get {
            guard let raw = UserDefaults.standard.string(forKey: key),
                  let preset = IndicatorPreset(rawValue: raw) else { return .classicBar }
            return preset
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
        }
    }
}
