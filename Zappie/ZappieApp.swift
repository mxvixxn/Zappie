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
            Text("Zappie")
                .frame(minWidth: 600, minHeight: 480)
        }
    }
}
