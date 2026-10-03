import Foundation
import Testing
@testable import Zappie

/// Heat warning only (Zappie stays read-only; it never stops charging itself).
/// Warn at 40 °C, high at 45 °C, clear below 38 °C; notify once per hot spell, at most every 30 min.
struct TemperatureWatchTests {
    let t0 = Date(timeIntervalSince1970: 1_791_020_000)

    @Test func normalTemperatureIsQuiet() {
        var w = TemperatureWatch()
        #expect(w.update(33.4, at: t0) == nil)
        #expect(w.level == .normal)
    }

    @Test func crossingFortyWarnsOnce() {
        var w = TemperatureWatch()
        #expect(w.update(40.2, at: t0) == .warm)
        #expect(w.level == .warm)
        #expect(w.update(40.8, at: t0 + 60) == nil)
    }

    @Test func fortyFiveEscalates() {
        var w = TemperatureWatch()
        _ = w.update(41, at: t0)
        #expect(w.update(45.3, at: t0 + 60) == .hot)
        #expect(w.level == .hot)
    }

    @Test func staysWarnUntilBelowThirtyEight() {
        var w = TemperatureWatch()
        _ = w.update(40.5, at: t0)
        _ = w.update(39, at: t0 + 60)
        #expect(w.level == .warm)
        _ = w.update(37.9, at: t0 + 120)
        #expect(w.level == .normal)
    }

    @Test func noRepeatNotificationWithinThirtyMinutes() {
        var w = TemperatureWatch()
        _ = w.update(40.5, at: t0)
        _ = w.update(37, at: t0 + 300)
        #expect(w.update(40.5, at: t0 + 600) == nil)
        #expect(w.level == .warm)
        _ = w.update(37, at: t0 + 1200)
        #expect(w.update(40.5, at: t0 + 1801) == .warm)
    }

    @Test func missingTemperatureChangesNothing() {
        var w = TemperatureWatch()
        _ = w.update(41, at: t0)
        #expect(w.update(nil, at: t0 + 60) == nil)
        #expect(w.level == .warm)
    }
}

struct TemperatureDisplayTests {
    @Test func batteryNodeShowsHeat() {
        let s = PowerSnapshot(isExternalConnected: true, adapterInW: 40, systemLoadW: 20, batteryW: 20, temperatureC: 41.24)
        let tree = PowerTree(snapshot: s, state: .charging, heat: .warm)
        #expect(tree.batteryHeat == "41.2 °C · 뜨거움")

        let hot = PowerTree(snapshot: s, state: .charging, heat: .hot)
        #expect(hot.batteryHeat == "41.2 °C · 매우 뜨거움")
    }

    @Test func noHeatLineWhenNormal() {
        let s = PowerSnapshot(isExternalConnected: true, adapterInW: 40, systemLoadW: 20, batteryW: 20, temperatureC: 33)
        #expect(PowerTree(snapshot: s, state: .charging).batteryHeat == nil)
    }

    @Test func notificationText() {
        #expect(TemperatureWatch.message(for: .warm, temperatureC: 40.6, charging: true)
                == .init(title: "배터리 온도가 높습니다 (40.6 °C)",
                         body: "충전 중 배터리가 뜨거워졌습니다. 통풍이 잘되는 곳에 두거나 무거운 작업을 잠시 줄여 주세요."))
        #expect(TemperatureWatch.message(for: .hot, temperatureC: 45.2, charging: false).title
                == "배터리 온도가 매우 높습니다 (45.2 °C)")
    }
}

@MainActor
struct TemperatureMonitorTests {
    @Test func monitorNotifiesOnHotSpell() {
        var sent: [TemperatureWatch.Message] = []
        var reading = PowerSnapshot(isExternalConnected: true, batteryW: 10, temperatureC: 33)
        var now = Date(timeIntervalSince1970: 1_791_020_000)
        let monitor = PowerMonitor(read: { reading }, now: { now }, logReason: { _ in },
                                   notify: { sent.append($0) })
        monitor.refresh()
        reading.temperatureC = 40.6
        now += 60
        monitor.refresh()
        now += 60
        monitor.refresh()
        #expect(sent.count == 1)
        #expect(monitor.heat == .warm)
    }
}
