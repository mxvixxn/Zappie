import Foundation
import Testing
@testable import Zappie

/// SMC values measured on this Mac (Mac17,9, macOS 27) on 2026-10-03.
/// Integers are little-endian on Apple Silicon; `flt ` is a little-endian Float32.
struct SMCDecodeTests {
    @Test func decodesLittleEndianFloat() {
        let bytes = withUnsafeBytes(of: Float(66.88).bitPattern.littleEndian) { Array($0) }
        #expect(abs(SMC.decode(bytes, type: "flt ")! - 66.88) < 0.001)
    }

    @Test func decodesLittleEndianSignedCurrent() {
        // B0AC read as big-endian was −22790 (0xA6FA) on battery → little-endian −1370 mA.
        #expect(SMC.decode([0xA6, 0xFA], type: "si16") == -1370)
        // Charging: 0x0D66 → +3430 mA.
        #expect(SMC.decode([0x66, 0x0D], type: "si16") == 3430)
    }

    @Test func decodesLittleEndianUnsignedVoltage() {
        // B0AV 0x3158 → 12632 mV.
        #expect(SMC.decode([0x58, 0x31], type: "ui16") == 12632)
    }

    @Test func unknownTypeIsNil() {
        #expect(SMC.decode([1, 2, 3, 4], type: "ch8*") == nil)
    }
}

struct LivePowerTests {
    @Test func chargingSample() throws {
        let live = try #require(LivePower(values: ["PDTR": 66.88, "PSTR": 25.34, "B0AV": 12632, "B0AC": 3430]))
        #expect(live.adapterInW == 66.88)
        #expect(live.systemLoadW == 25.34)
        #expect(abs(live.batteryW - 43.328) < 0.001)
    }

    @Test func dischargingSample() throws {
        let live = try #require(LivePower(values: ["PDTR": 0, "PSTR": 15.13, "B0AV": 12160, "B0AC": -1370]))
        #expect(live.batteryW < 0)
        #expect(live.adapterInW == 0)
    }

    @Test func missingKeyMeansNoLiveData() {
        #expect(LivePower(values: ["PDTR": 66.88, "PSTR": 25.34, "B0AV": 12632]) == nil)
    }

    @Test func liveWattsReplaceDriverWatts() {
        let driver = PowerSnapshot(isExternalConnected: true, adapterInW: 60.36, systemLoadW: 11.68, batteryW: 48.68,
                                   percent: 78, updateTime: Date(timeIntervalSince1970: 1_791_005_191))
        let now = Date(timeIntervalSince1970: 1_791_005_216)
        let live = LivePower(adapterInW: 66.88, systemLoadW: 25.34, batteryW: 43.33)
        let merged = live.applied(to: driver, at: now)
        #expect(merged.adapterInW == 66.88)
        #expect(merged.systemLoadW == 25.34)
        #expect(merged.batteryW == 43.33)
        #expect(merged.percent == 78)
        #expect(merged.updateTime == now)
        #expect(merged.wattsAreLive)
        #expect(merged.liveSample == live)
        #expect(merged.driverWatts == DriverWatts(adapterInW: 60.36, systemLoadW: 11.68, batteryW: 48.68,
                                                  updateTime: Date(timeIntervalSince1970: 1_791_005_191), valid: true))
    }

    @Test func noAdapterMeansNoInput() {
        // SMC can lag the unplug by a moment; trust ExternalConnected for input.
        let driver = PowerSnapshot(isExternalConnected: false)
        let merged = LivePower(adapterInW: 3.1, systemLoadW: 14, batteryW: -14).applied(to: driver, at: .now)
        #expect(merged.adapterInW == 0)
    }
}

/// Runs against this Mac's real SMC; skipped where AppleSMC cannot be opened.
struct SMCLiveTests {
    static let available = SMCConnection.shared != nil

    @Test(.enabled(if: available)) func readsLiveWattsOnThisMac() throws {
        let live = try #require(SMCConnection.shared?.livePower())
        #expect((0...300).contains(live.adapterInW))
        #expect((0...300).contains(live.systemLoadW))
        #expect((-300...300).contains(live.batteryW))
    }
}
