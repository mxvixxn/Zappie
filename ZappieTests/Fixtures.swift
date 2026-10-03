import Foundation

/// IORegistry dictionaries trimmed from the M0 captures in `docs/m0/`
/// (Mac17,9 M5 Pro, macOS 27, 70W USB-C adapter).
enum Fixtures {
    /// Plugged in, holding at the 80% charge limit (`ioreg-plugged.txt`).
    static var pluggedHold: [String: Any] {
        [
            "ExternalConnected": true,
            "Voltage": 12416,
            "InstantAmperage": 0,
            "CurrentCapacity": 80,
            "CycleCount": 66,
            "AvgTimeToFull": 65535,
            "AvgTimeToEmpty": 65535,
            "UpdateTime": 1790950824,
            "FullyCharged": false,
            "ChargerData": ["NotChargingReason": 16777216, "SlowChargingReason": 0] as [String: Any],
            "PowerTelemetryData": [
                "SystemPowerIn": 14916,
                "SystemLoad": 14916,
                "BatteryPower": 0,
                "AdapterEfficiencyLoss": 233,
            ] as [String: Any],
            "BatteryData": [
                "DesignCapacity": 6249,
                "FullChargeCapacity": 6004,
            ] as [String: Any],
            "PowerOutDetails": [
                ["PortIndex": 1, "Watts": 4448, "AdapterVoltage": 5201, "Current": 855, "PDPowermW": 15000],
                ["PortIndex": 3, "Watts": 1276, "AdapterVoltage": 5203, "Current": 245, "PDPowermW": 15000],
            ] as [[String: Any]],
            // One slot per USB-C port (slot = PortIndex − 1). Only some Apple devices fill it.
            "FedDetails": [
                ["FedVendorID": 1452, "FedStateOfCharge": 83, "FedExternalConnected": 0],
                ["FedVendorID": 0, "FedStateOfCharge": 0, "FedExternalConnected": 1],
                ["FedVendorID": 0, "FedStateOfCharge": 0, "FedExternalConnected": 0],
                ["FedVendorID": 0, "FedStateOfCharge": 0, "FedExternalConnected": 1],
            ] as [[String: Any]],
            "AdapterDetails": [
                "Watts": 68,
                "AdapterVoltage": 20000,
                "Current": 3390,
                "Name": "70W USB-C Power Adapter ",
                "Manufacturer": "Apple Inc.",
                "Description": "pd charger",
            ] as [String: Any],
        ]
    }

    /// Discharge telemetry as published right after replug (`ioreg-replugged.txt`).
    /// Negative values arrive as UInt64 bit patterns.
    static var discharging: [String: Any] {
        [
            "ExternalConnected": false,
            "Voltage": 12298,
            "InstantAmperage": NSNumber(value: UInt64(18446744073709550492)),
            "CurrentCapacity": 80,
            "AvgTimeToFull": 65535,
            "AvgTimeToEmpty": 95,
            "PowerTelemetryData": [
                "SystemPowerIn": 0,
                "SystemLoad": 16860,
                "BatteryPower": NSNumber(value: UInt64(18446744073709534756)),
                "AdapterEfficiencyLoss": 0,
            ] as [String: Any],
            "BatteryData": [
                "DesignCapacity": 6249,
                "FullChargeCapacity": 6004,
            ] as [String: Any],
            "AdapterDetails": ["FamilyCode": 0] as [String: Any],
        ]
    }

    /// `AppleSmartBatteryPack` node (`ioreg-battery-pack.txt`).
    static var pack: [String: Any] {
        ["BatteryData": ["Temperature": 2829] as [String: Any]]
    }
}
