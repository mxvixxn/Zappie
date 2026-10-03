import Foundation
import Testing
@testable import Zappie

/// Main window flow: sources on top (adapter, battery), system in the middle,
/// every USB-C port in parallel at the bottom.
struct PowerTreeTests {
    func tree(_ state: PowerState, _ s: PowerSnapshot) -> PowerTree {
        PowerTree(snapshot: s, state: state)
    }

    @Test func chargingSendsPowerUpToBattery() {
        let t = tree(.charging, PowerSnapshot(isExternalConnected: true, adapterInW: 45.2, systemLoadW: 12.3,
                                              batteryW: 31.4, percent: 62))
        #expect(t.adapterActive)
        #expect(t.adapterText == "45.2 W")
        #expect(t.batteryLink == .charging)
        #expect(t.batteryText == "+31.4 W")
        #expect(t.batteryPercent == "62%")
        #expect(t.systemText == "12.3 W")
    }

    @Test func batteryModeDimsAdapterAndDischarges() {
        let t = tree(.battery, PowerSnapshot(isExternalConnected: false, adapterInW: 0, systemLoadW: 11.8,
                                             batteryW: -11.8, percent: 80))
        #expect(!t.adapterActive)
        #expect(t.adapterText == "—")
        #expect(t.batteryLink == .discharging)
    }

    @Test func holdAndAssisted() {
        let hold = PowerSnapshot(isExternalConnected: true, adapterInW: 12, systemLoadW: 12, batteryW: 0)
        #expect(tree(.hold, hold).batteryLink == .idle)
        let assisted = PowerSnapshot(isExternalConnected: true, adapterInW: 30, systemLoadW: 38, batteryW: -8)
        #expect(tree(.assisted, assisted).batteryLink == .discharging)
    }

    @Test func allThreePortsAlwaysShown() {
        let s = PowerSnapshot(isExternalConnected: true, adapterInW: 19.5, systemLoadW: 19.5, batteryW: 0,
                              portOutputs: [PortOutput(port: 2, watts: 9.0, deviceName: "iPhone",
                                                       deviceBatteryPercent: 88, deviceIsApple: true)])
        let ports = tree(.hold, s).ports
        #expect(ports.map(\.name) == ["왼쪽 뒤", "왼쪽 앞", "오른쪽"])
        #expect(ports.map(\.active) == [false, true, false])
        #expect(ports.map(\.watts) == ["—", "9.0 W", "—"])
        #expect(ports.map(\.detail) == ["출력 없음", "iPhone · 88%", "출력 없음"])
    }

    @Test func activePortWithoutDeviceInfoSaysCharging() {
        let s = PowerSnapshot(isExternalConnected: true, adapterInW: 20, systemLoadW: 20, batteryW: 0,
                              portOutputs: [PortOutput(port: 3, watts: 4.4)])
        #expect(tree(.hold, s).ports[2].detail == "충전 중")
    }

    @Test func unknownPortIsAppended() {
        let s = PowerSnapshot(isExternalConnected: true, adapterInW: 20, systemLoadW: 20, batteryW: 0,
                              portOutputs: [PortOutput(port: 4, watts: 2)])
        #expect(tree(.hold, s).ports.map(\.name) == ["왼쪽 뒤", "왼쪽 앞", "오른쪽", "포트 4"])
    }

    @Test func macShareShownOnlyWithUSBOutput() {
        let idle = PowerSnapshot(isExternalConnected: true, adapterInW: 12, systemLoadW: 12, batteryW: 0)
        #expect(tree(.hold, idle).macText == nil)

        let hub = PowerSnapshot(isExternalConnected: true, adapterInW: 19.5, systemLoadW: 19.5, batteryW: 0,
                                portOutputs: [PortOutput(port: 2, watts: 7.3)])
        #expect(tree(.hold, hub).macText == "Mac 본체 12.2 W")
        #expect(tree(.hold, hub).usbActive)
    }
}
