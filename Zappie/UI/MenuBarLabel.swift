import AppKit
import SwiftUI

struct MenuBarLabel: View {
    let monitor: PowerMonitor
    @AppStorage(AppSettings.labelStyleKey) private var style = MenuBarLabelStyle.watts

    var body: some View {
        if let item = monitor.menuBarItem {
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

    private static var imageCache: [String: NSImage] = [:]

    /// Menu bar images are templates (monochrome) unless built as a non-template NSImage.
    /// Cached so an unchanged icon is not rebuilt on every refresh.
    private static func coloredSymbol(_ icon: PowerPresentation.MenuBar.Icon, tint: Tint) -> NSImage {
        let key = "\(icon)-\(tint)"
        if let cached = imageCache[key] { return cached }
        let image = makeSymbol(icon, tint: tint)
        imageCache[key] = image
        return image
    }

    private static func makeSymbol(_ icon: PowerPresentation.MenuBar.Icon, tint: Tint) -> NSImage {
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
