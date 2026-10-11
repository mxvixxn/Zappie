import AppKit
import SwiftUI

enum MainSection: String, CaseIterable, Identifiable {
    case overview = "개요"
    case history = "기록"
    case adapter = "어댑터"
    case battery = "배터리"
    case settings = "설정"

    var id: Self { self }
}

struct MainWindow: View {
    let monitor: PowerMonitor
    var scrolls = true
    @AppStorage(AppSettings.sectionKey) private var section: MainSection = .overview

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(Theme.divider).frame(width: 1)
            Group {
                switch section {
                case .overview: OverviewView(monitor: monitor, scrolls: scrolls)
                case .history: HistoryTab(monitor: monitor)
                case .adapter: AdapterTab(monitor: monitor)
                case .battery: BatteryTab(monitor: monitor)
                case .settings: SettingsTab(monitor: monitor)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.background)
        .foregroundStyle(Theme.text)
        .monospacedDigit()
        .preferredColorScheme(.dark)
        .frame(minWidth: 960, minHeight: 760)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(MainSection.allCases) { item in
                let selected = item == section
                Button {
                    section = item
                } label: {
                    Text(item.rawValue)
                        .font(.system(size: 13, weight: selected ? .semibold : .regular))
                        .foregroundStyle(selected ? Theme.text : Theme.sidebarText)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                        .background(selected ? Theme.adapter.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 16)
        .frame(width: 200)
        .background(Theme.sidebar)
    }
}

/// The main window's scene content. SwiftUI keeps a closed `Window`'s views alive, and they kept
/// following the monitor's one-second updates: after opening and closing the window once, the
/// app idled at ~3% CPU instead of ~1%. Draw nothing while the window is closed.
struct MainWindowScene: View {
    let monitor: PowerMonitor
    @State private var isOpen = true

    var body: some View {
        Group {
            if isOpen {
                MainWindow(monitor: monitor)
            } else {
                Theme.background.frame(minWidth: 960, minHeight: 760)
            }
        }
        .background(WindowLifecycle(isOpen: $isOpen))
    }
}

/// Reports the hosting window closing (`willClose`) and becoming visible again (occlusion),
/// which also covers SwiftUI reusing the closed window when it is reopened.
private struct WindowLifecycle: NSViewRepresentable {
    @Binding var isOpen: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { context.coordinator.attach(to: view.window) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.isOpen = $isOpen
        if context.coordinator.window == nil {
            DispatchQueue.main.async { context.coordinator.attach(to: view.window) }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(isOpen: $isOpen) }

    @MainActor
    final class Coordinator {
        var isOpen: Binding<Bool>
        private(set) weak var window: NSWindow?
        nonisolated(unsafe) private var observers: [NSObjectProtocol] = []

        init(isOpen: Binding<Bool>) { self.isOpen = isOpen }

        func attach(to window: NSWindow?) {
            guard let window, self.window == nil else { return }
            self.window = window
            let center = NotificationCenter.default
            observers.append(center.addObserver(forName: NSWindow.willCloseNotification, object: window,
                                                queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.set(false) }
            })
            observers.append(center.addObserver(forName: NSWindow.didChangeOcclusionStateNotification,
                                                object: window, queue: .main) { [weak self, weak window] _ in
                MainActor.assumeIsolated {
                    if window?.occlusionState.contains(.visible) == true { self?.set(true) }
                }
            })
        }

        private func set(_ open: Bool) {
            if isOpen.wrappedValue != open { isOpen.wrappedValue = open }
        }

        deinit {
            observers.forEach(NotificationCenter.default.removeObserver)
        }
    }
}
