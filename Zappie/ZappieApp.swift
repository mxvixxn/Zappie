import SwiftUI

@main
struct ZappieApp: App {
    @State private var monitor = PowerMonitor(alreadyLogged: ChargeReasonLog.loggedKeys())

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
                }
                .onChange(of: pollInterval) { _, seconds in
                    monitor.pollInterval = .seconds(seconds)
                }
        }
        .menuBarExtraStyle(.window)

        Window("Zappie", id: "main") {
            MainWindow(monitor: monitor)
        }
        .defaultSize(width: 1200, height: 960)
    }
}
