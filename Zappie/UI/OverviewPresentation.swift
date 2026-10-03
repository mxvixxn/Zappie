import Foundation

extension Format {
    static func updatedAgo(_ date: Date?, now: Date) -> String {
        guard let date else { return "" }
        let seconds = Int(now.timeIntervalSince(date))
        switch seconds {
        case ..<2: return "방금 갱신"
        case ..<60: return "\(seconds)초 전 갱신"
        default: return "\(seconds / 60)분 전 갱신"
        }
    }

    static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }
}

/// Main window "개요" cards, derived from one snapshot.
struct OverviewPresentation: Equatable {
    struct Composition: Equatable {
        struct Row: Equatable {
            var label: String
            var tint: Tint?
            var fraction: Double
            var valueText: String
        }
        var totalText: String
        var rows: [Row]
    }

    struct Adapter: Equatable {
        var ratedText: String
        var subtitle: String
        var usageFraction: Double
        var usageText: String
        var negotiatedText: String
        var lossText: String
    }

    struct Port: Equatable {
        var name: String
        var watts: String
        var detail: String
    }

    struct Tile: Equatable {
        var label: String
        var value: String
    }

    var composition: Composition?
    var adapter: Adapter?
    var batteryTiles: [Tile]
    var batteryCaption: String
    var ports: [Port]

    init(snapshot s: PowerSnapshot, state: PowerState) {
        let connected = state != .battery
        composition = connected ? Self.composition(s) : nil
        adapter = connected ? s.adapter.map { Self.adapter($0, inputW: s.adapterInW, lossW: s.adapterLossW) } : nil
        batteryTiles = Self.tiles(s)
        ports = s.portOutputs.map { p in
            let detail: String = if let v = p.voltageV, let i = p.currentA {
                String(format: "%.2f V × %.2f A", v, i)
            } else {
                "—"
            }
            return Port(name: PortName.name(for: p.port), watts: Format.watts(p.watts), detail: detail)
        }

        let w = Format.signedWatts(s.batteryW)
        batteryCaption = switch state {
        case .charging: "\(w) 충전"
        case .battery, .assisted: "\(w) 방전"
        case .hold: w
        }
    }

    /// Input = system + battery charge + other. Other is the remainder, clamped at zero.
    /// USB output is part of system load, so when present system splits into Mac + USB.
    private static func composition(_ s: PowerSnapshot) -> Composition? {
        guard let input = s.adapterInW, let system = s.systemLoadW else { return nil }
        let charge = max(s.batteryW ?? 0, 0)
        let other = max(input - system - charge, 0)
        let usb = s.usbOutW
        let denominator = max(input, system + charge + other)

        func row(_ label: String, _ tint: Tint?, _ w: Double) -> Composition.Row {
            let fraction = denominator > 0 ? w / denominator : 0
            return .init(label: label, tint: tint, fraction: fraction,
                         valueText: "\(Format.watts(w)) · \(Format.percent(fraction))")
        }
        let systemRows = usb > 0
            ? [row("Mac 본체", .adapter, max(system - usb, 0)), row("USB 기기 출력", .usb, usb)]
            : [row("시스템 소비", .adapter, system)]
        return Composition(
            totalText: Format.watts(input),
            rows: systemRows + [
                row("배터리 충전", .battery, charge),
                row("기타·손실 (계산값)", nil, other),
            ]
        )
    }

    private static func adapter(_ a: AdapterInfo, inputW: Double?, lossW: Double?) -> Adapter {
        let usage = min(max((inputW ?? 0) / Double(a.watts), 0), 1)
        let negotiated: String = if let v = a.voltageV, let i = a.currentA {
            String(format: "%.1f V × %.2f A", v, i)
        } else {
            "—"
        }
        return Adapter(
            ratedText: "\(a.watts) W",
            subtitle: a.name ?? a.protocolDescription ?? "",
            usageFraction: usage,
            usageText: Format.percent(usage),
            negotiatedText: negotiated,
            lossText: Format.watts(lossW)
        )
    }

    private static func tiles(_ s: PowerSnapshot) -> [Tile] {
        let current: String = s.batteryCurrentA.map { a in
            if abs(a) < 0.005 { return "0.00 A" }
            return (a > 0 ? "+" : "−") + String(format: "%.2f A", abs(a))
        } ?? "—"
        return [
            Tile(label: "전압", value: s.batteryVoltageV.map { String(format: "%.2f V", $0) } ?? "—"),
            Tile(label: "전류", value: current),
            Tile(label: "온도", value: s.temperatureC.map { String(format: "%.1f °C", $0) } ?? "—"),
            Tile(label: "사이클", value: s.cycleCount.map(String.init) ?? "—"),
            Tile(label: "최대 용량", value: Format.capacityHealth(s)),
            // The macOS charge limit setting is not readable through public API (SPEC §1).
            Tile(label: "충전 한도", value: "—"),
        ]
    }
}
