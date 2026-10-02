import SwiftUI

/// Design tokens from `docs/SPEC.md` §4 (dark mode).
enum Theme {
    static let background = Color(hex: 0x1E1E20)
    static let card = Color(hex: 0x2A2A2D)
    static let border = Color(hex: 0x3A3A3D)
    static let text = Color(hex: 0xF5F5F7)
    static let secondaryText = Color(hex: 0xA8A8AE)
    static let adapter = Color(hex: 0x967CEC)   // lavender
    static let battery = Color(hex: 0x0FAA7B)   // emerald
    static let inactive = Color(hex: 0x48484A)
    static let loss = Color(hex: 0x8E8E93)

    static let buttonText = Color(hex: 0x140F2A)
    static let sidebar = Color(hex: 0x232326)
    static let sidebarText = Color(hex: 0xD1D1D6)
    static let divider = Color(hex: 0x2E2E31)
    static let systemLine = Color(hex: 0xD1D1D6)

    static func color(_ tint: Tint) -> Color {
        switch tint {
        case .adapter: adapter
        case .battery: battery
        case .inactive: inactive
        }
    }

    /// Badge foreground: a lighter shade of the accent for contrast on the 16% fill.
    static func badgeText(_ tint: Tint) -> Color {
        switch tint {
        case .adapter: Color(hex: 0xC4B5FD)
        case .battery: Color(hex: 0x6EE7B7)
        case .inactive: secondaryText
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
