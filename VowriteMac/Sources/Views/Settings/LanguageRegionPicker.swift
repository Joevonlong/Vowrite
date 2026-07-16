import VowriteKit
import SwiftUI

/// F-079: Two-level language picker — a primary "main language" `Picker`
/// plus a secondary "region variant" `Picker` that only appears for
/// languages that have variants defined (e.g. Chinese, English, Spanish,
/// Portuguese, French). Selecting a new main language always resets to that
/// language's plain code (no variant); selecting a variant row updates
/// `selection` to the full BCP-47 tag.
///
/// Reused by `GeneralPage` (default + translation language settings) and
/// `ModeEditorSheet` (per-mode translation language settings).
struct LanguageRegionPicker: View {
    @Binding var selection: SupportedLanguage
    /// Excludes "Auto-detect" from the main-language list (used for
    /// translation targets, which must be an explicit language).
    var excludeAuto: Bool = false
    var width: CGFloat = 180

    private var family: SupportedLanguage { selection.languageFamily }

    private var familyOptions: [SupportedLanguage] {
        let roots = SupportedLanguage.familyRoots
        return excludeAuto ? roots.filter { $0 != .auto } : roots
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Picker("", selection: Binding(
                get: { family },
                set: { selection = $0 }
            )) {
                ForEach(familyOptions) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .frame(width: width)

            if !family.regionVariants.isEmpty {
                Picker("", selection: $selection) {
                    Text("Auto / Default").tag(family)
                    ForEach(family.regionVariants) { variant in
                        Text(variant.regionLabel ?? variant.displayName).tag(variant)
                    }
                }
                .frame(width: width)
            }
        }
    }
}
