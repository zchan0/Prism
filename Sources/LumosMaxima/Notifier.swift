import Foundation
import UserNotifications

@MainActor
final class Notifier {
    private let isAvailable = Bundle.main.bundleIdentifier != nil
    private static let timerIdentifier = "lumosMaxima.timer"
    private static let batteryIdentifier = "lumosMaxima.battery"

    func requestAuthorization() {
        guard isAvailable else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func postTimerEnded() {
        post(
            title: Strings.notificationTimerTitle,
            body: Strings.notificationTimerBody,
            identifier: Self.timerIdentifier
        )
    }

    func postBatteryStopped(level: Int) {
        post(
            title: Strings.notificationBatteryTitle,
            body: Strings.notificationBatteryBody(level),
            identifier: Self.batteryIdentifier
        )
    }

    private func post(title: String, body: String, identifier: String) {
        guard isAvailable else {
            print("notification: \(title) — \(body)")
            return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
