import Foundation

/// Resolves VowriteKit's processed Swift Package resources in an app bundle.
///
/// macOS app bundles place package resources under Contents/Resources, while
/// the generated Bundle.module accessor may only know the package build
/// directory or the app root. Resolve the embedded bundle first so a shipped
/// app never depends on a developer's absolute build path.
internal enum VowriteResources {
    private static let bundleName = "VowriteKit_VowriteKit.bundle"

    static let bundle: Bundle = resolve(mainBundle: .main) {
        Bundle.module
    }

    static func resolve(mainBundle: Bundle, fallback: () -> Bundle) -> Bundle {
        let candidates = [
            mainBundle.resourceURL?.appendingPathComponent(bundleName),
            mainBundle.bundleURL.appendingPathComponent(bundleName)
        ].compactMap { $0 }.compactMap(Bundle.init(url:))

        if let embedded = candidates.first {
            return embedded
        }
        return fallback()
    }
}
