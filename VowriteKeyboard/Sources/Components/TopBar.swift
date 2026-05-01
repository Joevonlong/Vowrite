import SwiftUI
import UIKit
import VowriteKit

struct TopBar: View {
    @ObservedObject var state: KeyboardState

    // F-067: long-press bulk-delete gesture state.
    @State private var pressActive = false
    @State private var pressStartedAt: Date?
    @State private var popupVisible = false
    @State private var fingerOnPopup = false
    @State private var popupHoldStartedAt: Date?
    @State private var popupFrame: CGRect = .zero
    @State private var popupRevealWorkItem: DispatchWorkItem?
    @State private var tierHapticWorkItems: [DispatchWorkItem] = []

    // Continuous-delete state (active while popup visible but finger not on popup).
    @State private var continuousDeleteTimer: Timer?
    @State private var continuousDeleteSpeed: TimeInterval = 0.1

    private let coordSpace = "topbar.delete"
    private let longPressThreshold: TimeInterval = 0.4

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "dot.radiowaves.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(KeyboardTheme.titleColor)
                Text("Vowrite")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(KeyboardTheme.titleColor)
            }

            Spacer()

            HStack(spacing: 12) {
                actionButton(text: "@") { state.insertText("@") }
                actionButton(text: "─") { state.insertSpace() }
                deleteButton
            }
        }
        .padding(.horizontal, 16)
        .coordinateSpace(name: coordSpace)
    }

    // MARK: - Action button (non-delete)

    @ViewBuilder
    private func actionButton(
        symbol: String? = nil,
        text: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(KeyboardTheme.buttonFill)
                    .frame(width: KeyboardTheme.actionButtonSize,
                           height: KeyboardTheme.actionButtonSize)

                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(KeyboardTheme.iconColor)
                } else if let text {
                    Text(text)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(KeyboardTheme.iconColor)
                }
            }
        }
    }

    // MARK: - F-067 Delete button + bulk-clear popup

    private var deleteButton: some View {
        ZStack {
            Circle()
                .fill(KeyboardTheme.buttonFill)
                .frame(width: KeyboardTheme.actionButtonSize,
                       height: KeyboardTheme.actionButtonSize)
            Image(systemName: "delete.left")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(KeyboardTheme.iconColor)
        }
        .scaleEffect(pressActive && !popupVisible ? 0.94 : 1.0)
        .animation(.easeOut(duration: 0.12), value: pressActive)
        .contentShape(Circle())
        .overlay(alignment: .top) {
            if popupVisible {
                BulkDeletePopupView(
                    fingerOnPopup: fingerOnPopup,
                    popupHoldStartedAt: popupHoldStartedAt,
                    coordSpaceName: coordSpace,
                    frameUpdate: { popupFrame = $0 }
                )
                .offset(y: 56)
                .allowsHitTesting(false)
                .transition(
                    .scale(scale: 0.7, anchor: .top)
                        .combined(with: .opacity)
                )
            }
        }
        .gesture(deleteGesture)
    }

    private var deleteGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(coordSpace))
            .onChanged { handleDragChanged(value: $0) }
            .onEnded { handleDragEnded(value: $0) }
    }

    private func handleDragChanged(value: DragGesture.Value) {
        if !pressActive {
            pressActive = true
            pressStartedAt = Date()
            scheduleRevealPopup()
        }

        guard popupVisible else { return }

        let inside = popupFrame.contains(value.location)
        if inside, !fingerOnPopup {
            fingerOnPopup = true
            popupHoldStartedAt = Date()
            stopContinuousDelete()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            scheduleTierHaptics()
        } else if !inside, fingerOnPopup {
            fingerOnPopup = false
            popupHoldStartedAt = nil
            cancelTierHaptics()
            startContinuousDelete()
        }
    }

    private func handleDragEnded(value: DragGesture.Value) {
        popupRevealWorkItem?.cancel()
        popupRevealWorkItem = nil
        cancelTierHaptics()
        stopContinuousDelete()

        let wasPopupVisible = popupVisible
        let wasFingerOnPopup = fingerOnPopup
        let popupHoldStart = popupHoldStartedAt
        let pressStart = pressStartedAt
        let now = Date()

        // Reset gesture-local state.
        pressActive = false
        pressStartedAt = nil
        fingerOnPopup = false
        popupHoldStartedAt = nil
        if wasPopupVisible {
            withAnimation(.easeOut(duration: 0.18)) {
                popupVisible = false
            }
        }

        if wasPopupVisible, wasFingerOnPopup, let start = popupHoldStart {
            let elapsed = now.timeIntervalSince(start)
            let tier = KeyboardState.BulkDeleteTier.from(elapsed: elapsed)
            state.bulkDelete(tier: tier)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }

        // Quick tap (no popup ever revealed) → single delete, matching the
        // pre-F-067 muscle memory.
        if !wasPopupVisible,
           let start = pressStart,
           now.timeIntervalSince(start) < longPressThreshold {
            state.deleteBackward()
        }
        // Otherwise: long-press without entering popup → continuous delete
        // already ran; nothing more to do.
    }

    private func scheduleRevealPopup() {
        let work = DispatchWorkItem {
            guard pressActive, !popupVisible else { return }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                popupVisible = true
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            startContinuousDelete()
        }
        popupRevealWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + longPressThreshold, execute: work)
    }

    // MARK: - Tier haptics

    /// Schedule selection haptics at the three tier crossings (0.5s / 1.3s /
    /// 2.5s) so the user feels each escalation even with a stationary finger.
    /// DragGesture.onChanged doesn't fire on a still finger, so we can't
    /// drive haptics from there.
    private func scheduleTierHaptics() {
        cancelTierHaptics()
        for delay in [0.5, 1.3, 2.5] as [TimeInterval] {
            let work = DispatchWorkItem {
                UISelectionFeedbackGenerator().selectionChanged()
            }
            tierHapticWorkItems.append(work)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    }

    private func cancelTierHaptics() {
        for w in tierHapticWorkItems { w.cancel() }
        tierHapticWorkItems.removeAll()
    }

    // MARK: - Continuous delete (preserved from pre-F-067 behavior)

    private func startContinuousDelete() {
        stopContinuousDelete()
        continuousDeleteSpeed = 0.1
        continuousDeleteTimer = Timer.scheduledTimer(
            withTimeInterval: continuousDeleteSpeed,
            repeats: true
        ) { _ in
            Task { @MainActor in
                state.deleteBackward()
            }
            if continuousDeleteSpeed > 0.05 {
                continuousDeleteSpeed -= 0.01
                continuousDeleteTimer?.invalidate()
                continuousDeleteTimer = Timer.scheduledTimer(
                    withTimeInterval: continuousDeleteSpeed,
                    repeats: true
                ) { _ in
                    Task { @MainActor in
                        state.deleteBackward()
                    }
                }
            }
        }
    }

    private func stopContinuousDelete() {
        continuousDeleteTimer?.invalidate()
        continuousDeleteTimer = nil
        continuousDeleteSpeed = 0.1
    }
}

// MARK: - F-067 Popup view

private struct BulkDeletePopupView: View {
    let fingerOnPopup: Bool
    let popupHoldStartedAt: Date?
    let coordSpaceName: String
    let frameUpdate: (CGRect) -> Void

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: 0.08,
                paused: !(fingerOnPopup && popupHoldStartedAt != nil)
            )
        ) { context in
            let tier: KeyboardState.BulkDeleteTier? = {
                guard fingerOnPopup, let start = popupHoldStartedAt else { return nil }
                return KeyboardState.BulkDeleteTier.from(
                    elapsed: context.date.timeIntervalSince(start)
                )
            }()
            content(tier: tier)
        }
    }

    @ViewBuilder
    private func content(tier: KeyboardState.BulkDeleteTier?) -> some View {
        let label = tier?.label ?? "上滑清空"
        HStack(spacing: 6) {
            Image(systemName: "trash")
                .font(.system(size: 14, weight: .semibold))
            Text(label)
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule().fill(Color.black.opacity(0.85))
        )
        .scaleEffect(fingerOnPopup ? 1.06 : 1.0)
        .shadow(color: .black.opacity(fingerOnPopup ? 0.25 : 0.12),
                radius: 8, y: 3)
        .animation(.spring(response: 0.22, dampingFraction: 0.85),
                   value: fingerOnPopup)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: PopupFrameKey.self,
                    value: proxy.frame(in: .named(coordSpaceName))
                )
            }
        )
        .onPreferenceChange(PopupFrameKey.self) { rect in
            frameUpdate(rect)
        }
    }
}

private struct PopupFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
