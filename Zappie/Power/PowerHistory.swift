import Foundation

struct PowerSample: Sendable, Equatable {
    var date: Date
    var inputW: Double
    var systemW: Double
    var usbW: Double = 0
}

/// SPEC §3: 1 hour at 1 s, 6 hours at 10 s averages, 24 hours at 60 s averages. Memory only (v1).
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

        init(range: HistoryRange) {
            averager = BucketAverager(interval: range.resolution)
            ring = RingBuffer(capacity: range.capacity)
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

    init(capacity: Int) {
        self.capacity = capacity
        storage.reserveCapacity(capacity)
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
    static func forChart(_ samples: [PowerSample], limit: Int = 360) -> [PowerSample] {
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
