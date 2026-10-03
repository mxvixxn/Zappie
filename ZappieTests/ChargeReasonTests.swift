import Foundation
import Testing
@testable import Zappie

/// Why the battery is idle or charging slowly, from `ChargerData` (docs/SPEC.md §1).
/// Only `NotChargingReason` 0x1000000 (charge limit) is verified so far; anything else is logged.
struct ChargeReasonTests {
    @Test func readerParsesChargerReasons() throws {
        let s = try #require(PowerReader.parse(battery: Fixtures.pluggedHold, pack: nil))
        #expect(s.notChargingReason == 0x100_0000)
        #expect(s.slowChargingReason == 0)
        #expect(s.fullyCharged == false)
    }

    func hold(percent: Int, reason: Int?, full: Bool = false) -> String {
        let s = PowerSnapshot(isExternalConnected: true, adapterInW: 12, systemLoadW: 12, batteryW: 0, percent: percent,
                              notChargingReason: reason, fullyCharged: full)
        return PowerPresentation(snapshot: s, state: .hold).detailValue
    }

    @Test func bypassExplainsWhy() {
        #expect(hold(percent: 80, reason: 0x100_0000) == "80% 한도에서 유지 중")
        #expect(hold(percent: 100, reason: 0, full: true) == "완충")
        #expect(hold(percent: 62, reason: 0x4) == "62%에서 충전 일시 중지")
        #expect(hold(percent: 80, reason: 0) == "80%에서 유지 중")
        #expect(hold(percent: 80, reason: nil) == "80%에서 유지 중")
    }

    @Test func slowChargingIsNoted() {
        let s = PowerSnapshot(isExternalConnected: true, adapterInW: 20, systemLoadW: 12, batteryW: 8, timeToFullMin: 24,
                              slowChargingReason: 2)
        #expect(PowerPresentation(snapshot: s, state: .charging).detailValue == "약 24분 · 느린 충전")
    }
}

struct ChargeReasonTrackerTests {
    let t0 = Date(timeIntervalSince1970: 1_791_000_000)

    @Test func reportsEachUnknownValueOnce() {
        var tracker = ChargeReasonTracker()
        let s = PowerSnapshot(isExternalConnected: true, batteryW: 0, percent: 62, notChargingReason: 0x4)
        let first = tracker.newSightings(in: s, at: t0)
        #expect(first == [.init(key: "NotChargingReason", value: 0x4, date: t0, percent: 62, batteryW: 0,
                                adapterInW: nil, connected: true)])
        #expect(tracker.newSightings(in: s, at: t0 + 1).isEmpty)
    }

    @Test func ignoresKnownValues() {
        var tracker = ChargeReasonTracker()
        let s = PowerSnapshot(isExternalConnected: true, notChargingReason: 0x100_0000, slowChargingReason: 0)
        #expect(tracker.newSightings(in: s, at: t0).isEmpty)
    }

    @Test func tracksSlowChargingToo() {
        var tracker = ChargeReasonTracker()
        let s = PowerSnapshot(isExternalConnected: true, slowChargingReason: 2)
        #expect(tracker.newSightings(in: s, at: t0).map(\.key) == ["SlowChargingReason"])
    }
}

struct ChargeReasonPersistenceTests {
    let t0 = Date(timeIntervalSince1970: 1_791_000_000)

    @Test func noExternalPowerIsKnown() {
        var tracker = ChargeReasonTracker()
        let s = PowerSnapshot(isExternalConnected: false, batteryW: -13.9, notChargingReason: 0x80)
        #expect(tracker.newSightings(in: s, at: t0).isEmpty)
    }

    /// Seen live: the same value was logged again after a relaunch.
    @Test func valuesAlreadyInTheLogAreNotRepeated() {
        var tracker = ChargeReasonTracker(alreadyLogged: ["NotChargingReason=4"])
        let s = PowerSnapshot(isExternalConnected: true, notChargingReason: 0x4)
        #expect(tracker.newSightings(in: s, at: t0).isEmpty)
    }

    @Test func logLinesBecomeKeys() {
        let lines = """
        {"key":"NotChargingReason","value":128,"date":"2026-10-03T05:05:52Z","connected":false}
        {"key":"SlowChargingReason","value":2,"date":"2026-10-03T05:06:00Z","connected":true}
        not json
        """
        #expect(ChargeReasonLog.keys(fromJSONLines: lines) == ["NotChargingReason=128", "SlowChargingReason=2"])
    }
}
