import Foundation

/// One reading of the battery/adapter state. Watts are signed: battery charge +, discharge −.
struct PowerSnapshot: Sendable, Equatable {
    var isExternalConnected: Bool
    var adapterInW: Double?
    var systemLoadW: Double?
    var batteryW: Double?
    var adapterLossW: Double?

    var batteryVoltageV: Double?
    var batteryCurrentA: Double?
    var temperatureC: Double?
    var percent: Int?
    var cycleCount: Int?
    var designCapacitymAh: Int?
    var fullChargeCapacitymAh: Int?
    var timeToFullMin: Int?
    var timeToEmptyMin: Int?

    var adapter: AdapterInfo?
}

struct AdapterInfo: Sendable, Equatable {
    var watts: Int
    var voltageV: Double?
    var currentA: Double?
    var name: String?
    var manufacturer: String?
    var protocolDescription: String?
}
