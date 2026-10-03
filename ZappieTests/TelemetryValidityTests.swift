import Foundation
import Testing
@testable import Zappie

/// The battery driver sometimes publishes mixed-up numbers right at a plug change and keeps them
/// until its next refresh (up to ~60 s). Those watts must not reach the screen or the history.
struct TelemetryValidityTests {
    @Test func impossibleNumbersAreHidden() throws {
        let s = try #require(PowerReader.parse(battery: Fixtures.unplugGlitch, pack: nil))
        #expect(!s.telemetryValid)
        #expect(s.systemLoadW == nil)
        #expect(s.batteryW == nil)
        #expect(s.adapterInW == nil)
        #expect(s.percent == 80)
    }

    @Test func normalNumbersStay() throws {
        let s = try #require(PowerReader.parse(battery: Fixtures.discharging, pack: nil))
        #expect(s.telemetryValid)
        #expect(s.batteryW == -16.86)
    }

    @Test func negativeSystemLoadIsImpossibleWhilePluggedInToo() throws {
        var battery = Fixtures.pluggedHold
        var telemetry = battery["PowerTelemetryData"] as! [String: Any]
        telemetry["SystemLoad"] = NSNumber(value: UInt64(bitPattern: -500))
        battery["PowerTelemetryData"] = telemetry
        #expect(try #require(PowerReader.parse(battery: battery, pack: nil)).telemetryValid == false)
    }

    @Test func historySkipsHiddenWatts() {
        var h = PowerHistory()
        let t0 = Date(timeIntervalSince1970: 1_790_949_960)
        let hidden = PowerSnapshot(isExternalConnected: false, telemetryValid: false)
        h.record(hidden, at: t0)
        h.record(hidden, at: t0 + 1)
        h.record(hidden, at: t0 + 2)
        #expect(h.samples(.hour).isEmpty)
    }

    @Test func treeSaysWaitingForUpdate() {
        let s = PowerSnapshot(isExternalConnected: false, percent: 78, telemetryValid: false)
        let tree = PowerTree(snapshot: s, state: .battery)
        #expect(tree.systemText == "—")
        #expect(tree.batteryText == "—")
        #expect(tree.macText == "갱신 대기 중")
    }
}

@MainActor
struct StaleAfterPlugChangeTests {
    /// The first driver publication after a plug change still mixes in the old power source.
    @Test func wattsHiddenUntilFirstUpdateAfterChange() {
        var now = Date(timeIntervalSince1970: 1_791_004_400)
        var reading = PowerSnapshot(isExternalConnected: true, adapterInW: 17, systemLoadW: 17, batteryW: 0.2,
                                    updateTime: now)
        let monitor = PowerMonitor(read: { reading }, now: { now }, logReason: { _ in })
        monitor.refresh()

        now += 5
        reading = PowerSnapshot(isExternalConnected: false, adapterInW: 0, systemLoadW: 14, batteryW: -14,
                                updateTime: now - 1)
        monitor.refresh()
        #expect(monitor.state == .battery)
        #expect(monitor.snapshot?.batteryW == nil)
        #expect(monitor.snapshot?.telemetryValid == false)

        now += 60
        reading.updateTime = now
        monitor.refresh()
        #expect(monitor.snapshot?.batteryW == -14)
        #expect(monitor.snapshot?.telemetryValid == true)
    }
}
