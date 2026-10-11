import SwiftUI

@main
struct ZappieApp: App {
    @State private var monitor = PowerMonitor(
        alreadyLogged: ChargeReasonLog.loggedKeys(),
        liveWattsDisabled: LiveWattsGuard.isDisabled,
        history: isRunningTests ? PowerHistory() : HistoryStore.load().map { PowerHistory(restoring: $0, now: .now) }
            ?? PowerHistory(),
        saveHistory: { archive in
            guard !isRunningTests else { return }
            try? HistoryStore.save(archive)
        })

    /// Unit tests run inside this app; keep the live monitor (and its log file) out of them.
    private static let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    @AppStorage(AppSettings.pollIntervalKey) private var pollInterval = 1

    var body: some Scene {
        MenuBarExtra {
            DropdownView(monitor: monitor)
        } label: {
            MenuBarLabel(monitor: monitor)
                .task {
                    guard !Self.isRunningTests else { return }
                    monitor.pollInterval = .seconds(pollInterval)
                    monitor.start()
                    saveHistory(on: NSWorkspace.shared.notificationCenter, NSWorkspace.willSleepNotification)
                    saveHistory(on: .default, NSApplication.willTerminateNotification)
                }
                .onChange(of: pollInterval) { _, seconds in
                    monitor.pollInterval = .seconds(seconds)
                }
        }
        .menuBarExtraStyle(.window)

        Window("Zappie", id: "main") {
            MainWindowScene(monitor: monitor)
        }
        .defaultSize(width: 1200, height: 960)
    }

    private func saveHistory(on center: NotificationCenter, _ name: Notification.Name) {
        center.addObserver(forName: name, object: nil, queue: .main) { [monitor] _ in
            MainActor.assumeIsolated { monitor.saveHistoryNow() }
        }
    }
}
