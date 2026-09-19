import SwiftUI
#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Vowrite Design Tokens — single source of truth for visual constants.
/// Usage: `VW.Spacing.md`, `VW.Radius.lg`, `VW.Anim.springQuick`, etc.
public enum VW {

    // MARK: - Spacing

    public enum Spacing {
        public static let xxs: CGFloat = 2
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 6
        public static let md: CGFloat = 8
        public static let lg: CGFloat = 10
        public static let xl: CGFloat = 12
        public static let xxl: CGFloat = 16
        public static let xxxl: CGFloat = 20
        public static let section: CGFloat = 24
        public static let page: CGFloat = 28
        public static let pageLarge: CGFloat = 32
        public static let pageXL: CGFloat = 40
    }

    // MARK: - Corner Radius

    public enum Radius {
        public static let xs: CGFloat = 2
        public static let sm: CGFloat = 3
        public static let md: CGFloat = 4
        public static let lg: CGFloat = 6
        public static let xl: CGFloat = 8
        public static let xxl: CGFloat = 10
        public static let xxxl: CGFloat = 12
        public static let pill: CGFloat = 999

        // Semantic aliases for the unified native UI. Existing values stay valid.
        public static let control: CGFloat = 8
        public static let panel: CGFloat = 12
        public static let overlay: CGFloat = 16
    }

    // MARK: - Animations

    public enum Anim {
        public static let springQuick = Animation.spring(response: 0.3, dampingFraction: 0.8)
        public static let springMedium = Animation.spring(response: 0.35, dampingFraction: 0.7)
        public static let easeQuick = Animation.easeInOut(duration: 0.15)
        public static let easeStandard = Animation.easeInOut(duration: 0.2)
        public static let easeNavigation = Animation.easeInOut(duration: 0.25)
        public static let smoothHover = Animation.smooth(duration: 0.2)
    }

    // MARK: - Colors

    public enum Colors {

        /// Opaque surfaces from the unified design. Keyboard extensions continue
        /// to use their transparent system background instead of a canvas fill.
        public enum Surface {
            public static let canvas = adaptive(light: 0xF5F6F8, dark: 0x111318)
            public static let panel = adaptive(light: 0xFFFFFF, dark: 0x1B1F26)
            public static let secondary = adaptive(light: 0xEFF2F6, dark: 0x242A34)
        }

        public enum Text {
            public static let primary = adaptive(light: 0x17202B, dark: 0xF3F5F7)
            public static let secondary = adaptive(light: 0x536171, dark: 0xB6C0CD)
        }

        public enum Action {
            public static let primary = adaptive(light: 0x1D4ED8, dark: 0x93B4FF)
            public static let soft = adaptive(light: 0xEAF0FF, dark: 0x23324F)
        }

        public enum Border {
            public static let standard = adaptive(light: 0xE0E4EA, dark: 0x343D4A)
        }

        /// Keep recording and destructive feedback semantically independent,
        /// even where their palette values coincide. Always pair with a label.
        public enum Status {
            public static let recording = adaptive(light: 0xB42318, dark: 0xFFACA5)
            public static let processing = adaptive(light: 0x1D4ED8, dark: 0x93B4FF)
            public static let success = adaptive(light: 0x166534, dark: 0x86D6A3)
            public static let warning = adaptive(light: 0x854D0E, dark: 0xF1D078)
            public static let error = adaptive(light: 0xB42318, dark: 0xFFACA5)
        }

        /// Resolve on each render through the native appearance/trait provider.
        /// This responds to SwiftUI's preferredColorScheme and local environment
        /// overrides, rather than capturing the system appearance at startup.
        private static func adaptive(light: UInt32, dark: UInt32) -> Color {
            #if os(macOS)
            return Color(nsColor: NSColor(name: nil) { appearance in
                let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
                return NSColor(
                    srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                    green: CGFloat((hex >> 8) & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255,
                    alpha: 1
                )
            })
            #elseif canImport(UIKit)
            return Color(uiColor: UIColor { traits in
                let hex = traits.userInterfaceStyle == .dark ? dark : light
                return UIColor(
                    red: CGFloat((hex >> 16) & 0xFF) / 255,
                    green: CGFloat((hex >> 8) & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255,
                    alpha: 1
                )
            })
            #else
            return Color(
                .sRGB,
                red: Double((light >> 16) & 0xFF) / 255,
                green: Double((light >> 8) & 0xFF) / 255,
                blue: Double(light & 0xFF) / 255,
                opacity: 1
            )
            #endif
        }

        // Legacy opacity-based tokens remain available during page migration.

        public enum Background {
            public static let subtle = Color.primary.opacity(0.03)
            public static let secondary = Color.secondary.opacity(0.04)
            public static let tertiary = Color.secondary.opacity(0.06)
            public static let elevated = Color.secondary.opacity(0.08)
        }

        public enum Accent {
            public static let light = Color.accentColor.opacity(0.08)
            public static let medium = Color.accentColor.opacity(0.1)
            public static let strong = Color.accentColor.opacity(0.15)
        }

        public enum Stroke {
            public static let light = Color.primary.opacity(0.06)
            public static let standard = Color.secondary.opacity(0.3)
        }

        public enum Overlay {
            public static let recording = Color.black.opacity(0.85)
            public static let processing = Color.black.opacity(0.75)
            public static let buttonFill = Color.white.opacity(0.12)
            public static let buttonStroke = Color.white.opacity(0.1)
        }

        public enum Destructive {
            public static let background = Color.red.opacity(0.06)
        }
    }
}
