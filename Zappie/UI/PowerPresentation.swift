import Foundation

/// Accent roles from the design tokens; `Theme` maps them to colors.
enum Tint: Equatable {
    case adapter, battery, usb, inactive
}

enum Format {
    /// Below this, a battery reading is shown as an unsigned 0.0.
    private static let zero = 0.05

    static func watts(_ w: Double?) -> String {
        w.map { String(format: "%.1f W", $0) } ?? "—"
    }

    static func signedWatts(_ w: Double?) -> String {
        guard let w else { return "—" }
        if abs(w) < zero { return "0.0 W" }
        return (w > 0 ? "+" : "−") + String(format: "%.1f W", abs(w))
    }

    static func compactWatts(_ w: Double?) -> String {
        watts(w).replacingOccurrences(of: " ", with: "")
    }

    static func compactSignedWatts(_ w: Double?) -> String {
        signedWatts(w).replacingOccurrences(of: " ", with: "")
    }

    static func duration(minutes: Int?) -> String {
        guard let minutes else { return "계산 중" }
        let h = minutes / 60, m = minutes % 60
        switch (h, m) {
        case (0, _): return "약 \(m)분"
        case (_, 0): return "약 \(h)시간"
        default: return "약 \(h)시간 \(m)분"
        }
    }
}

/// Header, badge, detail row, and menu bar item, derived from one snapshot.
/// The flow diagram itself comes from `PowerTree`.
struct PowerPresentation: Equatable {
    struct MenuBar: Equatable {
        enum Icon: Equatable { case bolt, plug, battery }
        var icon: Icon
        var tint: Tint
        var text: String
    }

    var source: String
    var badge: String
    var badgeTint: Tint
    var percent: String
    var detailLabel: String
    var detailValue: String
    var menuBar: MenuBar

    init(snapshot s: PowerSnapshot, state: PowerState) {
        percent = s.percent.map { "\($0)%" } ?? "—"

        switch state {
        case .charging:
            source = "전원 어댑터 · 충전 중"
            badge = "충전 중"
            badgeTint = .battery
            detailLabel = "충전 완료까지"
            detailValue = Format.duration(minutes: s.timeToFullMin)
                + ((s.slowChargingReason ?? 0) != 0 ? " · 느린 충전" : "")
            menuBar = MenuBar(icon: .bolt, tint: .battery, text: Format.compactSignedWatts(s.batteryW))
        case .hold:
            source = "전원 어댑터 · 바이패스"
            badge = "바이패스"
            badgeTint = .adapter
            detailLabel = "상태"
            detailValue = Self.bypassReason(s, percent: percent)
            menuBar = MenuBar(icon: .plug, tint: .adapter, text: Format.compactWatts(s.adapterInW))
        case .battery:
            source = "배터리 사용 중"
            badge = "배터리"
            badgeTint = .battery
            detailLabel = "남은 사용 시간"
            detailValue = Format.duration(minutes: s.timeToEmptyMin)
            menuBar = MenuBar(icon: .battery, tint: .battery, text: Format.compactSignedWatts(s.batteryW))
        case .assisted:
            source = "전원 어댑터 · 배터리 보조"
            badge = "배터리 보조"
            badgeTint = .battery
            detailLabel = "남은 사용 시간"
            detailValue = Format.duration(minutes: s.timeToEmptyMin)
            menuBar = MenuBar(icon: .battery, tint: .battery, text: Format.compactSignedWatts(s.batteryW))
        }
    }

    /// Why the battery sits idle. Only the charge-limit reason is verified; other non-zero
    /// reasons are shown generically and logged by `ChargeReasonTracker`.
    private static func bypassReason(_ s: PowerSnapshot, percent: String) -> String {
        if s.notChargingReason == ChargeReason.chargeLimit { return "\(percent) 한도에서 유지 중" }
        if s.fullyCharged == true { return "완충" }
        if let reason = s.notChargingReason, reason != 0 { return "\(percent)에서 충전 일시 중지" }
        return "\(percent)에서 유지 중"
    }
}
