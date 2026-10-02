import Foundation
import Testing
@testable import Zappie

private func snapshot(connected: Bool, batteryW: Double?, updated: Date? = nil) -> PowerSnapshot {
    PowerSnapshot(isExternalConnected: connected, batteryW: batteryW, updateTime: updated)
}

private let t0 = Date(timeIntervalSince1970: 1_790_950_000)

struct PowerStateClassifyTests {
    @Test func disconnectedIsBattery() {
        #expect(PowerState.classify(snapshot(connected: false, batteryW: -16.8)) == .battery)
    }

    @Test func connectedAndChargingAboveThreshold() {
        #expect(PowerState.classify(snapshot(connected: true, batteryW: 31.4)) == .charging)
    }

    @Test func connectedNearZeroIsHold() {
        #expect(PowerState.classify(snapshot(connected: true, batteryW: 0.3)) == .hold)
        #expect(PowerState.classify(snapshot(connected: true, batteryW: -0.5)) == .hold)
        #expect(PowerState.classify(snapshot(connected: true, batteryW: nil)) == .hold)
    }

    @Test func connectedAndDischargingIsAssisted() {
        #expect(PowerState.classify(snapshot(connected: true, batteryW: -5)) == .assisted)
    }

    /// Right after plugging in, IORegistry still publishes the discharge numbers.
    @Test func telemetryOlderThanConnectionChangeIsTreatedAsHold() {
        let stale = snapshot(connected: true, batteryW: -16.8, updated: t0)
        #expect(PowerState.classify(stale, connectionChangedAt: t0.addingTimeInterval(5)) == .hold)

        let fresh = snapshot(connected: true, batteryW: 31.4, updated: t0.addingTimeInterval(10))
        #expect(PowerState.classify(fresh, connectionChangedAt: t0.addingTimeInterval(5)) == .charging)
    }
}

struct StateDebouncerTests {
    @Test func firstValueIsAdoptedImmediately() {
        var d = StateDebouncer(delay: 2)
        #expect(d.update(.charging, at: t0) == .charging)
    }

    @Test func changeNeedsTwoStableSeconds() {
        var d = StateDebouncer(delay: 2)
        _ = d.update(.charging, at: t0)
        #expect(d.update(.hold, at: t0) == .charging)
        #expect(d.update(.hold, at: t0.addingTimeInterval(1.9)) == .charging)
        #expect(d.update(.hold, at: t0.addingTimeInterval(2)) == .hold)
    }

    @Test func flickerRestartsTheTimer() {
        var d = StateDebouncer(delay: 2)
        _ = d.update(.charging, at: t0)
        _ = d.update(.hold, at: t0)
        _ = d.update(.charging, at: t0.addingTimeInterval(1))
        _ = d.update(.hold, at: t0.addingTimeInterval(1.5))
        #expect(d.update(.hold, at: t0.addingTimeInterval(3)) == .charging)
        #expect(d.update(.hold, at: t0.addingTimeInterval(3.5)) == .hold)
    }

    /// Plug/unplug must show within a second, so transitions to or from battery skip the delay.
    @Test func batteryTransitionsAreImmediate() {
        var d = StateDebouncer(delay: 2)
        _ = d.update(.charging, at: t0)
        #expect(d.update(.battery, at: t0.addingTimeInterval(0.1)) == .battery)
        #expect(d.update(.hold, at: t0.addingTimeInterval(0.2)) == .hold)
    }
}
