import SwiftUI

struct KeyboardSetupGuide: View {
    enum Step {
        case addKeyboard
        case enableFullAccess
    }

    let step: Step

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch step {
            case .addKeyboard:
                guideRow(number: 1, text: "Open Settings")
                guideRow(number: 2, text: "General > Keyboard")
                guideRow(number: 3, text: "Keyboards > Add New Keyboard...")
                guideRow(number: 4, text: "Select Vowrite")

            case .enableFullAccess:
                guideRow(number: 1, text: "Open Settings > Vowrite")
                guideRow(number: 2, text: "Tap Keyboards")
                guideRow(number: 3, text: "Enable \"Allow Full Access\"")
            }
        }
        .padding(.horizontal, 40)
    }

    private func guideRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.accentColor, in: Circle())

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
