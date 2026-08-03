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
                .frame(width: 258)

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)
                .padding(.vertical, 3)

            agendaView
        }
    }

    private var monthView: some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                Text(monthTitle)
                    .font(.system(size: 12, weight: .bold, design: .rounded))

                Spacer()

                Button("Today") { showToday() }
                    .font(.system(size: 8.5, weight: .semibold))
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color.notchAccent)

                monthButton(icon: "chevron.left", offset: -1)
                monthButton(icon: "chevron.right", offset: 1)
            }
            .frame(height: 22)

            HStack(spacing: 2) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol.uppercased())
                        .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.notchMuted)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 12)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7),
                spacing: 2
            ) {
                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                    if let date {
                        CalendarDayButton(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            hasEvents: hasEvents(on: date)
                        ) {
                            selectedDate = date
                        }
                    } else {
                        Color.clear
                            .frame(height: 19)
                    }
                }
            }
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
    }

    private var agendaView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(selectedDate.formatted(.dateTime.weekday(.wide)))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(0.5)
                        .foregroundStyle(Color.notchMuted)
                    Text(selectedDate.formatted(.dateTime.month(.wide).day()))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }

                Spacer()

                Button {
                    service.refresh()
                    loadMonthEvents()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh events")

                Button(action: service.openCalendar) {
                    Image(systemName: "arrow.up.right")
                }
                .help("Open Apple Calendar")
            }
            .font(.system(size: 10, weight: .semibold))
            .buttonStyle(.borderless)

            if selectedDayEvents.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.notchAccent)
                    Text("No events on this day")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.notchMuted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private var startOfDisplayedMonth: Date {
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        return calendar.date(from: components) ?? displayedMonth
    }

    private var monthTitle: String {
        startOfDisplayedMonth.formatted(.dateTime.month(.wide).year())
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
        monthEvents.filter { occurs($0, on: selectedDate) }
    }

    private func hasEvents(on date: Date) -> Bool {
        monthEvents.contains { occurs($0, on: date) }
    }

    private func occurs(_ event: CalendarEventItem, on date: Date) -> Bool {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)
        return event.startDate < dayEnd && event.endDate > dayStart
    }

    private func monthButton(icon: String, offset: Int) -> some View {
        Button {
            guard let month = calendar.date(byAdding: .month, value: offset, to: startOfDisplayedMonth) else {
                return
            }
            displayedMonth = month
            selectedDate = month
            loadMonthEvents()
        } label: {
            Image(systemName: icon)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.white.opacity(0.06)))
        }
        .buttonStyle(.plain)
        .font(.system(size: 8, weight: .bold))
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

private struct CalendarDayButton: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasEvents: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                Text(date.formatted(.dateTime.day()))
                    .font(.system(size: 9, weight: isSelected || isToday ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.88))

                if hasEvents {
                    Circle()
                        .fill(isSelected ? Color.black.opacity(0.7) : Color.notchAccent)
                        .frame(width: 2.5, height: 2.5)
                        .offset(y: -1.5)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 19)
            .background(
                Circle()
                    .fill(isSelected ? Color.notchAccent : Color.clear)
                    .overlay(
                        Circle()
                            .stroke(isToday && !isSelected ? Color.notchAccent.opacity(0.8) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct CalendarAgendaRow: View {
    let event: CalendarEventItem

    var body: some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 1, green: 0.42, blue: 0.38))
                .frame(width: 3, height: 25)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Text(event.calendarTitle)
                    .font(.system(size: 8))
                    .foregroundStyle(Color.notchMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Text(event.shortTime)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.notchMuted)
        }
        .padding(.horizontal, 8)
        .frame(height: 34)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}

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
    }
}
