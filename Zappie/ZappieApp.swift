import SwiftUI

@main
struct ZappieApp: App {
    @State private var monitor = PowerMonitor()

    var body: some Scene {
        MenuBarExtra {
            DropdownView(monitor: monitor)
        } label: {
            MenuBarLabel(monitor: monitor)
                .task { monitor.start() }
        }
        .menuBarExtraStyle(.window)

        Window("Zappie", id: "main") {
            MainWindow(monitor: monitor)
        }
        .defaultSize(width: 1200, height: 960)
    }
}
