import SwiftUI
import VowriteKit

struct KeyboardView: View {
    @ObservedObject var state: KeyboardState

    var body: some View {
        VStack(spacing: 0) {
            TopBar(state: state)
                .frame(height: 44)

            Divider()

            RecordArea(state: state)
                .frame(maxHeight: .infinity)

            Divider()

            BottomBar(state: state)
                .frame(height: 44)
        }
        .background(Color(.secondarySystemBackground))
    }
}
