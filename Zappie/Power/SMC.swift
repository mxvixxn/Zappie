import Foundation
import IOKit

/// Read-only access to the System Management Controller's power sensors. Unlike the battery
/// driver's `PowerTelemetryData` (refreshed every 1–60 s), these update about every 1.5 s.
///
/// This is a private interface (as used by Stats / iStat Menus). Any failure returns nil and the
/// app falls back to the battery driver's watts. Key meanings verified on Mac17,9 (docs/SPEC.md §1):
/// `PDTR` adapter input W, `PSTR` system total W, `B0AV` battery mV, `B0AC` battery mA (signed).
enum SMC {
    static let liveKeys = ["PDTR", "PSTR", "B0AV", "B0AC"]

    /// Apple Silicon stores SMC integers and floats little-endian.
    static func decode(_ bytes: [UInt8], type: String) -> Double? {
        func le<T: FixedWidthInteger>(_: T.Type) -> T? {
            guard bytes.count >= MemoryLayout<T>.size else { return nil }
            return bytes.prefix(MemoryLayout<T>.size).enumerated()
                .reduce(T.zero) { $0 | T(truncatingIfNeeded: $1.element) << (8 * $1.offset) }
        }
        switch type {
        case "flt ": return le(UInt32.self).map { Double(Float(bitPattern: $0)) }
        case "si16": return le(UInt16.self).map { Double(Int16(bitPattern: $0)) }
        case "ui16": return le(UInt16.self).map(Double.init)
        case "ui32": return le(UInt32.self).map(Double.init)
        case "ui8 ": return bytes.first.map(Double.init)
        default: return nil
        }
    }
}

/// Live watts from the SMC.
struct LivePower: Equatable, Sendable {
    var adapterInW: Double
    var systemLoadW: Double
    /// Signed: charging +, discharging −.
    var batteryW: Double

    init(adapterInW: Double, systemLoadW: Double, batteryW: Double) {
        self.adapterInW = adapterInW
        self.systemLoadW = systemLoadW
        self.batteryW = batteryW
    }

    init?(values: [String: Double]) {
        guard let input = values["PDTR"], let system = values["PSTR"],
              let mV = values["B0AV"], let mA = values["B0AC"] else { return nil }
        self.init(adapterInW: input, systemLoadW: system, batteryW: mV * mA / 1_000_000)
    }

    /// Replaces the driver's watts with live ones. Everything else (capacity, ports, reasons)
    /// still comes from the driver. Connection state stays the driver's `ExternalConnected`.
    func applied(to driver: PowerSnapshot, at now: Date) -> PowerSnapshot {
        var s = driver
        s.adapterInW = driver.isExternalConnected ? adapterInW : 0
        s.systemLoadW = systemLoadW
        s.batteryW = batteryW
        s.updateTime = now
        s.telemetryValid = true
        s.wattsAreLive = true
        return s.hasImpossibleWatts ? s.withHiddenWatts() : s
    }
}

/// One user-client connection to AppleSMC, opened on first use.
final class SMCConnection: @unchecked Sendable {
    static let shared = SMCConnection()

    private let lock = NSLock()
    private var connection: io_connect_t = 0
    private var keyInfo: [String: (size: UInt32, type: String)] = [:]

    private init?() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(service) }
        guard IOServiceOpen(service, mach_task_self_, 0, &connection) == KERN_SUCCESS else { return nil }
    }

    deinit {
        IOServiceClose(connection)
    }

    func livePower() -> LivePower? {
        lock.lock()
        defer { lock.unlock() }
        var values: [String: Double] = [:]
        for key in SMC.liveKeys {
            guard let value = read(key) else { return nil }
            values[key] = value
        }
        return LivePower(values: values)
    }

    // MARK: - AppleSMC protocol (SMCKeyData_t, 80 bytes; selector 2)

    private struct KeyData {
        var key: UInt32 = 0
        var vers: (UInt8, UInt8, UInt8, UInt8, UInt16) = (0, 0, 0, 0, 0)
        var pLimit: (UInt16, UInt16, UInt32, UInt32, UInt32) = (0, 0, 0, 0, 0)
        var dataSize: UInt32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
        var padding: (UInt8, UInt8, UInt8) = (0, 0, 0) // C pads keyInfo to 12 bytes
        var result: UInt8 = 0
        var status: UInt8 = 0
        var command: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                    UInt8, UInt8, UInt8, UInt8) =
            (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    }

    private enum Command: UInt8 {
        case readKey = 5
        case keyInfo = 9
    }

    private func call(_ input: KeyData) -> KeyData? {
        var input = input
        var output = KeyData()
        var size = MemoryLayout<KeyData>.stride
        let result = IOConnectCallStructMethod(connection, 2, &input, MemoryLayout<KeyData>.stride, &output, &size)
        return result == KERN_SUCCESS && output.result == 0 ? output : nil
    }

    private func read(_ key: String) -> Double? {
        let code = key.utf8.reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
        if keyInfo[key] == nil {
            var request = KeyData()
            request.key = code
            request.command = Command.keyInfo.rawValue
            guard let info = call(request) else { return nil }
            let type = String(bytes: [24, 16, 8, 0].map { UInt8((info.dataType >> $0) & 0xFF) }, encoding: .ascii) ?? ""
            keyInfo[key] = (info.dataSize, type)
        }
        guard let info = keyInfo[key] else { return nil }
        var request = KeyData()
        request.key = code
        request.dataSize = info.size
        request.command = Command.readKey.rawValue
        guard let output = call(request) else { return nil }
        let bytes = withUnsafeBytes(of: output.bytes) { Array($0.prefix(Int(info.size))) }
        return SMC.decode(bytes, type: info.type)
    }
}
