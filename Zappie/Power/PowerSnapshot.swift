import Foundation

/// One reading of the battery/adapter state. Watts are signed: battery charge +, discharge −.
struct PowerSnapshot: Sendable, Equatable {
    var isExternalConnected: Bool
    var adapterInW: Double? = nil
    var systemLoadW: Double? = nil
    var batteryW: Double? = nil
    var adapterLossW: Double? = nil

    var batteryVoltageV: Double? = nil
    var batteryCurrentA: Double? = nil
    var temperatureC: Double? = nil
    var percent: Int? = nil
    var cycleCount: Int? = nil
    var designCapacitymAh: Int? = nil
    var fullChargeCapacitymAh: Int? = nil
    var timeToFullMin: Int? = nil
    var timeToEmptyMin: Int? = nil
    /// `ChargerData.NotChargingReason`; 0x1000000 = held at the charge limit (verified).
    var notChargingReason: Int? = nil
    /// `ChargerData.SlowChargingReason`; non-zero means charging is being slowed.
    var slowChargingReason: Int? = nil
    var fullyCharged: Bool? = nil

    var adapter: AdapterInfo? = nil
    /// USB-C ports currently supplying power to other devices. Already included in `systemLoadW`.
    var portOutputs: [PortOutput] = []
    /// Data-connected USB devices by port (e.g. 2: "iPhone"). These appear the moment a device is
    /// plugged in, unlike `portOutputs`, which waits for the battery driver's next refresh.
    var usbDevices: [Int: String] = [:]
    /// When the battery driver last refreshed these values (`UpdateTime`).
    var updateTime: Date? = nil
}

extension PowerSnapshot {
    var usbOutW: Double { portOutputs.reduce(0) { $0 + $1.watts } }
}

struct PortOutput: Sendable, Equatable {
    /// `PowerOutDetails.PortIndex`; see `PortName` for the physical location.
    var port: Int
    var watts: Double
    var voltageV: Double? = nil
    var currentA: Double? = nil
    /// USB product name, when the device also connects for data (e.g. "iPhone").
    var deviceName: String? = nil
    /// The device's own battery level, reported by some Apple devices via `FedDetails`.
    var deviceBatteryPercent: Int? = nil
    var deviceIsApple = false
}

struct AdapterInfo: Sendable, Equatable {
    var watts: Int
    var voltageV: Double?
    var currentA: Double?
    var name: String?
    var manufacturer: String?
    var protocolDescription: String?
}
