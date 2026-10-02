import Foundation
import Testing
@testable import Zappie

/// Scripted reader and clock so the monitor can be stepped deterministically.
@MainActor
private final class Rig {
    var reading: PowerSnapshot?
    var now = Date(timeIntervalSince1970: 1_790_950_000)
    lazy var monitor = PowerMonitor(read: { [unowned self] in reading }, now: { [unowned self] in now })

    func step(_ seconds: TimeInterval, _ reading: PowerSnapshot?) {
        now += seconds
        self.reading = reading
        monitor.refresh()
    }
}

@MainActor
struct PowerMonitorTests {
    @Test func publishesSnapshotAndState() {
        let rig = Rig()
        let s = PowerSnapshot(isExternalConnected: true, adapterInW: 40, batteryW: 25)
        rig.step(0, s)
        #expect(rig.monitor.snapshot == s)
        #expect(rig.monitor.state == .charging)
        #expect(rig.monitor.isSupported)
    }

    @Test func unsupportedWhenReaderReturnsNil() {
        let rig = Rig()
        rig.step(0, nil)
        #expect(!rig.monitor.isSupported)
        #expect(rig.monitor.state == nil)
    }

    @Test func unplugSwitchesToBatteryOnNextRefresh() {
        let rig = Rig()
        rig.step(0, PowerSnapshot(isExternalConnected: true, batteryW: 0))
        rig.step(1, PowerSnapshot(isExternalConnected: false, batteryW: 0))
        #expect(rig.monitor.state == .battery)
    }

    /// After replug the driver keeps publishing discharge watts until its next refresh.
    @Test func replugIgnoresStaleDischargeTelemetry() {
        let rig = Rig()
        let lastUpdate = rig.now
        rig.step(0, PowerSnapshot(isExternalConnected: false, batteryW: -16.8, updateTime: lastUpdate))
        rig.step(1, PowerSnapshot(isExternalConnected: true, batteryW: -16.8, updateTime: lastUpdate))
        #expect(rig.monitor.state == .hold)

        rig.step(1, PowerSnapshot(isExternalConnected: true, batteryW: 30, updateTime: rig.now))
        rig.step(2, PowerSnapshot(isExternalConnected: true, batteryW: 30, updateTime: rig.now))
        #expect(rig.monitor.state == .charging)
    }

    @Test func holdToChargingWaitsForHysteresis() {
        let rig = Rig()
        rig.step(0, PowerSnapshot(isExternalConnected: true, batteryW: 0))
        rig.step(1, PowerSnapshot(isExternalConnected: true, batteryW: 20))
        #expect(rig.monitor.state == .hold)
        rig.step(2, PowerSnapshot(isExternalConnected: true, batteryW: 20))
        #expect(rig.monitor.state == .charging)
    }
}
