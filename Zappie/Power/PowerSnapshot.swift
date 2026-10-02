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

    var adapter: AdapterInfo? = nil
    /// When the battery driver last refreshed these values (`UpdateTime`).
    var updateTime: Date? = nil
}

struct AdapterInfo: Sendable, Equatable {
    var watts: Int
    var voltageV: Double?
    var currentA: Double?
    var name: String?
    var manufacturer: String?
    var protocolDescription: String?
}
