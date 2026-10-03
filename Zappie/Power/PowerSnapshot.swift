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
    /// The port the charger is plugged into, when one is.
    var powerInput: PowerInput? = nil
    /// This Mac's USB-C ports and their names.
    var portLayout: PortLayout = .mac17_9
    /// When the battery driver last refreshed these values (`UpdateTime`).
    var updateTime: Date? = nil
    /// False when the watts were withheld as impossible or stale (see `withHiddenWatts()`).
    var telemetryValid = true
    /// True when the watts came from the SMC (live, ~1.5 s) rather than the battery driver.
    var wattsAreLive = false
}

extension PowerSnapshot {
    var usbOutW: Double { portOutputs.reduce(0) { $0 + $1.watts } }

    /// Watts the driver could not have measured: negative system load, or charging on battery.
    /// Seen right at an unplug: SystemLoad −48.6 W with BatteryPower +48.6 W.
    var hasImpossibleWatts: Bool {
        if let load = systemLoadW, load < 0 { return true }
        if let input = adapterInW, input < 0 { return true }
        if !isExternalConnected, let battery = batteryW, battery > PowerState.idleThresholdW { return true }
        return false
    }

    /// Same snapshot with the power-flow watts removed, for "갱신 대기 중".
    func withHiddenWatts() -> PowerSnapshot {
        var copy = self
        copy.adapterInW = nil
        copy.systemLoadW = nil
        copy.batteryW = nil
        copy.adapterLossW = nil
        copy.telemetryValid = false
        return copy
    }
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
