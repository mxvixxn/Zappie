import Foundation
import Testing
@testable import Zappie

/// Hub use: the Mac charges other devices over USB-C. That power is part of `SystemLoad`
/// (verified in docs/m0/usb-out-experiment.log), so the app splits it out of "system".
struct USBOutputTests {
    let ports = [PortOutput(port: 3, watts: 5.3, voltageV: 5.19, currentA: 1.02)]

    var hub: PowerSnapshot {
        PowerSnapshot(isExternalConnected: true, adapterInW: 17.3, systemLoadW: 17.3, batteryW: 0, portOutputs: ports)
    }

    @Test func dropdownSplitsSystemIntoMacAndUSB() {
        let p = PowerPresentation(snapshot: hub, state: .hold)
        #expect(p.systemLabel == "Mac 본체")
        #expect(p.systemText == "12.0 W")
        #expect(p.usbText == "5.3 W")
        #expect(p.flow.systemText == "17.3 W")
        #expect(p.flow.usbText == "5.3 W")
    }

    @Test func noUSBKeepsSystemLabel() {
        let s = PowerSnapshot(isExternalConnected: true, adapterInW: 12, systemLoadW: 12, batteryW: 0)
        let p = PowerPresentation(snapshot: s, state: .hold)
        #expect(p.systemLabel == "시스템")
        #expect(p.systemText == "12.0 W")
        #expect(p.usbText == nil)
        #expect(p.flow.usbText == nil)
    }

    @Test func compositionListsUSBOutput() throws {
        let c = try #require(OverviewPresentation(snapshot: hub, state: .hold).composition)
        #expect(c.rows.map(\.label) == ["Mac 본체", "USB 기기 출력", "배터리 충전", "기타·손실 (계산값)"])
        #expect(c.rows[1].valueText == "5.3 W · 31%")
        #expect(c.rows[1].tint == .usb)
    }

    @Test func compositionOmitsUSBRowWhenIdle() throws {
        let s = PowerSnapshot(isExternalConnected: true, adapterInW: 12, systemLoadW: 12, batteryW: 0)
        let c = try #require(OverviewPresentation(snapshot: s, state: .hold).composition)
        #expect(c.rows.map(\.label) == ["시스템 소비", "배터리 충전", "기타·손실 (계산값)"])
    }

    @Test func portRowsUseNames() {
        let rows = OverviewPresentation(snapshot: hub, state: .hold).ports
        #expect(rows == [.init(name: PortName.name(for: 3), watts: "5.3 W", detail: "5.19 V × 1.02 A")])
    }

    @Test func unknownPortFallsBackToNumber() {
        #expect(PortName.name(for: 9) == "포트 9")
    }

    @Test func historyRecordsUSBOutput() {
        var h = PowerHistory()
        let t0 = Date(timeIntervalSince1970: 1_790_949_960)
        h.record(hub, at: t0)
        h.record(hub, at: t0 + 1)
        #expect(h.samples(.hour).first?.usbW == 5.3)
    }
}
