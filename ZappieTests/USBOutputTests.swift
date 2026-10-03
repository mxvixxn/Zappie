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
        #expect(rows == [.init(name: "오른쪽", watts: "5.3 W", detail: "5.19 V × 1.02 A")])
    }

    @Test func unknownPortFallsBackToNumber() {
        #expect(PortLayout.mac17_9.name(for: 9) == "USB-C 9")
    }

    @Test func historyRecordsUSBOutput() {
        var h = PowerHistory()
        let t0 = Date(timeIntervalSince1970: 1_790_949_960)
        h.record(hub, at: t0)
        h.record(hub, at: t0 + 1)
        #expect(h.samples(.hour).first?.usbW == 5.3)
    }
}

/// Port mapping verified by moving an iPhone across ports (docs/m0/port-mapping.log):
/// PortIndex − 1 = FedDetails slot = USB bus (top byte of locationID).
struct PortIdentityTests {
    @Test func physicalPortNames() {
        #expect(PortLayout.mac17_9.name(for: 1) == "왼쪽 뒤")
        #expect(PortLayout.mac17_9.name(for: 2) == "왼쪽 앞")
        #expect(PortLayout.mac17_9.name(for: 3) == "오른쪽")
    }

    @Test func usbLocationIDMapsToPort() {
        #expect(PowerReader.port(forUSBLocationID: 0x0110_0000) == 2)
        #expect(PowerReader.port(forUSBLocationID: 0x0010_0000) == 1)
    }

    @Test func connectedDeviceBatteryComesFromFedDetails() throws {
        let s = try #require(PowerReader.parse(battery: Fixtures.pluggedHold, pack: nil))
        #expect(s.portOutputs.first { $0.port == 1 }?.deviceBatteryPercent == 83)
        #expect(s.portOutputs.first { $0.port == 1 }?.deviceIsApple == true)
        #expect(s.portOutputs.first { $0.port == 3 }?.deviceBatteryPercent == nil)
    }

    @Test func usbDeviceNamesAttachToPorts() throws {
        let s = try #require(PowerReader.parse(battery: Fixtures.pluggedHold, pack: nil, usbDeviceNames: [1: "iPhone"]))
        #expect(s.portOutputs.first { $0.port == 1 }?.deviceName == "iPhone")
        #expect(s.portOutputs.first { $0.port == 3 }?.deviceName == nil)
    }

    @Test func portRowDescribesDevice() {
        let ports = [
            PortOutput(port: 2, watts: 9.0, voltageV: 9, currentA: 1, deviceName: "iPhone", deviceBatteryPercent: 83,
                       deviceIsApple: true),
            PortOutput(port: 1, watts: 2.9, deviceBatteryPercent: 100, deviceIsApple: true),
            PortOutput(port: 3, watts: 4.4),
        ]
        let s = PowerSnapshot(isExternalConnected: true, adapterInW: 30, systemLoadW: 30, batteryW: 0, portOutputs: ports)
        let rows = OverviewPresentation(snapshot: s, state: .hold).ports
        #expect(rows.map(\.device) == ["iPhone · 83%", "Apple 기기 · 100%", nil])
        #expect(rows.map(\.name) == ["왼쪽 앞", "왼쪽 뒤", "오른쪽"])
    }
}
