import Foundation

/// The battery driver's own watts at its last publication, kept alongside live SMC watts.
struct DriverWatts: Equatable, Sendable {
    var adapterInW: Double?
    var systemLoadW: Double?
    var batteryW: Double?
    var updateTime: Date?
    /// False when the driver's numbers were impossible (see `PowerSnapshot.hasImpossibleWatts`).
    var valid: Bool
}

/// Remembers on this Mac that live watts were turned off for disagreeing with the driver.
enum LiveWattsGuard {
    static let key = "liveWattsAutoDisabled"

    static var isDisabled: Bool { UserDefaults.standard.bool(forKey: key) }
    static func disable() { UserDefaults.standard.set(true, forKey: key) }
    static func reset() { UserDefaults.standard.removeObject(forKey: key) }
}

/// Cross-checks SMC watts against each fresh battery-driver publication. SMC key meanings were
/// verified only on Mac17,9; on other Macs a key could mean something else.
///
/// Instant readings a second apart can differ a lot under bursty load (seen on this Mac during a
/// build: driver 36.7 W vs one SMC sample 19.1 W), so a driver value matches when it falls inside
/// the range the SMC showed over the last 30 s. Live watts turn off only when at least 8 of the
/// last 10 checks miss — roughly ten minutes of consistent disagreement.
struct SMCValidator: Sendable {
    enum Verdict: Equatable { case skipped, match, mismatch, disable }

    static let window: TimeInterval = 30
    /// Only driver numbers this fresh are compared.
    static let maxAge: TimeInterval = 3
    /// Plug changes make the driver publish mixed-up numbers for a while.
    static let settleAfterPlugChange: TimeInterval = 5
    static let checksKept = 10
    static let missesToDisable = 8

    private(set) var matches = 0
    private var recent: [(date: Date, live: LivePower)] = []
    private var results: [Bool] = []
    private var lastChecked: Date?

    mutating func record(_ live: LivePower, at date: Date) {
        recent.append((date, live))
        recent.removeAll { date.timeIntervalSince($0.date) > Self.window }
    }

    mutating func check(driver: DriverWatts, now: Date, connectionChangedAt: Date? = nil) -> Verdict {
        guard driver.valid, let published = driver.updateTime, published != lastChecked,
              now.timeIntervalSince(published) <= Self.maxAge else { return .skipped }
        if let changed = connectionChangedAt, published.timeIntervalSince(changed) < Self.settleAfterPlugChange {
            return .skipped
        }
        let samples = recent.filter { published.timeIntervalSince($0.date) <= Self.window }.map(\.live)
        guard !samples.isEmpty else { return .skipped }
        lastChecked = published

        let agrees = Self.agrees(driver, samples)
        results.append(agrees)
        if results.count > Self.checksKept { results.removeFirst() }
        if agrees {
            matches += 1
            return .match
        }
        let misses = results.filter { !$0 }.count
        return results.count >= Self.checksKept && misses >= Self.missesToDisable ? .disable : .mismatch
    }

    /// Each driver value must sit within the SMC's recent min…max, with 3 W (or 15%) of slack.
    static func agrees(_ d: DriverWatts, _ samples: [LivePower]) -> Bool {
        func inside(_ value: Double, _ values: [Double]) -> Bool {
            guard let low = values.min(), let high = values.max() else { return false }
            let slack = max(3, 0.15 * abs(value))
            return value >= low - slack && value <= high + slack
        }
        if let input = d.adapterInW, !inside(input, samples.map(\.adapterInW)) { return false }
        if let system = d.systemLoadW, !inside(system, samples.map(\.systemLoadW)) { return false }
        if let battery = d.batteryW {
            let idle = abs(battery) < 1 && samples.contains { abs($0.batteryW) < 1 }
            if !idle && !inside(battery, samples.map(\.batteryW)) { return false }
        }
        return true
    }
}
