import SwiftUI

struct CalendarView: View {
    @ObservedObject var service: AppleCalendarService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var displayedMonth = Date()
    @State private var selectedDate = Date()
    @State private var monthEvents: [CalendarEventItem] = []

    private let calendar = Calendar.current

    var body: some View {
        Group {
            switch service.accessState {
            case .notDetermined:
                permissionState
            case .requesting:
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Connecting to Apple Calendar…")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.notchMuted)
                }
            case .denied, .restricted:
                deniedState
            case .authorized:
                calendarContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 4)
        .onAppear {
            service.refresh()
            loadMonthEvents()
        }
        .onChange(of: service.accessState) { accessState in
            if accessState == .authorized { loadMonthEvents() }
        }
    }

    private var permissionState: some View {
        CalendarPromptView(
            icon: "calendar.badge.plus",
            title: "Connect Apple Calendar",
            message: "Display your local macOS calendars and upcoming schedule here.",
            actionTitle: "Allow Access",
            action: service.requestAccess
        )
    }

    private var deniedState: some View {
        CalendarPromptView(
            icon: "calendar.badge.exclamationmark",
            title: "Calendar access is off",
            message: "Enable Calendar access for Re:notch in System Settings to view your schedule.",
            actionTitle: "Open Settings",
            action: service.openCalendarPrivacySettings
        )
    }

    private var calendarContent: some View {
        HStack(spacing: 14) {
            monthView
                .frame(minWidth: 186, idealWidth: 238, maxWidth: 252)

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)
                .padding(.vertical, 2)

            agendaView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Month Panel (Open Obsidian Ground)

    private var monthView: some View {
        VStack(spacing: 4) {
            monthHeader
                .frame(height: 20)
            weekdayHeader
                .frame(height: 11)
            dayGrid
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var monthHeader: some View {
        HStack(alignment: .center, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(monthName)
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)
                Text(monthYear)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.notchMuted)
            }

            Spacer(minLength: 4)

            Button("Today") { showToday() }
                .font(.system(size: 9, weight: .semibold))
                .buttonStyle(.plain)
                .foregroundStyle(Color.notchAccent)
                .help("Jump to today")
                .accessibilityLabel("Jump to today")

            CalendarIconButton(icon: "chevron.left", label: "Previous month") {
                changeMonth(by: -1)
            }
            CalendarIconButton(icon: "chevron.right", label: "Next month") {
                changeMonth(by: 1)
            }
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 2) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Color.notchMuted)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private var dayGrid: some View {
        VStack(spacing: 1.5) {
            ForEach(0..<6, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<7, id: \.self) { column in
                        let index = row * 7 + column
                        if index < monthDays.count, let date = monthDays[index] {
                            CalendarDayButton(
                                date: date,
                                isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                                isToday: calendar.isDateInToday(date),
                                eventCount: eventCount(on: date)
                            ) {
                                selectedDate = date
                            }
                        } else {
                            Color.clear
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: selectedDate)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: displayedMonth)
    }

    // MARK: - Agenda Panel

    private var agendaView: some View {
        VStack(alignment: .leading, spacing: 0) {
            agendaHeader
                .padding(.bottom, 6)

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            if selectedDayEvents.isEmpty {
                emptyDayState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(selectedDayEvents.enumerated()), id: \.element.id) { index, event in
                            if index > 0 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.06))
                                    .frame(height: 1)
                            }
                            CalendarAgendaRow(event: event)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var agendaHeader: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(selectedDate.formatted(.dateTime.weekday(.wide)))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(agendaSubtitle)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Color.notchMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            CalendarIconButton(icon: "arrow.clockwise", label: "Refresh events") {
                service.refresh()
                loadMonthEvents()
            }
            CalendarIconButton(icon: "arrow.up.right", label: "Open Apple Calendar") {
                service.openCalendar()
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var emptyDayState: some View {
        VStack(alignment: .leading, spacing: 3) {
            Spacer()
            Text("No events on this day")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))
            Text("Open Apple Calendar to schedule something.")
                .font(.system(size: 9.5, weight: .regular))
                .foregroundStyle(Color.notchMuted)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Derived Values

    private var startOfDisplayedMonth: Date {
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        return calendar.date(from: components) ?? displayedMonth
    }

    private var monthName: String {
        startOfDisplayedMonth.formatted(.dateTime.month(.wide))
    }

    private var monthYear: String {
        startOfDisplayedMonth.formatted(.dateTime.year())
    }

    private var agendaSubtitle: String {
        let base = selectedDate.formatted(.dateTime.month(.wide).day())
        let count = selectedDayEvents.count
        guard count > 0 else { return base }
        return "\(base) · \(count) \(count == 1 ? "event" : "events")"
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let start = max(0, min(symbols.count - 1, calendar.firstWeekday - 1))
        return Array(symbols[start...] + symbols[..<start])
    }

    private var monthDays: [Date?] {
        guard let dayRange = calendar.range(of: .day, in: .month, for: startOfDisplayedMonth) else {
            return Array(repeating: nil, count: 42)
        }
        let weekday = calendar.component(.weekday, from: startOfDisplayedMonth)
        let leadingBlanks = (weekday - calendar.firstWeekday + 7) % 7
        var days = Array<Date?>(repeating: nil, count: leadingBlanks)
        days.append(contentsOf: dayRange.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: startOfDisplayedMonth)
        })
        days.append(contentsOf: Array(repeating: nil, count: max(0, 42 - days.count)))
        return Array(days.prefix(42))
    }

    private var selectedDayEvents: [CalendarEventItem] {
        events(on: selectedDate)
    }

    private func events(on date: Date) -> [CalendarEventItem] {
        monthEvents.filter { occurs($0, on: date) }
    }

    private func eventCount(on date: Date) -> Int {
        events(on: date).count
    }

    private func occurs(_ event: CalendarEventItem, on date: Date) -> Bool {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)
        return event.startDate < dayEnd && event.endDate > dayStart
    }

    // MARK: - Actions

    private func changeMonth(by offset: Int) {
        guard let month = calendar.date(byAdding: .month, value: offset, to: startOfDisplayedMonth) else {
            return
        }
        displayedMonth = month
        selectedDate = month
        loadMonthEvents()
    }

    private func showToday() {
        displayedMonth = Date()
        selectedDate = Date()
        loadMonthEvents()
    }

    private func loadMonthEvents() {
        let start = startOfDisplayedMonth
        guard let end = calendar.date(byAdding: .month, value: 1, to: start) else {
            monthEvents = []
            return
        }
        monthEvents = service.events(from: start, to: end)
    }
}

// MARK: - Day Button

private struct CalendarDayButton: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let eventCount: Int
    let action: () -> Void

    @State private var isHovering = false

    private var hasEvents: Bool { eventCount > 0 }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(fillColor)
                Circle()
                    .stroke(ringColor, lineWidth: 1)

                Text(date.formatted(.dateTime.day()))
                    .font(.system(size: 9.5, weight: isSelected || isToday ? .bold : .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(textColor)

                if hasEvents {
                    VStack {
                        Spacer()
                        Circle()
                            .fill(isSelected ? Color.black.opacity(0.75) : Color.notchAccent)
                            .frame(width: 2.5, height: 2.5)
                            .padding(.bottom, 1)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .help(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var fillColor: Color {
        if isSelected { return Color.notchAccent }
        if isHovering { return Color.white.opacity(0.09) }
        return Color.clear
    }

    private var ringColor: Color {
        if isToday && !isSelected { return Color.notchAccent.opacity(0.8) }
        return Color.clear
    }

    private var textColor: Color {
        if isSelected { return Color.black }
        if isToday { return Color.notchAccent }
        return Color.white.opacity(0.88)
    }

    private var accessibilityText: String {
        var parts = [date.formatted(.dateTime.weekday(.wide).month(.wide).day())]
        if isToday { parts.append("today") }
        if hasEvents {
            parts.append("\(eventCount) \(eventCount == 1 ? "event" : "events")")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Icon Button

private struct CalendarIconButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 8.5, weight: .bold))
                .foregroundStyle(isHovering ? .white : Color.notchMuted)
                .frame(width: 19, height: 19)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.white.opacity(isHovering ? 0.12 : 0.06))
                )
                .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(NotchPressButtonStyle())
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .help(label)
        .accessibilityLabel(label)
    }
}

// MARK: - Editorial Agenda Row (Clean Time Column, No Decorative Color Stripe)

private struct CalendarAgendaRow: View {
    let event: CalendarEventItem
    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(event.shortTime)
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(event.isAllDay ? Color.notchAccent : Color.notchMuted)
                .frame(width: 44, alignment: .leading)
                .lineLimit(1)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1.5) {
                Text(event.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(event.calendarTitle)
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(Color.notchMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(isHovering ? 0.055 : 0.0))
        )
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let time = event.isAllDay ? "all day" : "at \(event.shortTime)"
        return "\(event.title), \(event.calendarTitle), \(time)"
    }
}

// MARK: - Permission / Denied Prompt

private struct CalendarPromptView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.notchAccent.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.notchAccent.opacity(0.24), lineWidth: 0.8)
                    )
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.notchAccent)
            }
            .frame(width: 44, height: 44)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(.white)
                Text(message)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(Color.notchMuted)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Button(action: action) {
                Text(actionTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.notchAccent.opacity(isHovered ? 1.0 : 0.92))
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(NotchPressButtonStyle())
            .onHover { isHovered = $0 }
            .animation(.easeOut(duration: 0.14), value: isHovered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }
}
