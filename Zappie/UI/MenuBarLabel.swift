import AppKit
import SwiftUI

struct MenuBarLabel: View {
    let monitor: PowerMonitor
    @AppStorage(AppSettings.labelStyleKey) private var style = MenuBarLabelStyle.watts

    var body: some View {
        if let snapshot = monitor.snapshot, let state = monitor.state {
            let item = PowerPresentation(snapshot: snapshot, state: state).menuBar
            HStack(spacing: 4) {
                Image(nsImage: Self.coloredSymbol(item.icon, tint: item.tint))
                if style.showsText {
                    Text(item.text).monospacedDigit()
                }
            }
        } else {
            Image(systemName: "bolt.fill")
        }
    }

    /// Menu bar images are templates (monochrome) unless built as a non-template NSImage.
    private static func coloredSymbol(_ icon: PowerPresentation.MenuBar.Icon, tint: Tint) -> NSImage {
        let name = switch icon {
        case .bolt: "bolt.fill"
        case .plug: "powerplug.fill"
        case .battery: "battery.75"
        }
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            .applying(.init(paletteColors: [NSColor(Theme.color(tint))]))
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) ?? NSImage()
        image.isTemplate = false
        return image
    }
}
