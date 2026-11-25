import Foundation
import UserNotifications

@MainActor
protocol Notifying: AnyObject {
    func requestAuthorization()
    func postTimerEnded()
    func postBatteryStopped(level: Int)
}

@MainActor
final class Notifier: Notifying {
    private let isAvailable = Bundle.main.bundleIdentifier != nil
    private static let timerIdentifier = "prism.lumos.timer"
    private static let batteryIdentifier = "prism.lumos.battery"

    func requestAuthorization() {
        guard isAvailable else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func postTimerEnded() {
        post(
            title: LumosStrings.notificationTimerTitle,
            body: LumosStrings.notificationTimerBody,
            identifier: Self.timerIdentifier
        )
    }

    func postBatteryStopped(level: Int) {
        post(
            title: LumosStrings.notificationBatteryTitle,
            body: LumosStrings.notificationBatteryBody(level),
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
