import Foundation
import Testing
@testable import Zappie

private let t0 = Date(timeIntervalSince1970: 1_790_949_960) // divisible by 60

private func connected(_ input: Double, _ system: Double) -> PowerSnapshot {
    PowerSnapshot(isExternalConnected: true, adapterInW: input, systemLoadW: system)
}

struct RingBufferTests {
    @Test func dropsOldestBeyondCapacity() {
        var ring = RingBuffer<Int>(capacity: 3)
        for i in 1...5 { ring.append(i) }
        #expect(ring.elements == [3, 4, 5])
    }

    @Test func keepsOrderBeforeFull() {
        var ring = RingBuffer<Int>(capacity: 3)
        ring.append(1)
        ring.append(2)
        #expect(ring.elements == [1, 2])
    }
}

struct BucketAveragerTests {
    @Test func emitsAverageWhenBucketCloses() {
        var avg = BucketAverager(interval: 10)
        #expect(avg.add(PowerSample(date: t0, inputW: 10, systemW: 4)) == nil)
        #expect(avg.add(PowerSample(date: t0 + 5, inputW: 20, systemW: 6)) == nil)
        let out = avg.add(PowerSample(date: t0 + 10, inputW: 99, systemW: 99))
        #expect(out == PowerSample(date: t0, inputW: 15, systemW: 5))
    }

    @Test func bucketsAlignToWallClock() {
        var avg = BucketAverager(interval: 10)
        _ = avg.add(PowerSample(date: t0 + 7, inputW: 10, systemW: 10))
        let out = avg.add(PowerSample(date: t0 + 12, inputW: 0, systemW: 0))
        #expect(out?.date == t0)
    }
}

struct PowerHistoryTests {
    @Test func hourRangeKeepsOneSamplePerSecond() {
        var h = PowerHistory()
        h.record(connected(10, 5), at: t0)
        h.record(connected(20, 5), at: t0 + 0.5) // same second, e.g. a power-source event
        h.record(connected(30, 5), at: t0 + 1)
        h.record(connected(30, 5), at: t0 + 2)
        #expect(h.samples(.hour).map(\.inputW) == [15, 30])
    }

    @Test func sixHourRangeAveragesTenSeconds() {
        var h = PowerHistory()
        for s in 0..<20 { h.record(connected(Double(s), 1), at: t0 + Double(s)) }
        h.record(connected(0, 0), at: t0 + 20)
        #expect(h.samples(.sixHours).map(\.inputW) == [4.5, 14.5])
    }

    @Test func dayRangeAveragesOneMinute() {
        var h = PowerHistory()
        for s in 0..<60 { h.record(connected(12, 3), at: t0 + Double(s)) }
        h.record(connected(0, 0), at: t0 + 60)
        #expect(h.samples(.day) == [PowerSample(date: t0, inputW: 12, systemW: 3)])
    }

    @Test func inputIsZeroOnBattery() {
        var h = PowerHistory()
        let onBattery = PowerSnapshot(isExternalConnected: false, adapterInW: 3, systemLoadW: 11)
        h.record(onBattery, at: t0)
        h.record(onBattery, at: t0 + 1)
        #expect(h.samples(.hour) == [PowerSample(date: t0, inputW: 0, systemW: 11)])
    }

    @Test func rangesMatchSpec() {
        #expect(HistoryRange.hour.duration == 3600)
        #expect(HistoryRange.hour.capacity == 3600)
        #expect(HistoryRange.sixHours.capacity == 2160)
        #expect(HistoryRange.day.capacity == 1440)
    }
}

struct HistoryAxisTests {
    @Test func axisLabelsPerRange() {
        #expect(HistoryRange.hour.axisLabels == ["60분 전", "30분 전", "지금"])
        #expect(HistoryRange.sixHours.axisLabels == ["6시간 전", "3시간 전", "지금"])
        #expect(HistoryRange.day.axisLabels == ["24시간 전", "12시간 전", "지금"])
    }

    @Test func yMaxRoundsUpToTwentyWatts() {
        #expect(HistoryRange.yAxisMax(for: []) == 20)
        #expect(HistoryRange.yAxisMax(for: [PowerSample(date: t0, inputW: 45.2, systemW: 12)]) == 60)
        #expect(HistoryRange.yAxisMax(for: [PowerSample(date: t0, inputW: 14.9, systemW: 20)]) == 40)
    }
}
