import AppKit
import Foundation
import UserNotifications

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    private var center: UNUserNotificationCenter? {
        guard Bundle.main.bundleIdentifier != nil else { return nil }
        return UNUserNotificationCenter.current()
    }

    private override init() {
        super.init()
        if Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().delegate = self
        }
    }

    func requestAuthorization() {
        center?.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // Deliver banners and sound even when app is frontmost or accessory
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge, .list])
    }

    func playTimerSound() {
        if let sound = NSSound(named: "Glass") ?? NSSound(named: "Ping") {
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    /// Schedule an OS-level notification so it fires even if the app quits or
    /// the Mac sleeps. Returns the request identifier (needed to cancel).
    @discardableResult
    func scheduleTimerFinished(
        after interval: TimeInterval,
        mode: PomodoroMode = .focus,
        breakMinutes: Int = 5,
        autoAdvance: Bool = true
    ) -> String {
        let id = "virtual-notch-timer-\(UUID().uuidString)"
        guard let center else { return id }

        let content = UNMutableNotificationContent()
        switch mode {
        case .focus:
            content.title = "专注时段结束"
            content.body = autoAdvance
                ? "专注完成，现在开始 \(breakMinutes) 分钟休息。"
                : "专注完成，休息一下吧。"
        case .breakTime:
            content.title = "休息结束"
            content.body = "准备好开始下一轮专注了吗？"
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(0.5, interval), repeats: false)
        )
        center.add(request)
        return id
    }

    func cancelScheduled(_ id: String) {
        guard !id.isEmpty else { return }
        center?.removePendingNotificationRequests(withIdentifiers: [id])
    }

    func timerFinished(mode: PomodoroMode = .focus, breakMinutes: Int = 5, autoAdvance: Bool = true) {
        playTimerSound()

        guard let center else { return }
        let content = UNMutableNotificationContent()
        switch mode {
        case .focus:
            content.title = "专注时段结束"
            content.body = autoAdvance
                ? "专注完成，现在开始 \(breakMinutes) 分钟休息。"
                : "专注完成，休息一下吧。"
        case .breakTime:
            content.title = "休息结束"
            content.body = "准备好开始下一轮专注了吗？"
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "virtual-notch-timer-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }
}

