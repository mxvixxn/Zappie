import Foundation
import Testing
@testable import Zappie

/// Ports come from the device tree (`port-usb-c-N`, `port-magsafe…` nodes), so a 2-port MacBook Air
/// shows two ports. Location names only for models whose mapping was verified by hand.
struct PortLayoutTests {
    @Test func verifiedModelGetsLocationNames() {
        let l = PortLayout.make(model: "Mac17,9",
                                deviceTreeNodes: ["port-usb-c-1", "port-usb-c-2", "port-usb-c-3", "port-magsafe3-1"])
        #expect(l.ports == [1, 2, 3])
        #expect(l.hasMagSafe)
        #expect(l.name(for: 1) == "왼쪽 뒤")
        #expect(l.name(for: 2) == "왼쪽 앞")
        #expect(l.name(for: 3) == "오른쪽")
    }

    @Test func unknownTwoPortModelGetsNeutralNames() {
        let l = PortLayout.make(model: "MacBookAir10,1", deviceTreeNodes: ["port-usb-c-2", "port-usb-c-1"])
        #expect(l.ports == [1, 2])
        #expect(!l.hasMagSafe)
        #expect(l.name(for: 1) == "USB-C 1")
        #expect(l.name(for: 2) == "USB-C 2")
    }

    /// If the device tree disagrees with the verified table, do not trust the table.
    @Test func verifiedNamesNeedMatchingPorts() {
        let l = PortLayout.make(model: "Mac17,9", deviceTreeNodes: ["port-usb-c-1", "port-usb-c-2"])
        #expect(l.name(for: 1) == "USB-C 1")
    }

    @Test func portOutsideLayoutStillNamed() {
        #expect(PortLayout.mac17_9.name(for: 9) == "USB-C 9")
    }

    @Test func treeShowsOnlyThisMacsPorts() {
        let air = PortLayout.make(model: "MacBookAir10,1", deviceTreeNodes: ["port-usb-c-1", "port-usb-c-2"])
        let s = PowerSnapshot(isExternalConnected: true, adapterInW: 18.5, systemLoadW: 9.5, batteryW: 9,
                              powerInput: PowerInput(port: .usbC(1), source: "USB-PD", negotiatedW: 30),
                              portLayout: air)
        let tree = PowerTree(snapshot: s, state: .charging)
        #expect(tree.ports.map(\.name) == ["USB-C 1", "USB-C 2"])
        #expect(tree.adapterTitle == "어댑터 · USB-C 1")
        #expect(tree.ports[0].isInput)
    }
}

/// Runs on this Mac (Mac17,9): the device tree must reproduce the hand-verified layout.
struct PortLayoutLiveTests {
    static let isMac17_9: Bool = {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: max(size, 1))
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model) == "Mac17,9"
    }()

    @Test(.enabled(if: isMac17_9)) func thisMacMatchesVerifiedLayout() {
        #expect(PowerReader.thisMacPorts == PortLayout.mac17_9)
    }
}
