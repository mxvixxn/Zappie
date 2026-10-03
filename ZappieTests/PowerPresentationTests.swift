import Foundation
import Testing
@testable import Zappie

private func present(_ state: PowerState, _ s: PowerSnapshot) -> PowerPresentation {
    PowerPresentation(snapshot: s, state: state)
}

struct WattsFormatTests {
    @Test func signedUsesPlusAndUnicodeMinus() {
        #expect(Format.signedWatts(31.4) == "+31.4 W")
        #expect(Format.signedWatts(-11.8) == "−11.8 W")
    }

    @Test func nearZeroHasNoSign() {
        #expect(Format.signedWatts(0.02) == "0.0 W")
        #expect(Format.signedWatts(-0.04) == "0.0 W")
    }

    @Test func missingIsDash() {
        #expect(Format.watts(nil) == "—")
        #expect(Format.signedWatts(nil) == "—")
    }

    @Test func compactDropsTheSpace() {
        #expect(Format.compactWatts(12.34) == "12.3W")
        #expect(Format.compactSignedWatts(-11.8) == "−11.8W")
    }

    @Test func durations() {
        #expect(Format.duration(minutes: 24) == "약 24분")
        #expect(Format.duration(minutes: 290) == "약 4시간 50분")
        #expect(Format.duration(minutes: 120) == "약 2시간")
        #expect(Format.duration(minutes: nil) == "계산 중")
    }
}

struct PowerPresentationTests {
    let charging = PowerSnapshot(isExternalConnected: true, adapterInW: 45.2, systemLoadW: 12.3, batteryW: 31.4,
                                 percent: 62, timeToFullMin: 24)
    let hold = PowerSnapshot(isExternalConnected: true, adapterInW: 12.3, systemLoadW: 12.3, batteryW: 0, percent: 80)
    let battery = PowerSnapshot(isExternalConnected: false, adapterInW: 0, systemLoadW: 11.8, batteryW: -11.8,
                                percent: 80, timeToEmptyMin: 290)
    let assisted = PowerSnapshot(isExternalConnected: true, adapterInW: 30, systemLoadW: 38, batteryW: -8,
                                 percent: 55, timeToEmptyMin: 400)

    @Test func headerAndBadge() {
        let c = present(.charging, charging)
        #expect(c.source == "전원 어댑터 · 충전 중")
        #expect(c.badge == "충전 중")
        #expect(c.badgeTint == .battery)
        #expect(c.percent == "62%")

        let h = present(.hold, hold)
        #expect(h.source == "전원 어댑터 · 배터리 대기")
        #expect(h.badge == "한도 유지")
        #expect(h.badgeTint == .adapter)

        let b = present(.battery, battery)
        #expect(b.source == "배터리 사용 중")
        #expect(b.badge == "배터리")
        #expect(b.badgeTint == .battery)

        let a = present(.assisted, assisted)
        #expect(a.source == "전원 어댑터 · 배터리 보조")
        #expect(a.badge == "보조 방전")
    }

    @Test func detailRowPerState() {
        let c = present(.charging, charging)
        #expect(c.detailLabel == "충전 완료까지")
        #expect(c.detailValue == "약 24분")

        let h = present(.hold, hold)
        #expect(h.detailLabel == "상태")
        #expect(h.detailValue == "80%에서 유지 중")

        let b = present(.battery, battery)
        #expect(b.detailLabel == "남은 사용 시간")
        #expect(b.detailValue == "약 4시간 50분")
    }

    @Test func menuBarLabelPerState() {
        #expect(present(.charging, charging).menuBar == .init(icon: .bolt, tint: .battery, text: "+31.4W"))
        #expect(present(.hold, hold).menuBar == .init(icon: .plug, tint: .adapter, text: "12.3W"))
        #expect(present(.battery, battery).menuBar == .init(icon: .battery, tint: .battery, text: "−11.8W"))
        #expect(present(.assisted, assisted).menuBar == .init(icon: .battery, tint: .battery, text: "−8.0W"))
    }
}
