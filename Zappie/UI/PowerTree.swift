import Foundation

/// Main window flow, top to bottom: sources (adapter, battery) → system → every USB-C port.
struct PowerTree: Equatable {
    enum BatteryLink: Equatable {
        /// Adapter power flows up into the battery.
        case charging
        /// Battery feeds the system.
        case discharging
        case idle
    }

    struct Port: Equatable {
        var name: String
        var active: Bool
        var watts: String
        var detail: String
    }

    var adapterActive: Bool
    var adapterText: String
    var batteryLink: BatteryLink
    var batteryText: String
    var batteryPercent: String
    var systemText: String
    /// "Mac 본체 12.2 W" when some of the system load goes out over USB.
    var macText: String?
    var usbActive: Bool
    var ports: [Port]

    init(snapshot s: PowerSnapshot, state: PowerState) {
        adapterActive = state != .battery
        adapterText = adapterActive ? Format.watts(s.adapterInW) : "—"
        batteryLink = switch state {
        case .charging: .charging
        case .battery, .assisted: .discharging
        case .hold: .idle
        }
        batteryText = Format.signedWatts(s.batteryW)
        batteryPercent = s.percent.map { "\($0)%" } ?? "—"
        systemText = Format.watts(s.systemLoadW)

        let usb = s.usbOutW
        usbActive = usb > 0
        macText = usbActive ? s.systemLoadW.map { "Mac 본체 \(Format.watts(max($0 - usb, 0)))" } : nil

        let outputs = Dictionary(s.portOutputs.map { ($0.port, $0) }, uniquingKeysWith: { a, _ in a })
        let indices = Set(PortName.known.keys).union(outputs.keys).sorted()
        ports = indices.map { index in
            guard let out = outputs[index], out.watts > 0 else {
                return Port(name: PortName.name(for: index), active: false, watts: "—", detail: "출력 없음")
            }
            return Port(name: PortName.name(for: index), active: true, watts: Format.watts(out.watts),
                        detail: PortOutput.describeDevice(out) ?? "충전 중")
        }
    }
}

extension PortOutput {
    /// e.g. "iPhone · 88%", "Apple 기기 · 100%"; nil when nothing is known about the device.
    static func describeDevice(_ p: PortOutput) -> String? {
        let name = p.deviceName ?? (p.deviceIsApple ? "Apple 기기" : nil)
        switch (name, p.deviceBatteryPercent) {
        case let (name?, percent?): return "\(name) · \(percent)%"
        case let (name?, nil): return name
        case let (nil, percent?): return "기기 · \(percent)%"
        case (nil, nil): return nil
        }
    }
}
