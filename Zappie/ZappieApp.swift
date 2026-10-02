import SwiftUI

@main
struct ZappieApp: App {
    @State private var monitor = PowerMonitor()

    var body: some Scene {
        MenuBarExtra {
            DropdownView(monitor: monitor)
        } label: {
            Image(systemName: "bolt.fill")
                .task { monitor.start() }
        }
        .menuBarExtraStyle(.window)

        Window("Zappie", id: "main") {
            Text("Zappie")
                .frame(minWidth: 600, minHeight: 480)
        }
    }
}

/// Temporary readout until the designed dropdown lands in M3.
struct DropdownView: View {
    let monitor: PowerMonitor
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("전원")
                .font(.headline)

            if !monitor.isSupported {
                Text("지원하지 않는 기기")
                    .foregroundStyle(.secondary)
            } else if let s = monitor.snapshot {
                Grid(alignment: .leading, verticalSpacing: 4) {
                    row("상태", monitor.state.map(String.init(describing:)) ?? "—")
                    row("입력", watts(s.adapterInW))
                    row("시스템", watts(s.systemLoadW))
                    row("배터리", watts(s.batteryW))
                    row("잔량", s.percent.map { "\($0)%" } ?? "—")
                }
                .monospacedDigit()
            }

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

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value)
        }
    }

    private func watts(_ w: Double?) -> String {
        w.map { String(format: "%.1f W", $0) } ?? "—"
    }
}
