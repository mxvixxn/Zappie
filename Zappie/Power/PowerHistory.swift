import Foundation

struct PowerSample: Sendable, Equatable, Codable {
    var date: Date
    var inputW: Double
    var systemW: Double
    var usbW: Double = 0
}

/// SPEC §3: 1 hour at 1 s, 6 hours at 10 s averages, 24 hours at 60 s averages.
/// Saved to disk by `HistoryStore` and restored at launch.
enum HistoryRange: String, CaseIterable, Identifiable, Sendable {
    case hour = "1시간"
    case sixHours = "6시간"
    case day = "24시간"

    var id: Self { self }

    var resolution: TimeInterval {
        switch self {
        case .hour: 1
        case .sixHours: 10
        case .day: 60
        }
    }

    var duration: TimeInterval {
        switch self {
        case .hour: 3_600
        case .sixHours: 21_600
        case .day: 86_400
        }
    }

    var capacity: Int { Int(duration / resolution) }
}

struct PowerHistory: Sendable {
    private var tiers: [HistoryRange: Tier] = Dictionary(
        uniqueKeysWithValues: HistoryRange.allCases.map { ($0, Tier(range: $0)) }
    )

    init() {}

    /// Keeps only samples inside each range ending `now`; anything later (the clock moved back)
    /// is dropped so it can't sit after new samples.
    init(restoring archive: HistoryArchive, now: Date) {
        for range in HistoryRange.allCases {
            let start = now.addingTimeInterval(-range.duration)
            let kept = archive[range].filter { $0.date >= start && $0.date <= now }
            tiers[range] = Tier(range: range, restoring: kept)
        }
    }

    var archive: HistoryArchive {
        HistoryArchive(hour: samples(.hour), sixHours: samples(.sixHours), day: samples(.day))
    }

    /// Adapter input is recorded as 0 while on battery, so the chart shows the drop.
    mutating func record(_ snapshot: PowerSnapshot, at date: Date) {
        guard snapshot.telemetryValid else { return }
        let sample = PowerSample(
            date: date,
            inputW: snapshot.isExternalConnected ? snapshot.adapterInW ?? 0 : 0,
            systemW: snapshot.systemLoadW ?? 0,
            usbW: snapshot.usbOutW
        )
        for range in HistoryRange.allCases {
            tiers[range]?.add(sample)
        }
    }

    func samples(_ range: HistoryRange) -> [PowerSample] {
        tiers[range]?.ring.elements ?? []
    }

    private struct Tier: Sendable {
        var averager: BucketAverager
        var ring: RingBuffer<PowerSample>

        init(range: HistoryRange, restoring samples: [PowerSample] = []) {
            averager = BucketAverager(interval: range.resolution)
            ring = RingBuffer(capacity: range.capacity, elements: samples)
        }

        mutating func add(_ sample: PowerSample) {
            if let closed = averager.add(sample) {
                ring.append(closed)
            }
        }
    }
}

/// Averages samples into wall-clock-aligned buckets; a bucket is emitted when a later one starts.
struct BucketAverager: Sendable {
    let interval: TimeInterval
    private var bucketStart: Date?
    private var count = 0
    private var inputSum = 0.0
    private var systemSum = 0.0
    private var usbSum = 0.0

    init(interval: TimeInterval) {
        self.interval = interval
    }

    mutating func add(_ sample: PowerSample) -> PowerSample? {
        let start = Date(timeIntervalSince1970: (sample.date.timeIntervalSince1970 / interval).rounded(.down) * interval)
        var closed: PowerSample?
        if let bucketStart, start != bucketStart, count > 0 {
            let n = Double(count)
            closed = PowerSample(date: bucketStart, inputW: inputSum / n, systemW: systemSum / n, usbW: usbSum / n)
            count = 0
            inputSum = 0
            systemSum = 0
            usbSum = 0
        }
        bucketStart = start
        count += 1
        inputSum += sample.inputW
        systemSum += sample.systemW
        usbSum += sample.usbW
        return closed
    }
}

struct RingBuffer<Element: Sendable>: Sendable {
    let capacity: Int
    private var storage: [Element] = []
    private var head = 0

    init(capacity: Int, elements: [Element] = []) {
        self.capacity = capacity
        storage.reserveCapacity(capacity)
        storage.append(contentsOf: elements.suffix(capacity))
    }

    mutating func append(_ element: Element) {
        if storage.count < capacity {
            storage.append(element)
        } else {
            storage[head] = element
            head = (head + 1) % capacity
        }
    }

    /// Oldest first.
    var elements: [Element] {
        Array(storage[head...] + storage[..<head])
    }
}

extension HistoryRange {
    /// Start, middle, and end of the x axis.
    var axisLabels: [String] {
        switch self {
        case .hour: ["60분 전", "30분 전", "지금"]
        case .sixHours: ["6시간 전", "3시간 전", "지금"]
        case .day: ["24시간 전", "12시간 전", "지금"]
        }
    }

    /// Next multiple of 20 W strictly above the highest value, so lines never touch the top.
    static func yAxisMax(for samples: [PowerSample]) -> Double {
        let peak = samples.map { max($0.inputW, $0.systemW) }.max() ?? 0
        return ((peak / 20).rounded(.down) + 1) * 20
    }
}

extension HistoryRange {
    /// Averages consecutive samples so the chart draws at most `limit` points.
    /// Stored history keeps full resolution; this is only for drawing.
    static func forChart(_ samples: [PowerSample], limit: Int = chartPointLimit) -> [PowerSample] {
        guard samples.count > limit, limit > 0 else { return samples }
        let chunk = (samples.count + limit - 1) / limit
        return stride(from: 0, to: samples.count, by: chunk).map { start in
            let slice = samples[start..<min(start + chunk, samples.count)]
            let n = Double(slice.count)
            return PowerSample(date: slice.first!.date,
                               inputW: slice.reduce(0) { $0 + $1.inputW } / n,
                               systemW: slice.reduce(0) { $0 + $1.systemW } / n,
                               usbW: slice.reduce(0) { $0 + $1.usbW } / n)
        }
    }
}

/// What `HistoryStore` writes: each range's samples, oldest first. The averaging bucket still
/// open when saving (under a minute) is not kept.
struct HistoryArchive: Codable, Equatable, Sendable {
    var hour: [PowerSample]
    var sixHours: [PowerSample]
    var day: [PowerSample]

    subscript(range: HistoryRange) -> [PowerSample] {
        switch range {
        case .hour: hour
        case .sixHours: sixHours
        case .day: day
        }
    }
}

/// ~/Library/Application Support/Zappie/history.plist (binary, about 300 KB when full).
enum HistoryStore {
    static var url: URL {
        URL.applicationSupportDirectory.appending(path: "Zappie/history.plist")
    }

    static func load(from url: URL = url) -> HistoryArchive? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? PropertyListDecoder().decode(HistoryArchive.self, from: data)
    }

    static func save(_ archive: HistoryArchive, to url: URL = url) throws {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let data = try encoder.encode(archive)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}

/// A sample tagged with its unbroken stretch, so the chart draws each stretch as its own line.
struct ChartPoint: Equatable {
    var sample: PowerSample
    var segment: Int
}

extension HistoryRange {
    /// The chart is ~1000 pt wide; more points than this add nothing visible.
    static let chartPointLimit = 360

    /// Seconds one drawn point covers.
    var chartStep: TimeInterval { duration / Double(Self.chartPointLimit) }

    /// Changes once per `chartStep`: the chart only needs redrawing when a new point appears.
    func chartTick(_ now: Date) -> Date {
        Date(timeIntervalSince1970: (now.timeIntervalSince1970 / chartStep).rounded(.down) * chartStep)
    }

    /// A longer pause between samples is a gap (sleep, app not running, no readings). Generous
    /// enough for the slowest poll interval (5 s).
    var gapThreshold: TimeInterval { max(30, resolution * 5) }

    func segments(_ samples: [PowerSample]) -> [[PowerSample]] {
        var result: [[PowerSample]] = []
        var current: [PowerSample] = []
        for sample in samples {
            if let last = current.last, sample.date.timeIntervalSince(last.date) > gapThreshold {
                result.append(current)
                current = []
            }
            current.append(sample)
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    /// Segments, each downsampled on its own (never averaged across a gap), sharing `limit`
    /// points in proportion to their length.
    func chartPoints(_ samples: [PowerSample], limit: Int = Self.chartPointLimit) -> [ChartPoint] {
        let total = samples.count
        return segments(samples).enumerated().flatMap { index, segment in
            let share = max(1, limit * segment.count / max(total, 1))
            return Self.forChart(segment, limit: share).map { ChartPoint(sample: $0, segment: index) }
        }
    }
}
