import Foundation
import ServiceManagement

enum MenuBarLabelStyle: String, CaseIterable, Identifiable {
    case watts
    case iconOnly

    var id: Self { self }

    var title: String {
        switch self {
        case .watts: "아이콘 + 전력"
        case .iconOnly: "아이콘만"
        }
    }

    var showsText: Bool { self == .watts }
}

/// `@AppStorage` keys and choices shared by the views.
enum AppSettings {
    static let pollIntervalKey = "pollIntervalSeconds"
    static let labelStyleKey = "menuBarLabelStyle"
    static let sectionKey = "mainSection"

    static let pollIntervals = [1, 2, 5]
}

/// Login item for the app itself via `SMAppService.mainApp` (macOS 13+).
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Throws when the system refuses, e.g. an unsigned build or one run from a temporary location.
    static func set(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
