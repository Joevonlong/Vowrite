import SwiftUI

public struct BuiltinVoiceEffectSelectorView: View {
    @ObservedObject private var selection: BuiltinVoiceEffectSelection
    private let onSelect: () -> Void
    private let previewSize: BuiltinVoiceEffectCapsuleSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var category = BuiltinVoiceEffectCatalog.categories.first ?? ""

    public init(
        selection: BuiltinVoiceEffectSelection = .shared,
        previewSize: BuiltinVoiceEffectCapsuleSize = .compact,
        onSelect: @escaping () -> Void = {}
    ) {
        self.selection = selection
        self.previewSize = previewSize
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("More Voice Bars")
                        .font(.headline)
                    Text(BuiltinVoiceEffectCatalog.all.isEmpty
                         ? "Built-in Voice Bar resources are unavailable."
                         : "Choose from 80 built-in effects.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !BuiltinVoiceEffectCatalog.all.isEmpty {
                    Picker("Category", selection: $category) {
                        ForEach(BuiltinVoiceEffectCatalog.categories, id: \.self) { Text($0).tag($0) }
                    }
                    .frame(width: 184)
                }
            }

            if let effect = selection.selectedEffect {
                TimelineView(.animation(minimumInterval: 1.0 / 15, paused: reduceMotion)) { context in
                    let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
                    let level = reduceMotion ? 0.55 : 0.55 + sin(time * 3.2) * 0.3
                    HStack(spacing: 12) {
                        BuiltinVoiceEffectCapsule(
                            effect: effect,
                            frame: BuiltinVoiceEffectFrame(
                                phase: .listening,
                                time: time,
                                level: level,
                                reducedMotion: reduceMotion
                            ),
                            size: previewSize,
                            durationText: previewSize == .normal ? "0:08" : nil
                        )
                        .allowsHitTesting(false)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(effect.name).font(.subheadline.weight(.semibold))
                            Text(effect.english).font(.caption2).foregroundStyle(.secondary)
                        }
                        .frame(width: 92, alignment: .leading)
                    }
                }
                .frame(height: previewSize.dimensions.height)
            }

            Picker("Effect", selection: selectedEffectBinding) {
                Text("Choose an effect").tag(Int?.none)
                ForEach(effectsInCategory) { effect in
                    Text("\(effect.number)  \(effect.name) · \(effect.english)").tag(Int?.some(effect.id))
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            if let selectedCategory = selection.selectedEffect?.category {
                category = selectedCategory
            }
        }
    }

    private var effectsInCategory: [BuiltinVoiceEffect] {
        BuiltinVoiceEffectCatalog.all.filter { $0.category == category }
    }

    private var selectedEffectBinding: Binding<Int?> {
        Binding(
            get: { effectsInCategory.contains { $0.id == selection.selectedID } ? selection.selectedID : nil },
            set: { id in
                guard let id else { return }
                selection.select(id)
                onSelect()
            }
        )
    }
}
