import Foundation
import IOKit.ps
import Observation

/// Polls `PowerReader` and also refreshes immediately on power-source change notifications.
@Observable
@MainActor
final class PowerMonitor {
    private(set) var snapshot: PowerSnapshot?
    private(set) var state: PowerState?
    private(set) var isSupported = true
    private(set) var history = PowerHistory()

    var pollInterval: Duration = .seconds(1)

    private let read: () -> PowerSnapshot?
    private let now: () -> Date
    private var debouncer = StateDebouncer(delay: 2)
    private var connectionChangedAt: Date?
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var runLoopSource: CFRunLoopSource?

    init(read: @escaping () -> PowerSnapshot? = PowerReader.read, now: @escaping () -> Date = Date.init) {
        self.read = read
        self.now = now
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
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
        }
        runLoopSource = nil
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
}
