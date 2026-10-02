import Foundation

struct DetailRow: Equatable {
    var label: String
    var value: String
}

extension Format {
    static func milliampHours(_ value: Int?) -> String {
        value.map { "\($0.formatted(.number.locale(Locale(identifier: "ko_KR")))) mAh" } ?? "—"
    }

    /// Full-charge capacity as a share of design capacity.
    static func capacityHealth(_ s: PowerSnapshot) -> String {
        guard let full = s.fullChargeCapacitymAh, let design = s.designCapacitymAh, design > 0 else { return "—" }
        return percent(Double(full) / Double(design))
    }
}

/// Key/value lists for the 어댑터 and 배터리 tabs.
enum DetailRows {
    static func adapter(_ s: PowerSnapshot) -> [DetailRow] {
        guard let a = s.adapter else { return [] }
        return [
            DetailRow(label: "이름", value: a.name ?? "—"),
            DetailRow(label: "제조사", value: a.manufacturer ?? "—"),
            DetailRow(label: "정격", value: "\(a.watts) W"),
            DetailRow(label: "협상 전압", value: a.voltageV.map { String(format: "%.1f V", $0) } ?? "—"),
            DetailRow(label: "협상 전류", value: a.currentA.map { String(format: "%.2f A", $0) } ?? "—"),
            DetailRow(label: "프로토콜", value: a.protocolDescription ?? "—"),
            DetailRow(label: "현재 입력", value: Format.watts(s.adapterInW)),
            DetailRow(label: "어댑터 손실", value: Format.watts(s.adapterLossW)),
        ]
    }

    static func battery(_ s: PowerSnapshot, state: PowerState) -> [DetailRow] {
        let time: DetailRow = state == .charging
            ? DetailRow(label: "충전 완료까지", value: Format.duration(minutes: s.timeToFullMin))
            : DetailRow(label: "남은 사용 시간", value: Format.duration(minutes: s.timeToEmptyMin))
        return [
            DetailRow(label: "잔량", value: s.percent.map { "\($0)%" } ?? "—"),
            DetailRow(label: "설계 용량", value: Format.milliampHours(s.designCapacitymAh)),
            DetailRow(label: "최대 충전 용량", value: Format.milliampHours(s.fullChargeCapacitymAh)),
            DetailRow(label: "최대 용량", value: Format.capacityHealth(s)),
            DetailRow(label: "배터리 전력", value: Format.signedWatts(s.batteryW)),
            time,
        ]
    }
}

/// Average and peak of the visible history range, for the 기록 tab.
struct HistorySummary: Equatable {
    var items: [DetailRow]

    init?(_ samples: [PowerSample]) {
        guard !samples.isEmpty else { return nil }
        let n = Double(samples.count)
        let inputs = samples.map(\.inputW), systems = samples.map(\.systemW)
        items = [
            DetailRow(label: "평균 입력", value: Format.watts(inputs.reduce(0, +) / n)),
            DetailRow(label: "최대 입력", value: Format.watts(inputs.max())),
            DetailRow(label: "평균 시스템", value: Format.watts(systems.reduce(0, +) / n)),
            DetailRow(label: "최대 시스템", value: Format.watts(systems.max())),
        ]
    }
}
