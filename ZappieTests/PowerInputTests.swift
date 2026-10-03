import Foundation
import Testing
@testable import Zappie

/// Charging over USB-C instead of MagSafe (docs/m0/usb-c-charging.log, 2026-10-03).
/// Each powered port gets `IOPortFeaturePowerSource` children under ".../Power In"; the one
/// actually in use carries "[*]" in its registry name. "Brick ID" is a MagSafe/USB-C ID probe.
struct PowerInputParseTests {
    typealias Node = PowerReader.PowerSourceNode

    let usbCRight: [Node] = [
        .init(name: "USB-PD [*]", description: "Port-USB-C@3/Power In/USB-PD", maxPowermW: 68000),
        .init(name: "Brick ID", description: "Port-USB-C@3/Power In/Brick ID", maxPowermW: 2500),
        .init(name: "TypeC", description: "Port-USB-C@3/Power In/TypeC", maxPowermW: 15000),
    ]

    @Test func usbCPortIsTheInput() throws {
        let input = try #require(PowerReader.powerInput(from: usbCRight))
        #expect(input.port == .usbC(3))
        #expect(input.negotiatedW == 68)
        #expect(input.source == "USB-PD")
    }

    @Test func magSafeIsTheInput() throws {
        let nodes: [Node] = [
            .init(name: "USB-PD [*]", description: "Port-MagSafe 3@1/Power In/USB-PD", maxPowermW: 67800),
            .init(name: "Brick ID", description: "Port-MagSafe 3@1/Power In/Brick ID", maxPowermW: 2500),
        ]
        #expect(try #require(PowerReader.powerInput(from: nodes)).port == .magSafe)
    }

    /// For ~2 s after plugging in, plain Type-C 15 W wins until PD negotiation finishes.
    @Test func beforePDNegotiationTypeCWins() throws {
        let nodes: [Node] = [
            .init(name: "USB-PD", description: "Port-USB-C@2/Power In/USB-PD", maxPowermW: nil),
            .init(name: "TypeC [*]", description: "Port-USB-C@2/Power In/TypeC", maxPowermW: 15000),
        ]
        let input = try #require(PowerReader.powerInput(from: nodes))
        #expect(input.port == .usbC(2))
        #expect(input.negotiatedW == 15)
    }

    @Test func noChargerNoInput() {
        #expect(PowerReader.powerInput(from: []) == nil)
    }
}

struct PowerInputDisplayTests {
    func tree(_ input: PowerInput?) -> PowerTree {
        let s = PowerSnapshot(isExternalConnected: true, adapterInW: 22.2, systemLoadW: 22, batteryW: 0,
                              powerInput: input)
        return PowerTree(snapshot: s, state: .hold)
    }

    @Test func adapterNodeNamesTheInputPort() {
        #expect(tree(PowerInput(port: .magSafe, source: "USB-PD", negotiatedW: 67.8)).adapterTitle == "어댑터 · MagSafe")
        #expect(tree(PowerInput(port: .usbC(3), source: "USB-PD", negotiatedW: 68)).adapterTitle == "어댑터 · 오른쪽")
        #expect(tree(nil).adapterTitle == "어댑터")
    }

    @Test func usbCInputPortShowsPowerIn() {
        let port = tree(PowerInput(port: .usbC(3), source: "USB-PD", negotiatedW: 68)).ports[2]
        #expect(port.isInput)
        #expect(!port.active)
        #expect(port.watts == "22.2 W")
        #expect(port.detail == "전원 입력 · 최대 68 W")
    }

    @Test func otherPortsUnaffected() {
        let ports = tree(PowerInput(port: .usbC(3), source: "USB-PD", negotiatedW: 68)).ports
        #expect(!ports[0].isInput && !ports[1].isInput)
        #expect(ports[0].detail == "출력 없음")
    }

    /// The charger's port is not a device being powered, so the system → ports trunk stays idle.
    @Test func inputPortDoesNotCountAsConnectedDevice() {
        #expect(!tree(PowerInput(port: .usbC(1), source: "USB-PD", negotiatedW: 68)).anyPortConnected)
    }

    @Test func magSafeInputLeavesPortsAlone() {
        #expect(tree(PowerInput(port: .magSafe, source: "USB-PD", negotiatedW: 67.8)).ports.allSatisfy { !$0.isInput })
    }
}
