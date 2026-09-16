import AppKit
import EventKit
import Foundation

enum CalendarAccessState: Equatable, Sendable {
    case notDetermined
    case requesting
    case authorized
    case denied
    case restricted
}

struct CalendarEventItem: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarTitle: String

    var shortTime: String {
        if isAllDay { return "全天" }
        return startDate.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(Locale(identifier: "zh_CN")))
    }

    var dayLabel: String {
        if Calendar.current.isDateInToday(startDate) { return "今天" }
        if Calendar.current.isDateInTomorrow(startDate) { return "明天" }
        return startDate.formatted(.dateTime.locale(Locale(identifier: "zh_CN")).weekday(.abbreviated).month(.abbreviated).day())
    }
}

@MainActor
final class AppleCalendarService: ObservableObject {
    @Published private(set) var accessState: CalendarAccessState = .notDetermined
    @Published private(set) var events: [CalendarEventItem] = []
    @Published private(set) var errorMessage: String?

    private let eventStore = EKEventStore()
    private var storeObserver: NSObjectProtocol?
    private var activationObserver: NSObjectProtocol?

    var nextEvent: CalendarEventItem? { events.first }

    var compactStatus: String {
        switch accessState {
        case .notDetermined: return "点击连接苹果日历"
        case .requesting: return "正在请求权限…"
        case .denied, .restricted: return "请在系统设置中开启访问权限"
        case .authorized:
            guard let nextEvent else { return "未来 14 天没有日程" }
            return "\(nextEvent.dayLabel) · \(nextEvent.shortTime)"
        }
    }

    init(notificationCenter: NotificationCenter = .default) {
        refreshAuthorizationState()
        storeObserver = notificationCenter.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        // TCC toggles made in System Settings do not post .EKEventStoreChanged,
        // so re-read the authorization status whenever the app comes back to the
        // front. This keeps a granted/denied state change reflected immediately
        // without requiring the user to reopen the panel.
        activationObserver = notificationCenter.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        if accessState == .authorized { refresh() }
    }

    deinit {
        let center = NotificationCenter.default
        if let storeObserver { center.removeObserver(storeObserver) }
        if let activationObserver { center.removeObserver(activationObserver) }
    }

    func requestAccess() {
        guard accessState != .requesting else { return }
        accessState = .requesting
        errorMessage = nil

        // Bring the accessory app forward so the system consent sheet cannot
        // appear behind the currently active application.
        NSApp.activate(ignoringOtherApps: true)

        let completion: @Sendable (Bool, Error?) -> Void = { [weak self] granted, error in
            Task { @MainActor in
                if let error {
                    self?.errorMessage = error.localizedDescription
                } else if !granted {
                    // No error but no grant either: the system considers access
                    // denied (e.g. stale TCC entry). Point the user to Settings.
                    self?.errorMessage = "日历访问已关闭，请在系统设置中开启。"
                }
                self?.refreshAuthorizationState()
                self?.refresh()
            }
        }

        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents(completion: completion)
        } else {
            eventStore.requestAccess(to: .event, completion: completion)
        }
    }

    func refresh() {
        refreshAuthorizationState()
        guard accessState == .authorized else {
            events = []
            return
        }

        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 14, to: start) ?? start.addingTimeInterval(14 * 86_400)
        events = queriedEvents(from: start, to: end, limit: 12)
        errorMessage = nil
    }

    func events(from startDate: Date, to endDate: Date) -> [CalendarEventItem] {
        refreshAuthorizationState()
        guard accessState == .authorized else { return [] }
        return queriedEvents(from: startDate, to: endDate)
    }

    func openCalendar() {
        guard let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") else {
            return
        }
        NSWorkspace.shared.openApplication(
            at: applicationURL,
            configuration: NSWorkspace.OpenConfiguration()
        )
    }

    func openCalendarPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func refreshAuthorizationState() {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .notDetermined:
            accessState = .notDetermined
        case .restricted:
            accessState = .restricted
        case .denied:
            accessState = .denied
        case .fullAccess:
            accessState = .authorized
        case .writeOnly:
            accessState = .denied
        @unknown default:
            accessState = .denied
        }
    }

    private func queriedEvents(
        from startDate: Date,
        to endDate: Date,
        limit: Int? = nil
    ) -> [CalendarEventItem] {
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )
        let matched = eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
        let selected = limit.map { Array(matched.prefix($0)) } ?? matched

        return selected.map { event in
            CalendarEventItem(
                id: event.eventIdentifier ?? "\(event.title ?? "event")-\(event.startDate.timeIntervalSince1970)",
                title: event.title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "未命名日程",
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                calendarTitle: event.calendar.title
            )
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
