import Foundation
import Testing
@testable import Zappie

struct OverviewPresentationTests {
    let adapter = AdapterInfo(watts: 68, voltageV: 20, currentA: 3.39, name: "70W USB-C Power Adapter",
                              manufacturer: "Apple Inc.", protocolDescription: "pd charger")

    var charging: PowerSnapshot {
        PowerSnapshot(isExternalConnected: true, adapterInW: 45.2, systemLoadW: 12.3, batteryW: 31.4, adapterLossW: 0.233,
                      batteryVoltageV: 12.71, batteryCurrentA: 2.47, temperatureC: 33.42, percent: 62, cycleCount: 66,
                      designCapacitymAh: 6249, fullChargeCapacitymAh: 6004, timeToFullMin: 24, adapter: adapter)
    }

    var battery: PowerSnapshot {
        PowerSnapshot(isExternalConnected: false, adapterInW: 0, systemLoadW: 11.8, batteryW: -11.8,
                      batteryVoltageV: 12.3, batteryCurrentA: -1.124, percent: 80, timeToEmptyMin: 290)
    }

    @Test func compositionSplitsInputIntoSystemChargeAndOther() throws {
        let c = try #require(OverviewPresentation(snapshot: charging, state: .charging).composition)
        #expect(c.totalText == "45.2 W")
        #expect(c.rows.map(\.label) == ["시스템 소비", "배터리 충전", "기타·손실 (계산값)"])
        #expect(c.rows.map(\.valueText) == ["12.3 W · 27%", "31.4 W · 69%", "1.5 W · 3%"])
        #expect(abs(c.rows.map(\.fraction).reduce(0, +) - 1) < 0.0001)
    }

    @Test func compositionClampsNegativeOtherToZero() throws {
        let s = PowerSnapshot(isExternalConnected: true, adapterInW: 14.9, systemLoadW: 15.0, batteryW: 0)
        let c = try #require(OverviewPresentation(snapshot: s, state: .hold).composition)
        #expect(c.rows[2].valueText == "0.0 W · 0%")
        #expect(c.rows[1].valueText == "0.0 W · 0%")
    }

    @Test func noCompositionOnBattery() {
        #expect(OverviewPresentation(snapshot: battery, state: .battery).composition == nil)
    }

    @Test func adapterCard() throws {
        let a = try #require(OverviewPresentation(snapshot: charging, state: .charging).adapter)
        #expect(a.ratedText == "68 W")
        #expect(a.subtitle == "70W USB-C Power Adapter")
        #expect(a.usageText == "66%")
        #expect(abs(a.usageFraction - 45.2 / 68) < 0.0001)
        #expect(a.negotiatedText == "20.0 V × 3.39 A")
        #expect(a.lossText == "0.2 W")
    }

    @Test func usageFractionIsClampedToOne() throws {
        var s = charging
        s.adapterInW = 80
        let a = try #require(OverviewPresentation(snapshot: s, state: .charging).adapter)
        #expect(a.usageFraction == 1)
    }

    @Test func noAdapterCardOnBattery() {
        #expect(OverviewPresentation(snapshot: battery, state: .battery).adapter == nil)
    }

    @Test func batteryTiles() {
        let tiles = OverviewPresentation(snapshot: charging, state: .charging).batteryTiles
        #expect(tiles.map(\.label) == ["전압", "전류", "온도", "사이클", "최대 용량", "충전 한도"])
        #expect(tiles.map(\.value) == ["12.71 V", "+2.47 A", "33.4 °C", "66", "96%", "—"])

        let discharging = OverviewPresentation(snapshot: battery, state: .battery).batteryTiles
        #expect(discharging[1].value == "−1.12 A")
        #expect(discharging[2].value == "—")
    }

    @Test func batteryCaptionNamesTheDirection() {
        #expect(OverviewPresentation(snapshot: charging, state: .charging).batteryCaption == "+31.4 W 충전")
        #expect(OverviewPresentation(snapshot: battery, state: .battery).batteryCaption == "−11.8 W 방전")
        let hold = PowerSnapshot(isExternalConnected: true, adapterInW: 12, systemLoadW: 12, batteryW: 0)
        #expect(OverviewPresentation(snapshot: hold, state: .hold).batteryCaption == "0.0 W")
    }

    @Test func updatedAgo() {
        let t = Date(timeIntervalSince1970: 1_790_950_000)
        #expect(Format.updatedAgo(t, now: t.addingTimeInterval(1)) == "방금 갱신")
        #expect(Format.updatedAgo(t, now: t.addingTimeInterval(14)) == "14초 전 갱신")
        #expect(Format.updatedAgo(t, now: t.addingTimeInterval(130)) == "2분 전 갱신")
        #expect(Format.updatedAgo(nil, now: t) == "")
    }
}
