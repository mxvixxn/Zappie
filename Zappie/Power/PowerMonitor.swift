import Foundation
import IOKit
import IOKit.ps
import Observation

/// Polls `PowerReader` and also refreshes immediately when IOKit reports a change: power source
/// switches, USB devices attaching or detaching, and the battery driver publishing new values.
@Observable
@MainActor
final class PowerMonitor {
    private(set) var snapshot: PowerSnapshot?
    private(set) var state: PowerState?
    private(set) var isSupported = true
    private(set) var history = PowerHistory()
    /// When each port's data-connected USB device first appeared.
    private(set) var usbConnectedSince: [Int: Date] = [:]

    var pollInterval: Duration = .seconds(1)

    private let read: () -> PowerSnapshot?
    private let now: () -> Date
    private let logReason: (ChargeReasonSighting) -> Void
    private var reasonTracker: ChargeReasonTracker
    private var debouncer = StateDebouncer(delay: 2)
    private var connectionChangedAt: Date?
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var runLoopSource: CFRunLoopSource?
    @ObservationIgnored private var notifyPort: IONotificationPortRef?
    @ObservationIgnored private var notifications: [io_object_t] = []

    init(read: @escaping () -> PowerSnapshot? = PowerReader.read, now: @escaping () -> Date = Date.init,
         logReason: @escaping (ChargeReasonSighting) -> Void = ChargeReasonLog.append,
         alreadyLogged: Set<String> = []) {
        self.read = read
        self.now = now
        self.logReason = logReason
        reasonTracker = ChargeReasonTracker(alreadyLogged: alreadyLogged)
    }

    func refresh() {
        guard let reading = read() else {
            isSupported = false
            snapshot = nil
            state = nil
            return
        }
        isSupported = true

        let time = now()
        if let previous = snapshot, previous.isExternalConnected != reading.isExternalConnected {
            connectionChangedAt = time
        }
        snapshot = reading
        state = debouncer.update(PowerState.classify(reading, connectionChangedAt: connectionChangedAt), at: time)
        history.record(reading, at: time)
        reasonTracker.newSightings(in: reading, at: time).forEach(logReason)

        var since = usbConnectedSince.filter { reading.usbDevices[$0.key] != nil }
        for port in reading.usbDevices.keys where since[port] == nil {
            since[port] = time
        }
        if since != usbConnectedSince {
            usbConnectedSince = since
        }
    }

    func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled, let self {
                refresh()
                try? await Task.sleep(for: pollInterval)
            }
        }
        subscribeToPowerSourceChanges()
        subscribeToIOKitChanges()
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
        }
        runLoopSource = nil
        notifications.forEach { IOObjectRelease($0) }
        notifications = []
        if let notifyPort {
            IONotificationPortDestroy(notifyPort)
        }
        notifyPort = nil
    }

    private func subscribeToPowerSourceChanges() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOPowerSourceCallbackType = { context in
            guard let context else { return }
            let monitor = Unmanaged<PowerMonitor>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { monitor.refresh() }
        }
        guard let source = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        runLoopSource = source
    }

    /// USB attach/detach shows data devices (iPhone, iPad, Macs) on their port at once;
    /// battery-driver interest messages pick up new `PowerOutDetails` without waiting for the poll.
    private func subscribeToIOKitChanges() {
        guard notifyPort == nil, let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        IONotificationPortSetDispatchQueue(port, .main)
        notifyPort = port
        let context = Unmanaged.passUnretained(self).toOpaque()

        let usbChanged: IOServiceMatchingCallback = { context, iterator in
            PowerMonitor.drain(iterator)
            guard let context else { return }
            let monitor = Unmanaged<PowerMonitor>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { monitor.refresh() }
        }
        for type in [kIOFirstMatchNotification, kIOTerminatedNotification] {
            var iterator: io_iterator_t = 0
            if IOServiceAddMatchingNotification(port, type, IOServiceMatching("IOUSBHostDevice"), usbChanged,
                                                context, &iterator) == KERN_SUCCESS {
                Self.drain(iterator) // arms the notification
                notifications.append(iterator)
            }
        }

        let battery = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard battery != IO_OBJECT_NULL else { return }
        defer { IOObjectRelease(battery) }
        let batteryChanged: IOServiceInterestCallback = { context, _, _, _ in
            guard let context else { return }
            let monitor = Unmanaged<PowerMonitor>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { monitor.refresh() }
        }
        var interest: io_object_t = 0
        if IOServiceAddInterestNotification(port, battery, kIOGeneralInterest, batteryChanged, context,
                                            &interest) == KERN_SUCCESS {
            notifications.append(interest)
        }
    }

    private nonisolated static func drain(_ iterator: io_iterator_t) {
        while case let object = IOIteratorNext(iterator), object != IO_OBJECT_NULL {
            IOObjectRelease(object)
        }
    }
}
