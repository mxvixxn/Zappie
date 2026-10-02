import SwiftUI

@main
struct ZappieApp: App {
    var body: some Scene {
        MenuBarExtra {
            DropdownView()
        } label: {
            Image(systemName: "bolt.fill")
        }
        .menuBarExtraStyle(.window)

        Window("Zappie", id: "main") {
            Text("Zappie")
                .frame(minWidth: 600, minHeight: 480)
        }
    }
}

struct DropdownView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("전원")
                .font(.headline)
            Button("앱에서 자세히 보기") {
                openWindow(id: "main")
                NSApp.activate()
            }
            Divider()
            Button("종료") { NSApp.terminate(nil) }
        }
        .padding()
        .frame(width: 340)
    }
}
