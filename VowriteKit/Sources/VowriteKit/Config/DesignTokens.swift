import SwiftUI

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

    // MARK: - Colors (semantic, opacity-based)

    public enum Colors {

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
