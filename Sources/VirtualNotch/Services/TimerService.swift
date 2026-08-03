import Foundation

final class TimerService: ObservableObject {
    @Published private(set) var storedTimer: StoredTimer?
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var completionPulse = 0

    var onCompletion: (() -> Void)?

    private let defaults: UserDefaults
    private let persistenceKey = "virtualNotch.activeTimer.v1"
    private var ticker: Timer?

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

    var progress: Double {
        guard duration > 0 else { return 0 }
        return (1 - remaining / duration).clamped(to: 0...1)
    }

    func start(minutes: Int) {
        start(seconds: TimeInterval(minutes * 60))
    }

    func start(seconds: TimeInterval) {
        let safeDuration = seconds.clamped(to: 1...86_400)
        storedTimer = StoredTimer(
            duration: safeDuration,
            endDate: Date().addingTimeInterval(safeDuration),
            remainingWhenPaused: nil
        )
        remaining = safeDuration
        persist()
    }

    func togglePause() {
        guard var value = storedTimer else { return }
        if let pausedRemaining = value.remainingWhenPaused {
            value.endDate = Date().addingTimeInterval(pausedRemaining)
            value.remainingWhenPaused = nil
        } else {
            value.remainingWhenPaused = max(0, value.endDate.timeIntervalSinceNow)
        }
        storedTimer = value
        tick()
        persist()
    }

    func cancel() {
        storedTimer = nil
        remaining = 0
        defaults.removeObject(forKey: persistenceKey)
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
            storedTimer = nil
            defaults.removeObject(forKey: persistenceKey)
            completionPulse += 1
            onCompletion?()
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

        if value.isPaused || value.endDate > Date() {
            storedTimer = value
            remaining = value.remainingWhenPaused ?? value.endDate.timeIntervalSinceNow
        } else {
            defaults.removeObject(forKey: persistenceKey)
        }
    }
}
