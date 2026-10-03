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
        /// Something is plugged in (charging, or a data device still waiting for its watts).
        var connected: Bool = false
        /// Power is flowing to it.
        var active: Bool
        var watts: String
        var detail: String
        var icon: DeviceIcon = .generic
        /// The charger is plugged into this port.
        var isInput = false
    }

    var adapterActive: Bool
    var adapterTitle: String
    var adapterText: String
    var batteryLink: BatteryLink
    var batteryText: String
    var batteryPercent: String
    var systemText: String
    /// "Mac 본체 12.2 W" when some of the system load goes out over USB.
    var macText: String?
    var usbActive: Bool
    var ports: [Port]
    var anyPortConnected: Bool { ports.contains { $0.connected && !$0.isInput } }

    /// A data device seen this recently without watts is still waiting for the battery driver's
    /// refresh; after that it is simply not drawing power.
    static let pendingWindow: TimeInterval = 75

    /// - Parameter connectedSince: When each port's USB device first appeared (`PowerMonitor`).
    init(snapshot s: PowerSnapshot, state: PowerState, connectedSince: [Int: Date] = [:], now: Date = .now) {
        adapterActive = state != .battery
        adapterText = adapterActive ? Format.watts(s.adapterInW) : "—"
        adapterTitle = s.powerInput.map { "어댑터 · \($0.portName)" } ?? "어댑터"
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
        macText = !s.telemetryValid ? "갱신 대기 중"
            : usbActive ? s.systemLoadW.map { "Mac 본체 \(Format.watts(max($0 - usb, 0)))" } : nil

        let outputs = Dictionary(s.portOutputs.map { ($0.port, $0) }, uniquingKeysWith: { a, _ in a })
        let indices = Set(PortName.known.keys).union(outputs.keys).union(s.usbDevices.keys).sorted()
        let inputPort: Int? = if case let .usbC(n)? = s.powerInput?.port { n } else { nil }
        ports = indices.map { index in
            let name = PortName.name(for: index)
            if index == inputPort, let input = s.powerInput {
                let limit = input.negotiatedW.map { " · 최대 \(Format.wholeWatts($0))" } ?? ""
                return Port(name: name, connected: true, active: false, watts: Format.watts(s.adapterInW),
                            detail: "전원 입력\(limit)", icon: .charger, isInput: true)
            }
            if let out = outputs[index], out.watts > 0 {
                return Port(name: name, connected: true, active: true, watts: Format.watts(out.watts),
                            detail: PortOutput.describeDevice(out) ?? "충전 중", icon: DeviceIcon(out))
            }
            if let device = s.usbDevices[index] {
                let waiting = connectedSince[index].map { now.timeIntervalSince($0) < Self.pendingWindow } ?? true
                return Port(name: name, connected: true, active: false, watts: "—",
                            detail: "\(device) · \(waiting ? "전력 확인 중" : "충전 안 함")",
                            icon: DeviceIcon(PortOutput(port: index, watts: 0, deviceName: device)))
            }
            return Port(name: name, active: false, watts: "—", detail: "출력 없음")
        }
    }
}

/// Icon for what is plugged into a port. The name comes from USB (data-connected devices only),
/// so AirPods cases usually show up as an unnamed Apple device.
enum DeviceIcon: Equatable {
    case iphone, ipad, airpods, watch, macbook, desktopMac, apple, charger, generic

    init(_ p: PortOutput) {
        let name = p.deviceName?.lowercased() ?? ""
        if name.contains("iphone") { self = .iphone }
        else if name.contains("ipad") { self = .ipad }
        else if name.contains("airpods") { self = .airpods }
        else if name.contains("watch") { self = .watch }
        else if name.contains("macbook") { self = .macbook }
        else if name.contains("imac") || name.hasPrefix("mac ") { self = .desktopMac }
        else if p.deviceIsApple { self = .apple }
        else { self = .generic }
    }

    var symbol: String {
        switch self {
        case .iphone: "iphone"
        case .ipad: "ipad"
        case .airpods: "airpods"
        case .watch: "applewatch"
        case .macbook: "laptopcomputer"
        case .desktopMac: "desktopcomputer"
        case .apple: "apple.logo"
        case .charger: "powerplug"
        case .generic: "cable.connector"
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
