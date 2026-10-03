import Foundation
import UserNotifications

/// Battery heat warning. Zappie only warns; it never stops charging (it stays read-only).
/// Warn at 40 °C, high at 45 °C; clear below 38 °C (high drops to warm below 43 °C).
/// Notify when the level rises, at most once per 30 minutes unless it rises further.
struct TemperatureWatch: Sendable {
    enum Level: Int, Comparable, Sendable {
        case normal, warm, hot
        static func < (a: Level, b: Level) -> Bool { a.rawValue < b.rawValue }
    }

    struct Message: Equatable, Sendable {
        var title: String
        var body: String
    }

    static let warmC = 40.0
    static let hotC = 45.0
    static let hotClearC = 43.0
    static let clearC = 38.0
    static let renotifyAfter: TimeInterval = 30 * 60

    private(set) var level: Level = .normal
    private var lastNotified: (date: Date, level: Level)?

    /// Returns the level to notify about, or nil.
    mutating func update(_ temperatureC: Double?, at now: Date) -> Level? {
        guard let t = temperatureC else { return nil }
        let next: Level
        if t >= Self.hotC {
            next = .hot
        } else if t >= Self.warmC {
            next = level == .hot && t >= Self.hotClearC ? .hot : .warm
        } else if t >= Self.clearC {
            next = level == .normal ? .normal : .warm
        } else {
            next = .normal
        }
        defer { level = next }
        guard next > level, next != .normal else { return nil }
        if let last = lastNotified, now.timeIntervalSince(last.date) < Self.renotifyAfter, next <= last.level {
            return nil
        }
        lastNotified = (now, next)
        return next
    }

    static func message(for level: Level, temperatureC: Double, charging: Bool) -> Message {
        let t = String(format: "%.1f °C", temperatureC)
        switch level {
        case .hot:
            return Message(
                title: "배터리 온도가 매우 높습니다 (\(t))",
                body: charging
                    ? "충전 중 배터리가 매우 뜨겁습니다. 충전기를 잠시 분리하거나 Mac을 서늘한 곳으로 옮겨 주세요."
                    : "배터리가 매우 뜨겁습니다. Mac을 서늘한 곳으로 옮기고 무거운 작업을 멈춰 주세요."
            )
        case .warm, .normal:
            return Message(
                title: "배터리 온도가 높습니다 (\(t))",
                body: (charging ? "충전 중 배터리가 뜨거워졌습니다." : "배터리가 뜨거워졌습니다.")
                    + " 통풍이 잘되는 곳에 두거나 무거운 작업을 잠시 줄여 주세요."
            )
        }
    }
}

/// Posts heat warnings as macOS notifications, if the user keeps them on in settings.
enum HeatNotifier {
    static func send(_ message: TemperatureWatch.Message) {
        guard UserDefaults.standard.object(forKey: AppSettings.heatAlertsKey) as? Bool ?? true else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = message.title
            content.body = message.body
            content.sound = .default
            center.add(UNNotificationRequest(identifier: "zappie.heat", content: content, trigger: nil))
        }
    }
}
