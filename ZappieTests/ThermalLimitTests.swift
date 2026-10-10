import Foundation
import Testing
@testable import Zappie

/// `ChargerData.TimeChargingThermallyLimited` (0 so far on this Mac). Whether it is a live flag or
/// a running total is unverified, so "macOS is limiting charging for heat" means the value grew
/// within the last 3 minutes. Each start is logged so the meaning can be confirmed later.
struct ThermalLimitTrackerTests {
    let t0 = Date(timeIntervalSince1970: 1_791_100_000)

    @Test func firstReadingIsOnlyABaseline() {
        var t = ThermalLimitTracker()
        #expect(t.update(120, at: t0) == false)
        #expect(!t.isLimiting)
    }

    @Test func growingValueMeansLimiting() {
        var t = ThermalLimitTracker()
        _ = t.update(0, at: t0)
        #expect(t.update(30, at: t0 + 60) == true) // started
        #expect(t.isLimiting)
        #expect(t.update(90, at: t0 + 120) == false) // still limiting, not a new start
        #expect(t.isLimiting)
    }

    @Test func clearsAfterThreeQuietMinutes() {
        var t = ThermalLimitTracker()
        _ = t.update(0, at: t0)
        _ = t.update(30, at: t0 + 60)
        _ = t.update(30, at: t0 + 120)
        #expect(t.isLimiting)
        _ = t.update(30, at: t0 + 241)
        #expect(!t.isLimiting)
    }

    @Test func missingValueChangesNothing() {
        var t = ThermalLimitTracker()
        _ = t.update(0, at: t0)
        _ = t.update(30, at: t0 + 60)
        #expect(t.update(nil, at: t0 + 90) == false)
        #expect(t.isLimiting)
    }

    @Test func readerParsesTheValue() throws {
        let s = try #require(PowerReader.parse(battery: Fixtures.pluggedHold, pack: nil))
        #expect(s.thermallyLimitedTime == 0)
    }
}

struct ThermalLimitDisplayTests {
    let s = PowerSnapshot(isExternalConnected: true, adapterInW: 30, systemLoadW: 25, batteryW: 5, temperatureC: 41.24)

    @Test func hotAndLimited() {
        #expect(PowerTree(snapshot: s, state: .charging, heat: .warm, thermalLimited: true).batteryHeat
                == "41.2 °C · 충전 조절 중")
    }

    @Test func limitedWithoutOurWarning() {
        #expect(PowerTree(snapshot: s, state: .charging, thermalLimited: true).batteryHeat == "온도로 충전 조절 중")
    }

    @Test func hotButNotLimited() {
        #expect(PowerTree(snapshot: s, state: .charging, heat: .warm).batteryHeat == "41.2 °C · 뜨거움")
    }

    @Test func treeTintsLimitedBatteryAsWarning() {
        #expect(PowerTree(snapshot: s, state: .charging, thermalLimited: true).heat == .normal)
        #expect(PowerTree(snapshot: s, state: .charging, thermalLimited: true).thermalLimited)
    }
}

@MainActor
struct ThermalLimitMonitorTests {
    @Test func monitorPublishesAndLogsLimitStart() {
        var logged: [ChargeReasonSighting] = []
        var reading = PowerSnapshot(isExternalConnected: true, batteryW: 5, percent: 60, thermallyLimitedTime: 0)
        var now = Date(timeIntervalSince1970: 1_791_100_000)
        let monitor = PowerMonitor(read: { reading }, now: { now }, logReason: { logged.append($0) },
                                   notify: { _ in })
        monitor.refresh()
        reading.thermallyLimitedTime = 45
        now += 60
        monitor.refresh()
        #expect(monitor.thermalLimited)
        #expect(logged.map(\.key) == ["TimeChargingThermallyLimited"])
        #expect(logged.first?.value == 45)
    }
}
