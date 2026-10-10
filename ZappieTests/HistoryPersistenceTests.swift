import Foundation
import Testing
@testable import Zappie

private let t0 = Date(timeIntervalSince1970: 1_790_949_960) // divisible by 60

private func connected(_ input: Double, _ system: Double) -> PowerSnapshot {
    PowerSnapshot(isExternalConnected: true, adapterInW: input, systemLoadW: system)
}

private func sample(_ offset: TimeInterval, _ w: Double = 10) -> PowerSample {
    PowerSample(date: t0 + offset, inputW: w, systemW: 5, usbW: 1)
}

struct RingBufferRestoreTests {
    @Test func keepsNewestWithinCapacity() {
        let ring = RingBuffer(capacity: 3, elements: [1, 2, 3, 4, 5])
        #expect(ring.elements == [3, 4, 5])
    }

    @Test func appendsAfterRestore() {
        var ring = RingBuffer(capacity: 3, elements: [1, 2])
        ring.append(3)
        ring.append(4)
        #expect(ring.elements == [2, 3, 4])
    }
}

/// History survives app restarts: saved every minute and before sleep or quit, restored at launch.
struct HistoryArchiveTests {
    @Test func roundTripsAllRanges() {
        var h = PowerHistory()
        for s in 0...120 { h.record(connected(Double(s), 3), at: t0 + Double(s)) }
        let restored = PowerHistory(restoring: h.archive, now: t0 + 121)
        for range in HistoryRange.allCases {
            #expect(restored.samples(range) == h.samples(range))
        }
    }

    @Test func dropsSamplesOlderThanEachRange() {
        let archive = HistoryArchive(hour: [sample(0), sample(4_000)],
                                     sixHours: [sample(0), sample(4_000)],
                                     day: [sample(0), sample(4_000)])
        let h = PowerHistory(restoring: archive, now: t0 + 4_000 + 1)
        #expect(h.samples(.hour) == [sample(4_000)])
        #expect(h.samples(.sixHours) == [sample(0), sample(4_000)])
        #expect(h.samples(.day) == [sample(0), sample(4_000)])
    }

    /// The clock moved back (manual change, time zone sync): samples "from the future" would sit
    /// after every new one and draw backwards.
    @Test func dropsSamplesFromTheFuture() {
        let archive = HistoryArchive(hour: [sample(0), sample(100)], sixHours: [], day: [])
        let h = PowerHistory(restoring: archive, now: t0 + 50)
        #expect(h.samples(.hour) == [sample(0)])
    }

    @Test func newSamplesFollowRestoredOnes() {
        let archive = HistoryArchive(hour: [sample(0), sample(1)], sixHours: [], day: [])
        var h = PowerHistory(restoring: archive, now: t0 + 600)
        h.record(connected(20, 5), at: t0 + 600)
        h.record(connected(20, 5), at: t0 + 601)
        #expect(h.samples(.hour).map(\.date) == [t0, t0 + 1, t0 + 600])
    }
}

struct HistoryStoreTests {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "ZappieHistoryStoreTests-\(UUID().uuidString)/history.plist")

    @Test func savesAndLoads() throws {
        let archive = HistoryArchive(hour: [sample(0), sample(1, 12.5)], sixHours: [sample(0)], day: [])
        try HistoryStore.save(archive, to: url)
        #expect(HistoryStore.load(from: url) == archive)
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    @Test func missingFileLoadsNothing() {
        #expect(HistoryStore.load(from: url) == nil)
    }

    @Test func corruptFileLoadsNothing() throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not a plist".utf8).write(to: url)
        #expect(HistoryStore.load(from: url) == nil)
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}

/// Lines break where samples stop (sleep, app not running, no readings) instead of drawing a
/// straight line across the gap.
struct ChartSegmentTests {
    @Test func continuousSamplesStayOneSegment() {
        let s = (0..<10).map { sample(Double($0)) }
        #expect(HistoryRange.hour.segments(s) == [s])
    }

    @Test func splitsAtGapLongerThanThreshold() {
        let before = (0..<5).map { sample(Double($0)) }
        let after = (0..<5).map { sample(600 + Double($0)) }
        #expect(HistoryRange.hour.segments(before + after) == [before, after])
    }

    @Test func toleratesSlowPolling() {
        // Poll interval set to 5 s in settings: 1 h samples arrive every 5 s.
        let s = (0..<10).map { sample(Double($0) * 5) }
        #expect(HistoryRange.hour.segments(s).count == 1)
    }

    @Test func thresholdScalesWithResolution() {
        #expect(HistoryRange.hour.gapThreshold == 30)
        #expect(HistoryRange.sixHours.gapThreshold == 50)
        #expect(HistoryRange.day.gapThreshold == 300)
    }

    @Test func emptyHasNoSegments() {
        #expect(HistoryRange.hour.segments([]).isEmpty)
    }

    /// Downsampling for drawing must not average across a gap.
    @Test func chartPointsDownsampleWithinSegments() {
        let before = (0..<3_000).map { sample(Double($0), 10) }
        let after = (0..<600).map { sample(10_000 + Double($0), 30) }
        let points = HistoryRange.hour.chartPoints(before + after, limit: 360)
        #expect(Set(points.map(\.segment)) == [0, 1])
        #expect(points.count <= 360 + 2)
        #expect(points.filter { $0.segment == 0 }.allSatisfy { $0.sample.inputW == 10 })
        #expect(points.filter { $0.segment == 1 }.allSatisfy { $0.sample.inputW == 30 })
    }
}

@MainActor
struct HistorySavingTests {
    @Test func savesAboutEveryMinute() {
        var now = t0
        var saved: [HistoryArchive] = []
        let monitor = PowerMonitor(read: { connected(20, 5) }, now: { now }, logReason: { _ in },
                                   notify: { _ in }, saveHistory: { saved.append($0) })
        for s in 0..<130 {
            now = t0 + Double(s)
            monitor.refresh()
        }
        #expect(saved.count == 2)
        #expect(saved.last?.hour.isEmpty == false)
    }

    @Test func saveNowWritesImmediately() {
        var saved = 0
        let monitor = PowerMonitor(read: { connected(20, 5) }, now: { t0 }, logReason: { _ in },
                                   notify: { _ in }, saveHistory: { _ in saved += 1 })
        monitor.refresh()
        monitor.saveHistoryNow()
        #expect(saved == 1)
    }

    @Test func startsFromRestoredHistory() {
        let archive = HistoryArchive(hour: [sample(0)], sixHours: [], day: [])
        let monitor = PowerMonitor(read: { connected(20, 5) }, now: { t0 + 10 }, logReason: { _ in },
                                   notify: { _ in }, history: PowerHistory(restoring: archive, now: t0 + 10))
        #expect(monitor.history.samples(.hour) == [sample(0)])
    }
}

/// With the main window open, rebuilding ~1,000 chart marks every second was most of its CPU.
/// A drawn point covers `chartStep` seconds, so the chart only needs redrawing once per step.
struct ChartTickTests {
    @Test func stepIsDurationOverDrawnPoints() {
        #expect(HistoryRange.hour.chartStep == 10)
        #expect(HistoryRange.sixHours.chartStep == 60)
        #expect(HistoryRange.day.chartStep == 240)
    }

    @Test func tickHoldsWithinAStep() {
        let base = Date(timeIntervalSince1970: 1_790_949_840) // divisible by 240
        #expect(HistoryRange.hour.chartTick(base + 3) == base)
        #expect(HistoryRange.hour.chartTick(base + 9.9) == base)
        #expect(HistoryRange.hour.chartTick(base + 10) == base + 10)
        #expect(HistoryRange.day.chartTick(base + 239) == base)
        #expect(HistoryRange.day.chartTick(base + 240) == base + 240)
    }
}
