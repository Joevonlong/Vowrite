import AppKit

/// The V-leaves brand silhouette, drawn as vectors for every display scale.
enum MenuBarLogo {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.saveGState()
            defer { context.restoreGState() }

            // Crop the transparent master margins and center its visible bounds.
            // Paths are from Resources/AppIcon-source.svg; fine colored details
            // are omitted to keep the silhouette legible at menu-bar sizes.
            let scale: CGFloat = 18 / 754
            context.translateBy(x: 9 - 512 * scale, y: -198 * scale)
            context.scaleBy(x: scale, y: scale)

            let leaves = CGMutablePath()
            leaves.move(to: CGPoint(x: 258, y: 198))
            leaves.addCurve(
                to: CGPoint(x: 210, y: 630),
                control1: CGPoint(x: 178, y: 286),
                control2: CGPoint(x: 158, y: 458)
            )
            leaves.addCurve(
                to: CGPoint(x: 510, y: 952),
                control1: CGPoint(x: 264, y: 800),
                control2: CGPoint(x: 392, y: 898)
            )
            leaves.addLine(to: CGPoint(x: 514, y: 952))
            leaves.addCurve(
                to: CGPoint(x: 412, y: 462),
                control1: CGPoint(x: 504, y: 792),
                control2: CGPoint(x: 462, y: 602)
            )
            leaves.addCurve(
                to: CGPoint(x: 258, y: 198),
                control1: CGPoint(x: 360, y: 320),
                control2: CGPoint(x: 306, y: 234)
            )
            leaves.closeSubpath()

            leaves.move(to: CGPoint(x: 766, y: 198))
            leaves.addCurve(
                to: CGPoint(x: 814, y: 630),
                control1: CGPoint(x: 846, y: 286),
                control2: CGPoint(x: 866, y: 458)
            )
            leaves.addCurve(
                to: CGPoint(x: 514, y: 952),
                control1: CGPoint(x: 760, y: 800),
                control2: CGPoint(x: 632, y: 898)
            )
            leaves.addLine(to: CGPoint(x: 510, y: 952))
            leaves.addCurve(
                to: CGPoint(x: 612, y: 462),
                control1: CGPoint(x: 520, y: 792),
                control2: CGPoint(x: 562, y: 602)
            )
            leaves.addCurve(
                to: CGPoint(x: 766, y: 198),
                control1: CGPoint(x: 664, y: 320),
                control2: CGPoint(x: 718, y: 234)
            )
            leaves.closeSubpath()
            context.addPath(leaves)
            context.setFillColor(NSColor.black.cgColor)
            context.fillPath()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Vowrite"
        return image
    }()
}
