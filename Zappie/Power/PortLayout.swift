import Foundation

/// This Mac's USB-C ports, from device-tree nodes (`port-usb-c-N`, `port-magsafe…`).
/// N matches `PowerOutDetails.PortIndex` and `Port-USB-C@N` (verified on Mac17,9).
/// Location names ("왼쪽 뒤") only for models mapped by hand; others get "USB-C N".
struct PortLayout: Equatable, Sendable {
    var ports: [Int]
    var hasMagSafe: Bool
    private var names: [Int: String]

    func name(for port: Int) -> String {
        names[port] ?? "USB-C \(port)"
    }

    /// Hand-verified locations: docs/m0/port-mapping.log, docs/m0/usb-c-charging.log.
    static let verifiedNames: [String: [Int: String]] = [
        "Mac17,9": [1: "왼쪽 뒤", 2: "왼쪽 앞", 3: "오른쪽"],
    ]

    static func make(model: String, deviceTreeNodes: [String]) -> PortLayout {
        let ports = deviceTreeNodes.compactMap { node -> Int? in
            guard node.hasPrefix("port-usb-c-") else { return nil }
            return Int(node.dropFirst("port-usb-c-".count))
        }.sorted()
        let verified = verifiedNames[model].flatMap { Set($0.keys) == Set(ports) ? $0 : nil }
        return PortLayout(ports: ports, hasMagSafe: deviceTreeNodes.contains { $0.hasPrefix("port-magsafe") },
                          names: verified ?? [:])
    }

    /// The MacBook Pro this app was built and verified on; the default for test snapshots.
    static let mac17_9 = make(model: "Mac17,9",
                              deviceTreeNodes: ["port-usb-c-1", "port-usb-c-2", "port-usb-c-3", "port-magsafe3-1"])
}
