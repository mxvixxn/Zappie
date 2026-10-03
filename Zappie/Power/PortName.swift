import Foundation

/// Physical location of each `PowerOutDetails.PortIndex` on this MacBook Pro (Mac17,9).
/// Mapped by moving one device across ports (docs/m0/port-mapping.log).
enum PortName {
    static let known: [Int: String] = [1: "왼쪽 뒤", 2: "왼쪽 앞", 3: "오른쪽"]

    static func name(for port: Int) -> String {
        known[port] ?? "포트 \(port)"
    }
}
