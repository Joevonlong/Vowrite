import SwiftUI
import UIKit

struct VoiceBottomRow: View {
    @ObservedObject var state: KeyboardState

    var body: some View {
        HStack(spacing: 10) {
            Button { state.insertReturn() } label: {
                Text("换行")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(KeyboardTheme.titleColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        Capsule()
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.10), radius: 3, y: 1)
                    )
            }
            DeleteButton(state: state)
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
    }
}

// MARK: - F-067 Delete Button (relocated from TopBar)

private struct DeleteButton: View {
    @ObservedObject var state: KeyboardState

    @State private var pressActive = false
    @State private var pressStartedAt: Date?
    @State private var popupVisible = false
    @State private var fingerOnPopup = false
    @State private var popupHoldStartedAt: Date?
    @State private var popupFrame: CGRect = .zero
    @State private var popupRevealWorkItem: DispatchWorkItem?
    @State private var tierHapticWorkItems: [DispatchWorkItem] = []
    @State private var continuousDeleteTimer: Timer?
    @State private var continuousDeleteSpeed: TimeInterval = 0.1

    private let coordSpace = "voicebottomrow.delete"
    private let longPressThreshold: TimeInterval = 0.4
    private let popupOffsetAboveButton: CGFloat = 60

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 44, height: 44)
                .shadow(color: .black.opacity(0.10), radius: 3, y: 1)
            Image(systemName: "delete.left")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(KeyboardTheme.iconColor)
        }
        .scaleEffect(pressActive && !popupVisible ? 0.94 : 1.0)
        .animation(.easeOut(duration: 0.12), value: pressActive)
        .contentShape(Circle())
        .overlay(alignment: .topTrailing) {
            if popupVisible {
                BulkDeletePopupView(
                    fingerOnPopup: fingerOnPopup,
                    popupHoldStartedAt: popupHoldStartedAt,
                    coordSpaceName: coordSpace,
                    frameUpdate: { popupFrame = $0 }
                )
                .offset(y: -popupOffsetAboveButton)
                .allowsHitTesting(false)
                .transition(.scale(scale: 0.75, anchor: .bottomTrailing).combined(with: .opacity))
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named(coordSpace))
                .onChanged { handleDragChanged(value: $0) }
                .onEnded { handleDragEnded(value: $0) }
        )
        .coordinateSpace(name: coordSpace)
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

        pressActive = false
        pressStartedAt = nil
        fingerOnPopup = false
        popupHoldStartedAt = nil

        if wasPopupVisible {
            withAnimation(.easeOut(duration: 0.22)) { popupVisible = false }
        }

        if wasPopupVisible, wasFingerOnPopup, let start = popupHoldStart {
            let tier = KeyboardState.BulkDeleteTier.from(elapsed: now.timeIntervalSince(start))
            state.bulkDelete(tier: tier)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }

        if !wasPopupVisible, let start = pressStart,
           now.timeIntervalSince(start) < longPressThreshold {
            state.deleteBackward()
        }
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

    private func scheduleTierHaptics() {
        cancelTierHaptics()
        for delay in [0.5, 1.3, 2.5] as [TimeInterval] {
            let work = DispatchWorkItem { UISelectionFeedbackGenerator().selectionChanged() }
            tierHapticWorkItems.append(work)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    }

    private func cancelTierHaptics() {
        tierHapticWorkItems.forEach { $0.cancel() }
        tierHapticWorkItems.removeAll()
    }

    private func startContinuousDelete() {
        stopContinuousDelete()
        continuousDeleteSpeed = 0.1
        continuousDeleteTimer = Timer.scheduledTimer(withTimeInterval: continuousDeleteSpeed, repeats: true) { _ in
            Task { @MainActor in state.deleteBackward() }
            if continuousDeleteSpeed > 0.05 {
                continuousDeleteSpeed -= 0.01
                continuousDeleteTimer?.invalidate()
                continuousDeleteTimer = Timer.scheduledTimer(withTimeInterval: continuousDeleteSpeed, repeats: true) { _ in
                    Task { @MainActor in state.deleteBackward() }
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

// MARK: - F-067 Popup (moved from TopBar)

private struct BulkDeletePopupView: View {
    let fingerOnPopup: Bool
    let popupHoldStartedAt: Date?
    let coordSpaceName: String
    let frameUpdate: (CGRect) -> Void

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.08, paused: !(fingerOnPopup && popupHoldStartedAt != nil))) { context in
            let tier: KeyboardState.BulkDeleteTier? = {
                guard fingerOnPopup, let start = popupHoldStartedAt else { return nil }
                return KeyboardState.BulkDeleteTier.from(elapsed: context.date.timeIntervalSince(start))
            }()
            content(tier: tier)
        }
    }

    @ViewBuilder
    private func content(tier: KeyboardState.BulkDeleteTier?) -> some View {
        let label = tier?.label ?? "删除全部"
        HStack(spacing: 8) {
            Image(systemName: "trash.fill").font(.system(size: 17, weight: .semibold))
            Text(label)
                .font(.system(size: 17, weight: .semibold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Capsule().fill(Color.black.opacity(0.88)))
        .scaleEffect(fingerOnPopup ? 1.05 : 1.0)
        .shadow(color: .black.opacity(fingerOnPopup ? 0.30 : 0.18), radius: 10, y: 4)
        .animation(.spring(response: 0.22, dampingFraction: 0.85), value: fingerOnPopup)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: PopupFrameKey.self,
                                       value: proxy.frame(in: .named(coordSpaceName)))
            }
        )
        .onPreferenceChange(PopupFrameKey.self) { frameUpdate($0) }
    }
}

private struct PopupFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}
