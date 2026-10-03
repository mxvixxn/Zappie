import Foundation

enum PowerState: Sendable, Equatable {
    /// Running on battery.
    case battery
    /// Adapter connected, battery charging.
    case charging
    /// Adapter powers the system directly; battery idle (e.g. held at the charge limit).
    case hold
    /// Adapter connected but insufficient; battery discharging to help.
    case assisted

    /// Battery watts within ±threshold count as idle. Telemetry reads exactly 0 when the battery
    /// is idle, so this only absorbs rounding; flicker is handled by `StateDebouncer`.
    /// (Was 0.5 W, which hid a real 0.3 W assist as "배터리 대기".)
    static let idleThresholdW = 0.1

    /// - Parameter connectionChangedAt: When `isExternalConnected` last flipped. Telemetry older
    ///   than that still describes the previous power source, so its watts are ignored.
    static func classify(_ snapshot: PowerSnapshot, connectionChangedAt: Date? = nil) -> PowerState {
        guard snapshot.isExternalConnected else { return .battery }

        if let changed = connectionChangedAt, let updated = snapshot.updateTime, updated < changed {
            return .hold
        }
        guard let w = snapshot.batteryW else { return .hold }

        if w > idleThresholdW { return .charging }
        if w < -idleThresholdW { return .assisted }
        return .hold
    }
}

/// Holds back state changes until the new state has been stable for `delay` seconds.
/// Changes to or from `.battery` (plug/unplug) pass through immediately.
struct StateDebouncer {
    let delay: TimeInterval
    private(set) var current: PowerState?
    private var pending: (state: PowerState, since: Date)?

    init(delay: TimeInterval) {
        self.delay = delay
    }

    mutating func update(_ state: PowerState, at now: Date) -> PowerState {
        guard let current, state != current else {
            pending = nil
            self.current = state
            return state
        }

        if state == .battery || current == .battery {
            return adopt(state)
        }

        if pending?.state != state {
            pending = (state, now)
        }
        if let pending, now.timeIntervalSince(pending.since) >= delay {
            return adopt(state)
        }
        return current
    }

    private mutating func adopt(_ state: PowerState) -> PowerState {
        pending = nil
        current = state
        return state
    }
}
