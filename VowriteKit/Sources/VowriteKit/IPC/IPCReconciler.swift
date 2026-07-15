import Foundation

/// Pure decision logic for reconciling a keyboard-side read of
/// `BackgroundRecordingIPC` state against the keyboard's own notion of
/// "the session I started."
///
/// This exists to give the keyboard's two IPC read sites — the live poll
/// loop (`KeyboardState.pollIPCState`, 10Hz while a recording is believed to
/// be in flight) and the reload-time check (`KeyboardState
/// .reloadConfiguration`, run every time the keyboard view appears) — a
/// single, testable source of truth for "does this IPC read belong to me,
/// and what should I do about it." Without a shared decision point the two
/// call sites can (and, before this type existed, did) independently drift
/// on what counts as stale — the root cause of the defect where a keyboard
/// dismissed mid-session left a `.done` + result sitting in App Group
/// storage that a *later*, unrelated recording's first poll tick would read
/// and insert into the wrong host app.
///
/// `IPCReconciler` itself touches no UserDefaults, no Darwin notifications,
/// and holds no state — callers read `ipc.state` / compute session-id
/// equality / read `ipc.isServiceAlive` and pass the results in.
public enum IPCReconciler {
    /// What the keyboard should do after inspecting an IPC read.
    public enum Action: Equatable {
        /// `state` (`.recording` or `.processing`) belongs to the caller's
        /// own session and the service is alive — reflect it in the UI
        /// (start or continue polling as appropriate for the call site).
        case adopt(BackgroundRecordingState)
        /// `.done` belongs to the caller's own session — insert `ipc.result`
        /// into the host app, then return to idle.
        case insertResultAndGoIdle
        /// `.error` belongs to the caller's own session — surface
        /// `ipc.errorMessage` to the user, then return to idle.
        case surfaceErrorAndGoIdle
        /// `state` is `.recording`/`.processing`, the session id matches,
        /// but the service's heartbeat has gone stale — the main app process
        /// died mid-session. Distinct from a foreign session: this is worth
        /// telling the user about rather than discarding silently.
        case serviceDied
        /// Nothing in `defaults` is attributable to the caller: either the
        /// session id doesn't match (a stale or foreign session), or the
        /// state is a `.done`/`.error` the caller has no business acting on.
        /// Discard whatever is there (`ipc.clearResult()`) without
        /// inserting text or surfacing an error, then return to idle.
        case discardAndGoIdle
        /// `state` is `.idle` — no session in flight, nothing to reconcile.
        /// Callers keep their own bespoke idle-handling (e.g. the keyboard
        /// poll loop's `startCommandSentAt` grace period) around this case.
        case none
    }

    /// Decide what a keyboard should do given a single IPC read.
    ///
    /// - Parameters:
    ///   - state: `ipc.state` as read by the caller.
    ///   - sessionMatches: whether `ipc.activeSessionId` equals the caller's
    ///     own remembered session id. Must be `false` when either side is
    ///     `nil` — an absent id never counts as a match (fail toward
    ///     discarding rather than inserting).
    ///   - serviceAlive: `ipc.isServiceAlive` at read time. Only consulted
    ///     for `.recording`/`.processing`, where a matching session with a
    ///     dead service means the main app process died mid-session.
    public static func action(
        state: BackgroundRecordingState,
        sessionMatches: Bool,
        serviceAlive: Bool
    ) -> Action {
        switch state {
        case .idle:
            return .none

        case .recording, .processing:
            guard sessionMatches else { return .discardAndGoIdle }
            guard serviceAlive else { return .serviceDied }
            return .adopt(state)

        case .done:
            return sessionMatches ? .insertResultAndGoIdle : .discardAndGoIdle

        case .error:
            return sessionMatches ? .surfaceErrorAndGoIdle : .discardAndGoIdle
        }
    }
}
