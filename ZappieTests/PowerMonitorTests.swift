import Foundation
import Testing
@testable import Zappie

/// Scripted reader and clock so the monitor can be stepped deterministically.
@MainActor
private final class Rig {
    var reading: PowerSnapshot?
    var now = Date(timeIntervalSince1970: 1_790_950_000)
    var logged: [ChargeReasonSighting] = []
    lazy var monitor = PowerMonitor(read: { [unowned self] in reading }, now: { [unowned self] in now },
                                    logReason: { [unowned self] in logged.append($0) })

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

    @Test func refreshRecordsHistory() {
        let rig = Rig()
        rig.step(0, PowerSnapshot(isExternalConnected: true, adapterInW: 20, systemLoadW: 8))
        rig.step(1, PowerSnapshot(isExternalConnected: true, adapterInW: 20, systemLoadW: 8))
        #expect(rig.monitor.history.samples(.hour).map(\.inputW) == [20])
    }

    @Test func tracksWhenUSBDevicesWereConnected() {
        let rig = Rig()
        let start = rig.now
        rig.step(0, PowerSnapshot(isExternalConnected: true, usbDevices: [2: "iPhone"]))
        rig.step(3, PowerSnapshot(isExternalConnected: true, usbDevices: [2: "iPhone"]))
        #expect(rig.monitor.usbConnectedSince == [2: start])

        rig.step(1, PowerSnapshot(isExternalConnected: true))
        #expect(rig.monitor.usbConnectedSince.isEmpty)
    }

    @Test func logsUnknownChargeReasons() {
        let rig = Rig()
        rig.step(0, PowerSnapshot(isExternalConnected: true, batteryW: 0, notChargingReason: 0x4))
        rig.step(1, PowerSnapshot(isExternalConnected: true, batteryW: 0, notChargingReason: 0x4))
        #expect(rig.logged.map(\.value) == [0x4])
    }

    /// Redrawing the menu bar every second (live SMC watts) cost ~2% CPU. Small wobbles are
    /// batched; real changes still show at once.
    @Test func menuBarIgnoresSmallWobbleForFiveSeconds() {
        let rig = Rig()
        rig.step(0, PowerSnapshot(isExternalConnected: true, adapterInW: 22.2, systemLoadW: 22, batteryW: 0))
        #expect(rig.monitor.menuBarItem?.text == "22.2W")
        rig.step(1, PowerSnapshot(isExternalConnected: true, adapterInW: 22.4, systemLoadW: 22, batteryW: 0))
        #expect(rig.monitor.menuBarItem?.text == "22.2W")
        rig.step(4, PowerSnapshot(isExternalConnected: true, adapterInW: 22.4, systemLoadW: 22, batteryW: 0))
        #expect(rig.monitor.menuBarItem?.text == "22.4W")
    }

    @Test func menuBarShowsBigChangesAtOnce() {
        let rig = Rig()
        rig.step(0, PowerSnapshot(isExternalConnected: true, adapterInW: 22.2, systemLoadW: 22, batteryW: 0))
        rig.step(1, PowerSnapshot(isExternalConnected: true, adapterInW: 30.0, systemLoadW: 30, batteryW: 0))
        #expect(rig.monitor.menuBarItem?.text == "30.0W")
    }

    @Test func menuBarFollowsStateChangesAtOnce() {
        let rig = Rig()
        rig.step(0, PowerSnapshot(isExternalConnected: true, adapterInW: 22.2, systemLoadW: 22, batteryW: 0))
        rig.step(1, PowerSnapshot(isExternalConnected: false, adapterInW: 0, systemLoadW: 22.3, batteryW: -22.3))
        #expect(rig.monitor.menuBarItem?.icon == .battery)
        #expect(rig.monitor.menuBarItem?.text == "−22.3W")
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
