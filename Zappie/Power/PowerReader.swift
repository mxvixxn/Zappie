import Foundation
import IOKit

/// Reads `AppleSmartBattery` (and its `AppleSmartBatteryPack` child) from the IORegistry.
/// Key names and units are verified against real output in `docs/SPEC.md` §1.
enum PowerReader {
    /// Returns `nil` on Macs without a battery or without `PowerTelemetryData` (Intel, desktops).
    static func read() -> PowerSnapshot? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(service) }

        guard let battery = properties(of: service) else { return nil }
        return parse(battery: battery, pack: packProperties(of: service))
    }

    static func parse(battery: [String: Any], pack: [String: Any]?) -> PowerSnapshot? {
        guard let telemetry = battery["PowerTelemetryData"] as? [String: Any] else { return nil }
        let batteryData = battery["BatteryData"] as? [String: Any]

        let voltageMV = signed(battery["Voltage"])
        let amperageMA = signed(battery["InstantAmperage"])

        var batteryW = signed(telemetry["BatteryPower"]).map(milli)
        if batteryW == nil || batteryW == 0, let voltageMV, let amperageMA {
            batteryW = Double(voltageMV) * Double(amperageMA) / 1_000_000
        }

        let packData = pack?["BatteryData"] as? [String: Any]

        return PowerSnapshot(
            isExternalConnected: battery["ExternalConnected"] as? Bool ?? false,
            adapterInW: signed(telemetry["SystemPowerIn"]).map(milli),
            systemLoadW: signed(telemetry["SystemLoad"]).map(milli),
            batteryW: batteryW,
            adapterLossW: signed(telemetry["AdapterEfficiencyLoss"]).map(milli),
            batteryVoltageV: voltageMV.map(milli),
            batteryCurrentA: amperageMA.map(milli),
            temperatureC: signed(packData?["Temperature"]).map { Double($0) / 100 },
            percent: int(battery["CurrentCapacity"]),
            cycleCount: int(battery["CycleCount"]),
            designCapacitymAh: int(batteryData?["DesignCapacity"]),
            fullChargeCapacitymAh: int(batteryData?["FullChargeCapacity"]),
            timeToFullMin: minutes(battery["AvgTimeToFull"]),
            timeToEmptyMin: minutes(battery["AvgTimeToEmpty"]),
            adapter: adapter(battery["AdapterDetails"] as? [String: Any])
        )
    }

    // MARK: - Parsing helpers

    private static func adapter(_ details: [String: Any]?) -> AdapterInfo? {
        guard let details, let watts = int(details["Watts"]) else { return nil }
        return AdapterInfo(
            watts: watts,
            voltageV: signed(details["AdapterVoltage"]).map(milli),
            currentA: signed(details["Current"]).map(milli),
            name: (details["Name"] as? String)?.trimmingCharacters(in: .whitespaces),
            manufacturer: details["Manufacturer"] as? String,
            protocolDescription: details["Description"] as? String
        )
    }

    /// IOKit publishes negative values as UInt64 bit patterns; `int64Value` reinterprets them.
    private static func signed(_ value: Any?) -> Int64? {
        (value as? NSNumber)?.int64Value
    }

    private static func int(_ value: Any?) -> Int? {
        signed(value).map(Int.init)
    }

    /// 65535 means "still calculating / not applicable".
    private static func minutes(_ value: Any?) -> Int? {
        guard let m = int(value), m != 65535 else { return nil }
        return m
    }

    private static func milli(_ value: Int64) -> Double {
        Double(value) / 1000
    }

    // MARK: - IORegistry

    private static func properties(of entry: io_registry_entry_t) -> [String: Any]? {
        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(entry, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS else {
            return nil
        }
        return props?.takeRetainedValue() as? [String: Any]
    }

    private static func packProperties(of battery: io_registry_entry_t) -> [String: Any]? {
        var iterator: io_iterator_t = 0
        guard IORegistryEntryGetChildIterator(battery, kIOServicePlane, &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        while case let child = IOIteratorNext(iterator), child != IO_OBJECT_NULL {
            defer { IOObjectRelease(child) }
            if IOObjectConformsTo(child, "AppleSmartBatteryPack") != 0 {
                return properties(of: child)
            }
        }
        return nil
    }
}
