import Foundation
import Testing
@testable import Zappie

/// SMC key meanings are verified only on Mac17,9. On other Macs the app checks them itself:
/// each fresh battery-driver publication must fall inside the range the SMC showed over the last
/// 30 s; live watts turn off only when most recent checks fail.
struct SMCValidatorTests {
    let t0 = Date(timeIntervalSince1970: 1_791_010_000)

    func driver(_ input: Double?, _ system: Double?, _ battery: Double?, at t: Date) -> DriverWatts {
        DriverWatts(adapterInW: input, systemLoadW: system, batteryW: battery, updateTime: t, valid: true)
    }

    func feed(_ v: inout SMCValidator, _ samples: [(Double, Double, Double)], endingAt end: Date) {
        for (i, s) in samples.enumerated() {
            v.record(LivePower(systemLoadW: s.1, batteryW: s.2),
                     at: end - Double(samples.count - 1 - i))
        }
    }

    @Test func thisMacIdleMatches() {
        var v = SMCValidator()
        feed(&v, [(15.9, 16.8, 0), (15.9, 16.83, 0)], endingAt: t0 + 1)
        #expect(v.check(driver: driver(16.83, 16.83, 0, at: t0), now: t0 + 1) == .match)
        #expect(v.matches == 1)
    }

    /// Seen on this Mac during a build: driver 36.7 / 36.9 W while one SMC sample read 19.1 / 30.0 W.
    @Test func thisMacUnderBurstyLoadStillMatches() {
        var v = SMCValidator()
        feed(&v, [(22, 24, 0), (38, 37.5, 0), (30, 35, 0), (19.1, 30.0, 0)], endingAt: t0 + 1)
        #expect(v.check(driver: driver(36.7, 36.9, -0.17, at: t0), now: t0 + 1) == .match)
    }

    @Test func persistentlyWrongKeysDisableAfterEightOfTen() {
        var v = SMCValidator()
        var verdicts: [SMCValidator.Verdict] = []
        for i in 0..<10 {
            let t = t0 + Double(i * 60)
            feed(&v, [(0, 2, 40), (0, 2.2, 41)], endingAt: t + 1)
            verdicts.append(v.check(driver: driver(0, 15, -15, at: t), now: t + 1))
        }
        #expect(verdicts.prefix(9).allSatisfy { $0 == .mismatch })
        #expect(verdicts.last == .disable)
    }

    @Test func occasionalMissesNeverDisable() {
        var v = SMCValidator()
        for i in 0..<20 {
            let t = t0 + Double(i * 60)
            let wrong = i % 3 == 0
            feed(&v, [wrong ? (0, 2, 40) : (0, 15, -15)], endingAt: t + 1)
            #expect(v.check(driver: driver(0, 15, -15, at: t), now: t + 1) != .disable)
        }
    }

    @Test func samePublicationCheckedOnce() {
        var v = SMCValidator()
        feed(&v, [(0, 15, -15)], endingAt: t0 + 1)
        _ = v.check(driver: driver(0, 15, -15, at: t0), now: t0 + 1)
        #expect(v.check(driver: driver(0, 15, -15, at: t0), now: t0 + 2) == .skipped)
    }

    @Test func oldDriverValuesAreNotCompared() {
        var v = SMCValidator()
        feed(&v, [(0, 30, -30)], endingAt: t0 + 30)
        #expect(v.check(driver: driver(0, 15, -15, at: t0), now: t0 + 30) == .skipped)
    }

    @Test func noRecentSMCSamplesMeansNoVerdict() {
        var v = SMCValidator()
        #expect(v.check(driver: driver(0, 15, -15, at: t0), now: t0 + 1) == .skipped)
    }

    /// At a plug change the driver publishes mixed-up numbers; never blame the SMC for those.
    @Test func plugChangesAreNotCompared() {
        var v = SMCValidator()
        feed(&v, [(66.9, 25, 42)], endingAt: t0 + 1)
        #expect(v.check(driver: driver(60.4, 11.7, 48.7, at: t0), now: t0 + 1, connectionChangedAt: t0 - 2) == .skipped)
    }

    @Test func invalidDriverValuesAreNotCompared() {
        var v = SMCValidator()
        feed(&v, [(0, 15, -15)], endingAt: t0 + 1)
        let hidden = DriverWatts(adapterInW: nil, systemLoadW: nil, batteryW: nil, updateTime: t0, valid: false)
        #expect(v.check(driver: hidden, now: t0 + 1) == .skipped)
    }

    @Test func oppositeBatteryDirectionIsAMismatch() {
        var v = SMCValidator()
        feed(&v, [(0, 15, 15), (0, 15, 14)], endingAt: t0 + 1)
        #expect(v.check(driver: driver(0, 15, -15, at: t0), now: t0 + 1) == .mismatch)
    }

    @Test func idleBatteryNearZeroMatchesEitherSign() {
        var v = SMCValidator()
        feed(&v, [(22.2, 21.5, -0.2)], endingAt: t0 + 1)
        #expect(v.check(driver: driver(22, 22, 0, at: t0), now: t0 + 1) == .match)
    }
}
