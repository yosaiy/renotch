import SwiftUI

struct CalendarView: View {
    @ObservedObject var service: AppleCalendarService

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
                ProgressView("Connecting to Apple Calendar…")
                    .controlSize(.small)
            case .denied, .restricted:
                deniedState
            case .authorized:
                calendarContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 8)
        .onAppear {
            service.refresh()
            loadMonthEvents()
        }
        .onChange(of: service.accessState) { accessState in
            if accessState == .authorized { loadMonthEvents() }
        }
    }

    private var permissionState: some View {
        CalendarMessageCard(
            icon: "calendar.badge.plus",
            title: "Connect Apple Calendar",
            message: "Show your calendar and events already synced on this Mac.",
            actionTitle: "Allow Access",
            action: service.requestAccess
        )
    }

    private var deniedState: some View {
        CalendarMessageCard(
            icon: "calendar.badge.exclamationmark",
            title: "Calendar access is off",
            message: "Enable Calendar access in System Settings to show your dates and events.",
            actionTitle: "Open Settings",
            action: service.openCalendarPrivacySettings
        )
    }

    private var calendarContent: some View {
        HStack(spacing: 12) {
            monthView
                .frame(minWidth: 190, idealWidth: 258, maxWidth: 268)

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)
                .padding(.vertical, 3)

            agendaView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Month panel

    /// Fills whatever height the notch surface gives it: header and weekday
    /// rows stay fixed while the day grid absorbs the remaining space, so the
    /// calendar is never taller than its container.
    private var monthView: some View {
        VStack(spacing: 4) {
            monthHeader
                .frame(height: 20)
            weekdayHeader
                .frame(height: 10)
            dayGrid
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(9)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
    }

    private var monthHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(monthName)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .accessibilityAddTraits(.isHeader)
            Text(monthYear)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.notchMuted)

            Spacer()

            Button("Today") { showToday() }
                .font(.system(size: 8.5, weight: .semibold))
                .buttonStyle(.borderless)
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
                Text(symbol.uppercased())
                    .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.notchMuted)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    /// Six evenly distributed rows instead of a fixed-height LazyVGrid, so the
    /// grid stretches or shrinks with the notch height without clipping.
    private var dayGrid: some View {
        VStack(spacing: 2) {
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
        .animation(.easeOut(duration: 0.15), value: selectedDate)
        .animation(.easeOut(duration: 0.15), value: displayedMonth)
    }

    // MARK: - Agenda panel

    private var agendaView: some View {
        VStack(alignment: .leading, spacing: 7) {
            agendaHeader

            if selectedDayEvents.isEmpty {
                emptyDayState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 5) {
                        ForEach(selectedDayEvents) { event in
                            CalendarAgendaRow(event: event)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var agendaHeader: some View {
        HStack(spacing: 9) {
            dateBlock

            VStack(alignment: .leading, spacing: 1) {
                Text(selectedDate.formatted(.dateTime.weekday(.wide)))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                Text(agendaSubtitle)
                    .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.notchMuted)
                    .lineLimit(1)
            }

            Spacer()

            CalendarIconButton(icon: "arrow.clockwise", label: "Refresh events") {
                service.refresh()
                loadMonthEvents()
            }
            CalendarIconButton(icon: "arrow.up.right", label: "Open Apple Calendar") {
                service.openCalendar()
            }
        }
        .font(.system(size: 10, weight: .semibold))
        .accessibilityElement(children: .contain)
    }

    /// Mini calendar tile for the selected day: weekday abbreviation stacked
    /// over a large day number, mirroring the macOS Calendar date badge.
    private var dateBlock: some View {
        VStack(spacing: 0) {
            Text(selectedDate.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                .font(.system(size: 6.5, weight: .bold, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(Color.notchAccent)
            Text(selectedDate.formatted(.dateTime.day()))
                .font(.system(size: 15, weight: .bold, design: .rounded))
        }
        .frame(width: 32, height: 32)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.notchAccent.opacity(0.12))
        )
        .accessibilityHidden(true)
    }

    private var emptyDayState: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color.notchAccent.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.notchAccent)
            }
            Text("No events on this day")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            Text("Nothing scheduled — enjoy the free time.")
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(Color.notchMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Derived values

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
        return "\(base) · \(count) event\(count == 1 ? "" : "s")"
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

// MARK: - Day button

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
                    .font(.system(size: 9, weight: isSelected || isToday ? .bold : .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(textColor)

                if hasEvents {
                    VStack {
                        Spacer()
                        Circle()
                            .fill(isSelected ? Color.black.opacity(0.7) : Color.notchAccent)
                            .frame(width: 2.5, height: 2.5)
                            .padding(.bottom, 1.5)
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
        if isHovering { return Color.white.opacity(0.08) }
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
            parts.append("\(eventCount) event\(eventCount == 1 ? "" : "s")")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Icon button with hover state

private struct CalendarIconButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(isHovering ? Color.white.opacity(0.92) : Color.white.opacity(0.6))
                .frame(width: 16, height: 16)
                .background(Circle().fill(Color.white.opacity(isHovering ? 0.1 : 0.06)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .help(label)
        .accessibilityLabel(label)
    }
}

// MARK: - Agenda row

private struct CalendarAgendaRow: View {
    let event: CalendarEventItem

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 1, green: 0.42, blue: 0.38))
                .frame(width: 3)
                .padding(.vertical, 7)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Text(event.calendarTitle)
                    .font(.system(size: 8))
                    .foregroundStyle(Color.notchMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Text(event.shortTime)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(event.isAllDay ? Color.notchAccent : Color.white.opacity(0.7))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.white.opacity(0.06)))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 8)
        .frame(height: 36)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(isHovering ? 0.08 : 0.05))
        )
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
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

// MARK: - Message card

private struct CalendarMessageCard: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Color.notchAccent)
                .frame(width: 54, height: 54)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.notchAccent.opacity(0.1)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text(message)
                    .font(.system(size: 9.5))
                    .foregroundStyle(Color.notchMuted)
            }
            Spacer()
            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
                .tint(Color.notchAccent)
                .foregroundStyle(.black)
                .controlSize(.small)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 15).fill(Color.white.opacity(0.045)))
        .accessibilityElement(children: .contain)
    }
}
