import Foundation
import IOKit
import Testing
@testable import Zappie

struct PowerReaderTests {
    @Test func parsesTelemetryInWatts() throws {
        let s = try #require(PowerReader.parse(battery: Fixtures.pluggedHold, pack: nil))
        #expect(s.isExternalConnected)
        #expect(s.adapterInW == 14.916)
        #expect(s.systemLoadW == 14.916)
        #expect(s.batteryW == 0)
        #expect(s.adapterLossW == 0.233)
    }

    @Test func decodesNegativeValuesSentAsUInt64() throws {
        let s = try #require(PowerReader.parse(battery: Fixtures.discharging, pack: nil))
        #expect(!s.isExternalConnected)
        #expect(s.batteryW == -16.86)
        #expect(s.batteryCurrentA == -1.124)
    }

    @Test func fallsBackToVoltageTimesCurrentWithoutBatteryPower() throws {
        var battery = Fixtures.discharging
        var telemetry = battery["PowerTelemetryData"] as! [String: Any]
        telemetry["BatteryPower"] = nil
        battery["PowerTelemetryData"] = telemetry

        let s = try #require(PowerReader.parse(battery: battery, pack: nil))
        let w = try #require(s.batteryW)
        #expect(abs(w - (-13.822952)) < 0.0001)
    }

    /// Telemetry 0 means idle. A momentary InstantAmperage wobble under a load spike must not
    /// override it (seen live: −0.8 W shown as "보조 방전" while input == system load).
    @Test func telemetryZeroIsNotReplacedByInstantCurrent() throws {
        var battery = Fixtures.pluggedHold
        battery["InstantAmperage"] = NSNumber(value: UInt64(bitPattern: -65))
        let s = try #require(PowerReader.parse(battery: battery, pack: nil))
        #expect(s.batteryW == 0)
    }

    @Test func readsTemperatureFromPackNode() throws {
        let withPack = try #require(PowerReader.parse(battery: Fixtures.pluggedHold, pack: Fixtures.pack))
        #expect(withPack.temperatureC == 28.29)

        let withoutPack = try #require(PowerReader.parse(battery: Fixtures.pluggedHold, pack: nil))
        #expect(withoutPack.temperatureC == nil)
    }

    @Test func readsBatteryHealth() throws {
        let s = try #require(PowerReader.parse(battery: Fixtures.pluggedHold, pack: nil))
        #expect(s.percent == 80)
        #expect(s.cycleCount == 66)
        #expect(s.designCapacitymAh == 6249)
        #expect(s.fullChargeCapacitymAh == 6004)
        #expect(s.batteryVoltageV == 12.416)
    }

    @Test func treats65535AsNoEstimate() throws {
        let plugged = try #require(PowerReader.parse(battery: Fixtures.pluggedHold, pack: nil))
        #expect(plugged.timeToFullMin == nil)
        #expect(plugged.timeToEmptyMin == nil)

        let discharging = try #require(PowerReader.parse(battery: Fixtures.discharging, pack: nil))
        #expect(discharging.timeToEmptyMin == 95)
    }

    @Test func readsAdapterDetails() throws {
        let s = try #require(PowerReader.parse(battery: Fixtures.pluggedHold, pack: nil))
        let adapter = try #require(s.adapter)
        #expect(adapter.watts == 68)
        #expect(adapter.voltageV == 20)
        #expect(adapter.currentA == 3.39)
        #expect(adapter.name == "70W USB-C Power Adapter")
        #expect(adapter.manufacturer == "Apple Inc.")
        #expect(adapter.protocolDescription == "pd charger")
    }

    @Test func noAdapterWhenDetailsHaveNoWatts() throws {
        let s = try #require(PowerReader.parse(battery: Fixtures.discharging, pack: nil))
        #expect(s.adapter == nil)
    }

    @Test func readsUpdateTimeAsDate() throws {
        let s = try #require(PowerReader.parse(battery: Fixtures.pluggedHold, pack: nil))
        #expect(s.updateTime == Date(timeIntervalSince1970: 1790950824))
    }

    /// `PowerOutDetails` lists only ports currently supplying power; `Watts` is actually mW.
    @Test func readsUSBPortOutputs() throws {
        let s = try #require(PowerReader.parse(battery: Fixtures.pluggedHold, pack: nil))
        #expect(s.portOutputs == [
            PortOutput(port: 1, watts: 4.448, voltageV: 5.201, currentA: 0.855,
                       deviceBatteryPercent: 83, deviceIsApple: true),
            PortOutput(port: 3, watts: 1.276, voltageV: 5.203, currentA: 0.245),
        ])
        #expect(abs(s.usbOutW - 5.724) < 0.0001)
    }

    @Test func noPortOutputsWhenNothingIsCharging() throws {
        let s = try #require(PowerReader.parse(battery: Fixtures.discharging, pack: nil))
        #expect(s.portOutputs.isEmpty)
        #expect(s.usbOutW == 0)
    }

    @Test func unsupportedWithoutPowerTelemetry() {
        var battery = Fixtures.pluggedHold
        battery["PowerTelemetryData"] = nil
        #expect(PowerReader.parse(battery: battery, pack: nil) == nil)
    }
}

/// Runs against this Mac's real IORegistry; skipped on Macs without a battery.
struct PowerReaderLiveTests {
    static let hasBattery: Bool = {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        defer { IOObjectRelease(service) }
        return service != IO_OBJECT_NULL
    }()

    @Test(.enabled(if: hasBattery)) func readsThisMac() throws {
        let s = try #require(PowerReader.read())
        #expect(s.percent != nil)
        #expect(s.systemLoadW != nil)
        #expect(s.temperatureC.map { (5...60).contains($0) } == true)
    }
}
