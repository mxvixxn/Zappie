import SwiftUI

@main
struct ZappieApp: App {
    @State private var monitor = PowerMonitor()
    @AppStorage(AppSettings.pollIntervalKey) private var pollInterval = 1

    var body: some Scene {
        MenuBarExtra {
            DropdownView(monitor: monitor)
        } label: {
            MenuBarLabel(monitor: monitor)
                .task {
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
