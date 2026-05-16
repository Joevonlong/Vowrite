import SwiftUI
import UIKit

struct KeyboardInputView: View {
    @ObservedObject var state: KeyboardState

    @State private var kbDeleteTimer: Timer?
    @State private var kbDeletePressStart: Date?
    @State private var kbDeleteLongPressed = false

    var body: some View {
        GeometryReader { geo in
            let layout = KeyLayout(availableWidth: geo.size.width - 8)
            VStack(spacing: 8) {
                if state.keyboardLayout == .letters {
                    lettersSection(layout: layout)
                } else if state.keyboardLayout == .numbers {
                    numbersSection(layout: layout)
                } else {
                    symbolsSection(layout: layout)
                }
                bottomRow(layout: layout)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Layout

    struct KeyLayout {
        let availableWidth: CGFloat
        let gap: CGFloat = 6

        var standardWidth: CGFloat { (availableWidth - 9 * gap) / 10 }

        // Letters row 3: ⇧ + Z X C V B N M (7) + ⌫ → 7×lw + 2×(1.5lw) + 8×gap = 10lw + 48 = w
        var lettersRow3Width: CGFloat { (availableWidth - 8 * gap) / 10 }
        var lettersRow3SpecialWidth: CGFloat { lettersRow3Width * 1.5 }

        // Numbers/Symbols row 3: [toggle] + .,?!' (5) + ⌫ → 5×lw + 2×(1.5lw) + 6×gap = 8lw + 36 = w
        var numbersRow3Width: CGFloat { (availableWidth - 6 * gap) / 8 }
        var numbersRow3SpecialWidth: CGFloat { numbersRow3Width * 1.5 }

        // Bottom row: return is the primary action key — noticeably wider
        // than the 123/ABC toggle so it reads as the dominant key and the
        // space bar stays a moderate width rather than stretching edge-to-edge.
        var returnWidth: CGFloat { lettersRow3SpecialWidth * 1.6 }

        var keyHeight: CGFloat { 44 }
    }

    // MARK: - Letters

    @ViewBuilder
    private func lettersSection(layout: KeyLayout) -> some View {
        HStack(spacing: layout.gap) {
            ForEach(["q","w","e","r","t","y","u","i","o","p"], id: \.self) { key in
                letterKey(key, width: layout.standardWidth, height: layout.keyHeight)
            }
        }
        HStack(spacing: 0) {
            Spacer()
            HStack(spacing: layout.gap) {
                ForEach(["a","s","d","f","g","h","j","k","l"], id: \.self) { key in
                    letterKey(key, width: layout.standardWidth, height: layout.keyHeight)
                }
            }
            Spacer()
        }
        HStack(spacing: layout.gap) {
            shiftKey(width: layout.lettersRow3SpecialWidth, height: layout.keyHeight)
            ForEach(["z","x","c","v","b","n","m"], id: \.self) { key in
                letterKey(key, width: layout.lettersRow3Width, height: layout.keyHeight)
            }
            kbDeleteKey(width: layout.lettersRow3SpecialWidth, height: layout.keyHeight)
        }
    }

    // MARK: - Numbers

    @ViewBuilder
    private func numbersSection(layout: KeyLayout) -> some View {
        HStack(spacing: layout.gap) {
            ForEach(["1","2","3","4","5","6","7","8","9","0"], id: \.self) { key in
                specialCharKey(key, width: layout.standardWidth, height: layout.keyHeight)
            }
        }
        HStack(spacing: layout.gap) {
            ForEach(["-","/",":",";","(",")",  "$","&","@","\""], id: \.self) { key in
                specialCharKey(key, width: layout.standardWidth, height: layout.keyHeight)
            }
        }
        HStack(spacing: layout.gap) {
            symToggleKey("#+=", width: layout.numbersRow3SpecialWidth, height: layout.keyHeight) {
                state.keyboardLayout = .symbols
            }
            ForEach([".",",","?","!","'"], id: \.self) { key in
                specialCharKey(key, width: layout.numbersRow3Width, height: layout.keyHeight)
            }
            kbDeleteKey(width: layout.numbersRow3SpecialWidth, height: layout.keyHeight)
        }
    }

    // MARK: - Symbols

    @ViewBuilder
    private func symbolsSection(layout: KeyLayout) -> some View {
        HStack(spacing: layout.gap) {
            ForEach(["[","]","{","}","#","%","^","*","+","="], id: \.self) { key in
                specialCharKey(key, width: layout.standardWidth, height: layout.keyHeight)
            }
        }
        HStack(spacing: layout.gap) {
            ForEach(["_","\\","|","~","<",">","€","£","¥","•"], id: \.self) { key in
                specialCharKey(key, width: layout.standardWidth, height: layout.keyHeight)
            }
        }
        HStack(spacing: layout.gap) {
            symToggleKey("123", width: layout.numbersRow3SpecialWidth, height: layout.keyHeight) {
                state.keyboardLayout = .numbers
            }
            ForEach([".",",","?","!","'"], id: \.self) { key in
                specialCharKey(key, width: layout.numbersRow3Width, height: layout.keyHeight)
            }
            kbDeleteKey(width: layout.numbersRow3SpecialWidth, height: layout.keyHeight)
        }
    }

    // MARK: - Bottom row

    @ViewBuilder
    private func bottomRow(layout: KeyLayout) -> some View {
        HStack(spacing: layout.gap) {
            if state.showGlobe {
                GlobeKeyButton(inputViewController: state.viewController)
                    .frame(width: layout.lettersRow3SpecialWidth, height: layout.keyHeight)
            }
            specialFunctionKey(
                label: state.keyboardLayout == .letters ? "123" : "ABC",
                width: layout.lettersRow3SpecialWidth,
                height: layout.keyHeight
            ) {
                state.keyboardLayout = state.keyboardLayout == .letters ? .numbers : .letters
            }
            Button { state.insertText(" ") } label: {
                Text("拼")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(KeyboardTheme.subtitleColor)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 16)
                    .frame(height: layout.keyHeight)
                    .background(
                        RoundedRectangle(cornerRadius: KeyboardTheme.keyCornerRadius, style: .continuous)
                            .fill(KeyboardTheme.keyFill)
                            .shadow(color: .black.opacity(0.12), radius: 0, x: 0, y: 1)
                    )
            }
            returnKey(width: layout.returnWidth, height: layout.keyHeight)
        }
    }

    // MARK: - Return key (dark — matches image-2 style)

    private func returnKey(width: CGFloat, height: CGFloat) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            state.insertText("\n")
        } label: {
            Image(systemName: "return")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(KeyboardTheme.accentText)
                .frame(width: width, height: height)
                .background(
                    RoundedRectangle(cornerRadius: KeyboardTheme.keyCornerRadius, style: .continuous)
                        .fill(KeyboardTheme.accentFill)
                        .shadow(color: .black.opacity(0.18), radius: 0, x: 0, y: 1)
                )
        }
    }

    // MARK: - Key builders

    private func letterKey(_ char: String, width: CGFloat, height: CGFloat) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            state.typeLetter(char)
        } label: {
            Text(state.keyboardShift == .off ? char : char.uppercased())
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(KeyboardTheme.titleColor)
                .frame(width: width, height: height)
                .background(
                    RoundedRectangle(cornerRadius: KeyboardTheme.keyCornerRadius, style: .continuous)
                        .fill(Color(UIColor.systemGray5))
                        .shadow(color: .black.opacity(0.25), radius: 0, x: 0, y: 1)
                )
        }
    }

    private func specialCharKey(_ char: String, width: CGFloat, height: CGFloat) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            state.insertText(char)
        } label: {
            Text(char)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(KeyboardTheme.titleColor)
                .frame(width: width, height: height)
                .background(
                    RoundedRectangle(cornerRadius: KeyboardTheme.keyCornerRadius, style: .continuous)
                        .fill(Color(UIColor.systemGray5))
                        .shadow(color: .black.opacity(0.25), radius: 0, x: 0, y: 1)
                )
        }
    }

    private func specialFunctionKey(label: String, width: CGFloat, height: CGFloat, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(KeyboardTheme.titleColor)
                .frame(width: width, height: height)
                .background(
                    RoundedRectangle(cornerRadius: KeyboardTheme.keyCornerRadius, style: .continuous)
                        .fill(Color(UIColor.systemGray4))
                        .shadow(color: .black.opacity(0.25), radius: 0, x: 0, y: 1)
                )
        }
    }

    private func symToggleKey(_ label: String, width: CGFloat, height: CGFloat, action: @escaping () -> Void) -> some View {
        specialFunctionKey(label: label, width: width, height: height, action: action)
    }

    // MARK: - Shift key

    private func shiftKey(width: CGFloat, height: CGFloat) -> some View {
        let bg: Color = {
            switch state.keyboardShift {
            case .off: return Color(UIColor.systemGray4)
            case .shift, .capsLock: return Color(UIColor.systemGray2)
            }
        }()
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            state.handleShiftTap()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: KeyboardTheme.keyCornerRadius, style: .continuous)
                    .fill(bg)
                    .shadow(color: .black.opacity(0.25), radius: 0, x: 0, y: 1)
                VStack(spacing: 2) {
                    Image(systemName: state.keyboardShift == .capsLock ? "capslock.fill" : "shift")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(KeyboardTheme.titleColor)
                    if state.keyboardShift == .capsLock {
                        Circle().fill(KeyboardTheme.titleColor).frame(width: 4, height: 4)
                    }
                }
            }
            .frame(width: width, height: height)
        }
        .animation(.easeOut(duration: 0.1), value: state.keyboardShift)
    }

    // MARK: - Keyboard delete (continuous, no F-067 popup)

    private func kbDeleteKey(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: KeyboardTheme.keyCornerRadius, style: .continuous)
                .fill(KeyboardTheme.specialKeyFill)
                .shadow(color: .black.opacity(0.25), radius: 0, x: 0, y: 1)
            Image(systemName: "delete.left")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(KeyboardTheme.titleColor)
        }
        .frame(width: width, height: height)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if kbDeletePressStart == nil {
                        kbDeletePressStart = Date()
                        kbDeleteLongPressed = false
                    }
                    if !kbDeleteLongPressed,
                       let start = kbDeletePressStart,
                       Date().timeIntervalSince(start) >= 0.4 {
                        kbDeleteLongPressed = true
                        kbDeleteTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                            Task { @MainActor in state.deleteBackward() }
                        }
                    }
                }
                .onEnded { _ in
                    kbDeleteTimer?.invalidate(); kbDeleteTimer = nil
                    if !kbDeleteLongPressed { state.deleteBackward() }
                    kbDeletePressStart = nil; kbDeleteLongPressed = false
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
        )
    }
}
