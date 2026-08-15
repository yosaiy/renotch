import UserNotifications

final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Schedule an OS-level notification so it fires even if the app quits or
    /// the Mac sleeps. Returns the request identifier (needed to cancel).
    @discardableResult
    func scheduleTimerFinished(after interval: TimeInterval) -> String {
        let id = "virtual-notch-timer-\(UUID().uuidString)"
        let content = UNMutableNotificationContent()
        content.title = "Timer complete"
        content.body = "Your Re:notch timer has finished."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(0.5, interval), repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
        return id
    }

    func cancelScheduled(_ id: String) {
        guard !id.isEmpty else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    func timerFinished() {
        let content = UNMutableNotificationContent()
        content.title = "Timer complete"
        content.body = "Your Re:notch timer has finished."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "virtual-notch-timer-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
