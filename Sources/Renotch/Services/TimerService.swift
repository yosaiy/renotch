import Foundation
import UserNotifications

final class TimerService: ObservableObject {
    @Published private(set) var storedTimer: StoredTimer?
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var completionPulse = 0
    @Published var selectedMode: PomodoroMode = .focus
    @Published var focusMinutes: Int = 25
    @Published var breakMinutes: Int = 5
    @Published var autoAdvance: Bool = true

    var onCompletion: ((PomodoroMode) -> Void)?

    private let defaults: UserDefaults
    private let persistenceKey = "virtualNotch.activeTimer.v1"
    private var ticker: Timer?
    private var scheduledNotificationID: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        restore()
        startTicker()
    }

    deinit {
        ticker?.invalidate()
    }

    var isActive: Bool { storedTimer != nil }
    var isPaused: Bool { storedTimer?.isPaused == true }
    var duration: TimeInterval { storedTimer?.duration ?? 0 }
    var currentMode: PomodoroMode { storedTimer?.resolvedMode ?? selectedMode }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return (1 - remaining / duration).clamped(to: 0...1)
    }

    func startPomodoro(
        focusMinutes: Int? = nil,
        breakMinutes: Int? = nil,
        autoAdvance: Bool = true,
        notify: Bool = true
    ) {
        let fMin = (focusMinutes ?? self.focusMinutes).clamped(to: 1...180)
        let bMin = (breakMinutes ?? self.breakMinutes).clamped(to: 1...60)
        self.focusMinutes = fMin
        self.breakMinutes = bMin
        self.autoAdvance = autoAdvance

        start(
            minutes: fMin,
            mode: .focus,
            focusMinutes: fMin,
            breakMinutes: bMin,
            autoAdvance: autoAdvance,
            notify: notify
        )
    }

    func start(
        minutes: Int,
        mode: PomodoroMode? = nil,
        focusMinutes: Int? = nil,
        breakMinutes: Int? = nil,
        autoAdvance: Bool? = nil,
        notify: Bool = true
    ) {
        start(
            seconds: TimeInterval(minutes * 60),
            mode: mode,
            focusMinutes: focusMinutes ?? self.focusMinutes,
            breakMinutes: breakMinutes ?? self.breakMinutes,
            autoAdvance: autoAdvance ?? self.autoAdvance,
            notify: notify
        )
    }

    func start(
        seconds: TimeInterval,
        mode: PomodoroMode? = nil,
        focusMinutes: Int? = nil,
        breakMinutes: Int? = nil,
        autoAdvance: Bool? = nil,
        notify: Bool = true
    ) {
        let safeDuration = seconds.clamped(to: 1...86_400)
        let activeMode = mode ?? selectedMode
        let fMin = focusMinutes ?? self.focusMinutes
        let bMin = breakMinutes ?? self.breakMinutes
        let shouldAuto = autoAdvance ?? self.autoAdvance

        selectedMode = activeMode
        if activeMode == .focus {
            self.focusMinutes = max(1, Int(ceil(safeDuration / 60)))
        } else {
            self.breakMinutes = max(1, Int(ceil(safeDuration / 60)))
        }

        storedTimer = StoredTimer(
            duration: safeDuration,
            endDate: Date().addingTimeInterval(safeDuration),
            remainingWhenPaused: nil,
            mode: activeMode,
            focusMinutes: fMin,
            breakMinutes: bMin,
            autoAdvance: shouldAuto
        )
        remaining = safeDuration
        persist()

        // Cancel any prior scheduled notification
        if let id = scheduledNotificationID {
            NotificationService.shared.cancelScheduled(id)
        }

        // Schedule OS-level notification so it fires even if app quits
        if notify {
            scheduledNotificationID = NotificationService.shared.scheduleTimerFinished(
                after: safeDuration,
                mode: activeMode,
                breakMinutes: bMin,
                autoAdvance: shouldAuto
            )
        } else {
            scheduledNotificationID = nil
        }
    }

    func togglePause() {
        guard var value = storedTimer else { return }
        if let pausedRemaining = value.remainingWhenPaused {
            value.endDate = Date().addingTimeInterval(pausedRemaining)
            value.remainingWhenPaused = nil
            // Re-schedule against remaining time on resume
            if let id = scheduledNotificationID {
                NotificationService.shared.cancelScheduled(id)
            }
            scheduledNotificationID = NotificationService.shared.scheduleTimerFinished(
                after: pausedRemaining,
                mode: value.resolvedMode,
                breakMinutes: value.resolvedBreakMinutes,
                autoAdvance: value.isAutoAdvance
            )
        } else {
            value.remainingWhenPaused = max(0, value.endDate.timeIntervalSinceNow)
            // Cancel pending notification while paused
            if let id = scheduledNotificationID {
                NotificationService.shared.cancelScheduled(id)
                scheduledNotificationID = nil
            }
        }
        storedTimer = value
        tick()
        persist()
    }

    func cancel() {
        storedTimer = nil
        remaining = 0
        defaults.removeObject(forKey: persistenceKey)
        if let id = scheduledNotificationID {
            NotificationService.shared.cancelScheduled(id)
            scheduledNotificationID = nil
        }
    }

    func skip() {
        let fMin = storedTimer?.resolvedFocusMinutes ?? focusMinutes
        let bMin = storedTimer?.resolvedBreakMinutes ?? breakMinutes
        let current = currentMode

        cancel()

        if current == .focus {
            selectedMode = .breakTime
            start(
                minutes: bMin,
                mode: .breakTime,
                focusMinutes: fMin,
                breakMinutes: bMin,
                autoAdvance: false,
                notify: true
            )
        } else {
            selectedMode = .focus
        }
    }

    static func formatted(_ interval: TimeInterval) -> String {
        let total = max(0, Int(ceil(interval)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func startTicker() {
        ticker = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.tick()
        }
        ticker?.tolerance = 0.1
    }

    private func tick() {
        guard let value = storedTimer else { return }
        if let pausedRemaining = value.remainingWhenPaused {
            remaining = pausedRemaining
            return
        }

        remaining = max(0, value.endDate.timeIntervalSinceNow)
        if remaining <= 0 {
            let finishedMode = value.resolvedMode
            let fMin = value.resolvedFocusMinutes
            let bMin = value.resolvedBreakMinutes
            let shouldAuto = value.isAutoAdvance

            storedTimer = nil
            defaults.removeObject(forKey: persistenceKey)
            completionPulse += 1

            if finishedMode == .focus && shouldAuto {
                // Auto-advance: automatically start the break timer
                selectedMode = .breakTime
                start(
                    minutes: bMin,
                    mode: .breakTime,
                    focusMinutes: fMin,
                    breakMinutes: bMin,
                    autoAdvance: false,
                    notify: true
                )
                onCompletion?(.focus)
            } else {
                selectedMode = (finishedMode == .focus) ? .breakTime : .focus
                onCompletion?(finishedMode)
            }
        }
    }

    private func persist() {
        guard let storedTimer,
              let data = try? JSONEncoder().encode(storedTimer) else { return }
        defaults.set(data, forKey: persistenceKey)
    }

    private func restore() {
        guard let data = defaults.data(forKey: persistenceKey),
              let value = try? JSONDecoder().decode(StoredTimer.self, from: data) else { return }

        focusMinutes = value.resolvedFocusMinutes
        breakMinutes = value.resolvedBreakMinutes
        autoAdvance = value.isAutoAdvance

        if value.isPaused || value.endDate > Date() {
            storedTimer = value
            selectedMode = value.resolvedMode
            remaining = value.remainingWhenPaused ?? value.endDate.timeIntervalSinceNow
        } else {
            defaults.removeObject(forKey: persistenceKey)
        }
    }
}


