import Foundation
import Testing
@testable import Zappie

struct DetailPresentationTests {
    let adapter = AdapterInfo(watts: 68, voltageV: 20, currentA: 3.39, name: "70W USB-C Power Adapter",
                              manufacturer: "Apple Inc.", protocolDescription: "pd charger")

    var charging: PowerSnapshot {
        PowerSnapshot(isExternalConnected: true, adapterInW: 45.2, systemLoadW: 12.3, batteryW: 31.4, adapterLossW: 0.233,
                      percent: 62, designCapacitymAh: 6249, fullChargeCapacitymAh: 6004, timeToFullMin: 24,
                      adapter: adapter)
    }

    @Test func adapterRows() {
        let rows = DetailRows.adapter(charging)
        #expect(rows.map(\.label) == ["이름", "제조사", "정격", "협상 전압", "협상 전류", "프로토콜", "현재 입력", "어댑터 손실"])
        #expect(rows.map(\.value) == ["70W USB-C Power Adapter", "Apple Inc.", "68 W", "20.0 V", "3.39 A",
                                      "pd charger", "45.2 W", "0.2 W"])
    }

    @Test func adapterRowsEmptyWithoutAdapter() {
        let s = PowerSnapshot(isExternalConnected: false)
        #expect(DetailRows.adapter(s).isEmpty)
    }

    @Test func batteryRows() {
        let rows = DetailRows.battery(charging, state: .charging)
        #expect(rows.map(\.label) == ["잔량", "설계 용량", "최대 충전 용량", "최대 용량", "배터리 전력", "충전 완료까지"])
        #expect(rows.map(\.value) == ["62%", "6,249 mAh", "6,004 mAh", "96%", "+31.4 W", "약 24분"])
    }

    @Test func batteryRowsShowTimeToEmptyWhenDischarging() {
        let s = PowerSnapshot(isExternalConnected: false, batteryW: -11.8, timeToEmptyMin: 290)
        let last = DetailRows.battery(s, state: .battery).last
        #expect(last?.label == "남은 사용 시간")
        #expect(last?.value == "약 4시간 50분")
    }
}

struct HistorySummaryTests {
    let t0 = Date(timeIntervalSince1970: 1_790_949_960)

    @Test func averagesAndPeaks() throws {
        let samples = [
            PowerSample(date: t0, inputW: 40, systemW: 10),
            PowerSample(date: t0 + 1, inputW: 50, systemW: 20),
        ]
        let s = try #require(HistorySummary(samples))
        #expect(s.items.map(\.label) == ["평균 입력", "최대 입력", "평균 시스템", "최대 시스템"])
        #expect(s.items.map(\.value) == ["45.0 W", "50.0 W", "15.0 W", "20.0 W"])
    }

    @Test func nilWhenEmpty() {
        #expect(HistorySummary([]) == nil)
    }
}

struct SettingsTests {
    @Test func pollIntervalOptions() {
        #expect(AppSettings.pollIntervals == [1, 2, 5])
    }

    @Test func iconOnlyHidesText() {
        #expect(MenuBarLabelStyle.watts.showsText)
        #expect(!MenuBarLabelStyle.iconOnly.showsText)
    }
}
