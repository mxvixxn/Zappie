import Foundation

/// Where the charger is plugged in. From `IOPortFeaturePowerSource` nodes: the source in use has
/// "[*]" in its registry name, and its `Description` starts with the port, e.g.
/// "Port-USB-C@3/Power In/USB-PD" or "Port-MagSafe 3@1/Power In/USB-PD".
struct PowerInput: Equatable, Sendable {
    enum Port: Equatable, Sendable {
        case magSafe
        /// `Port-USB-C@N`, same N as `PowerOutDetails.PortIndex` (verified on all three ports).
        case usbC(Int)
    }

    var port: Port
    /// "USB-PD", or "TypeC" for the ~2 s before PD negotiation finishes.
    var source: String
    /// Negotiated maximum, from `WinningPowerSourceOption`.
    var negotiatedW: Double?

    func portName(in layout: PortLayout) -> String {
        switch port {
        case .magSafe: "MagSafe"
        case let .usbC(n): layout.name(for: n)
        }
    }
}
