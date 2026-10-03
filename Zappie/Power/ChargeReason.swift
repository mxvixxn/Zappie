import Foundation

enum ChargeReason {
    /// `NotChargingReason` while held at the macOS charge limit (seen at 80%, 2026-10-02).
    static let chargeLimit = 0x100_0000

    /// Values whose meaning is known; anything else gets logged for later naming.
    static let known: [String: Set<Int>] = [
        "NotChargingReason": [0, chargeLimit],
        "SlowChargingReason": [0],
    ]
}

/// One first sighting of an unexplained charger reason, with the context needed to name it.
struct ChargeReasonSighting: Codable, Equatable, Sendable {
    var key: String
    var value: Int
    var date: Date
    var percent: Int?
    var batteryW: Double?
    var adapterInW: Double?
    var connected: Bool
}

/// Reports each unknown reason value once per app run.
struct ChargeReasonTracker {
    private var seen: Set<String> = []

    mutating func newSightings(in s: PowerSnapshot, at date: Date) -> [ChargeReasonSighting] {
        let values = [("NotChargingReason", s.notChargingReason), ("SlowChargingReason", s.slowChargingReason)]
        return values.compactMap { key, value in
            guard let value, !(ChargeReason.known[key]?.contains(value) ?? false),
                  seen.insert("\(key)=\(value)").inserted else { return nil }
            return ChargeReasonSighting(key: key, value: value, date: date, percent: s.percent, batteryW: s.batteryW,
                                        adapterInW: s.adapterInW, connected: s.isExternalConnected)
        }
    }
}

/// Appends sightings as JSON lines to ~/Library/Application Support/Zappie/charge-reasons.jsonl.
enum ChargeReasonLog {
    static var url: URL {
        URL.applicationSupportDirectory.appending(path: "Zappie/charge-reasons.jsonl")
    }

    static func append(_ sighting: ChargeReasonSighting) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard var line = try? encoder.encode(sighting) else { return }
        line.append(0x0A)
        let fm = FileManager.default
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: line)
        } else {
            try? line.write(to: url)
        }
    }
}
