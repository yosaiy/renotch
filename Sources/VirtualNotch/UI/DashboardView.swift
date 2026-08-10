import SwiftUI

/// Unified dashboard: every section lives on one continuous surface as a slim
/// row, separated by hairline dividers instead of individual cards.
struct DashboardView: View {
    @ObservedObject var music: MusicService
    @ObservedObject var activity: DeveloperActivityService
    @ObservedObject var shelf: ShelfStore
    @ObservedObject var timer: TimerService
    @ObservedObject var todos: TodoStore
    @ObservedObject var calendar: AppleCalendarService
    let navigate: (NotchSection) -> Void

    var body: some View {
        VStack(spacing: 0) {
            rowsView
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var rowsView: some View {
        let rows: [(DashboardRow.RowData, AnyView)] = [
            (musicRowData, AnyView(musicControls)),
            (codingRowData, AnyView(EmptyView())),
            (shelfRowData, AnyView(EmptyView())),
            (timerRowData, AnyView(timerProgress)),
            (todosRowData, AnyView(EmptyView())),
            (calendarRowData, AnyView(EmptyView()))
        ]

        ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
            DashboardRow(data: row.0, controls: row.1) {
                navigate(row.0.section)
            }
            if index < rows.count - 1 {
                dashboardDivider
            }
        }
    }

    private var dashboardDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 0.5)
            .padding(.leading, 31)
    }

    // MARK: - Row data

    private var musicRowData: DashboardRow.RowData {
        DashboardRow.RowData(
            section: .music,
            icon: "waveform",
            title: "Music",
            value: music.track?.title ?? "Nothing playing",
            detail: music.isPlaying ? music.activeSource.displayName : "Paused",
            isActive: music.isPlaying
        )
    }

    private var codingRowData: DashboardRow.RowData {
        DashboardRow.RowData(
            section: .activity,
            icon: "chevron.left.forwardslash.chevron.right",
            title: "Coding",
            value: activity.runningCount > 0
                ? "\(activity.runningCount) active"
                : "No active tasks",
            detail: activity.runningCount > 0
                ? activity.primaryActivity.title
                : "Ready",
            isActive: activity.runningCount > 0
        )
    }

    private var shelfRowData: DashboardRow.RowData {
        DashboardRow.RowData(
            section: .shelf,
            icon: "tray.full.fill",
            title: "File Shelf",
            value: shelf.items.isEmpty
                ? "Shelf is empty"
                : "\(shelf.items.count) item\(shelf.items.count == 1 ? "" : "s")",
            detail: "Drop files to keep them close",
            isActive: !shelf.items.isEmpty
        )
    }

    private var timerRowData: DashboardRow.RowData {
        DashboardRow.RowData(
            section: .timer,
            icon: "timer",
            title: "Timer",
            value: timer.isActive
                ? TimerService.formatted(timer.remaining)
                : "No active timer",
            detail: timer.isPaused ? "Paused" : (timer.isActive ? "Running" : "Ready"),
            isActive: timer.isActive
        )
    }

    private var todosRowData: DashboardRow.RowData {
        DashboardRow.RowData(
            section: .todo,
            icon: "checklist",
            title: "Todos",
            value: todos.remainingCount > 0
                ? "\(todos.remainingCount) remaining"
                : "All clear",
            detail: todos.items.isEmpty ? "Add your first task" : "View task list",
            isActive: todos.remainingCount > 0
        )
    }

    private var calendarRowData: DashboardRow.RowData {
        let nextEvent = calendar.accessState == .authorized ? calendar.nextEvent : nil
        let value: String
        let detail: String

        if let nextEvent {
            value = nextEvent.title
            detail = "\(nextEvent.dayLabel) · \(nextEvent.shortTime)"
        } else {
            // No event to surface: report the connection state so the row
            // guides the user instead of implying the calendar is empty.
            switch calendar.accessState {
            case .notDetermined:
                value = "Not connected"
                detail = "Tap to allow Calendar access"
            case .requesting:
                value = "Connecting…"
                detail = "Waiting for permission"
            case .denied, .restricted:
                value = "Access is off"
                detail = "Enable it in System Settings"
            case .authorized:
                value = "No upcoming events"
                detail = "Nothing in the next 14 days"
            }
        }

        return DashboardRow.RowData(
            section: .calendar,
            icon: "calendar",
            title: "Calendar",
            value: value,
            detail: detail,
            isActive: nextEvent != nil
        )
    }

    // MARK: - Inline controls

    @ViewBuilder
    private var musicControls: some View {
        if music.track != nil {
            Button {
                music.togglePlayback()
            } label: {
                Image(systemName: music.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.notchAccent)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Color.notchAccent.opacity(0.14)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help(music.isPlaying ? "Pause" : "Play")
            .accessibilityLabel(music.isPlaying ? "Pause music" : "Play music")
        }
    }

    @ViewBuilder
    private var timerProgress: some View {
        if timer.isActive {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 1.5)
                Circle()
                    .trim(from: 0, to: timer.progress)
                    .stroke(
                        Color.notchAccent,
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.25), value: timer.progress)
            }
            .frame(width: 14, height: 14)
            .accessibilityHidden(true)
        }
    }
}

/// One strip of the unified dashboard: icon, title, live value, secondary
/// detail, optional inline controls, and a hover-revealed navigation chevron.
private struct DashboardRow: View {
    struct RowData {
        let section: NotchSection
        let icon: String
        let title: String
        let value: String
        let detail: String
        let isActive: Bool
    }

    let data: RowData
    let controls: AnyView
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: data.icon)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(data.isActive ? Color.notchAccent : Color.notchMuted)
                    .frame(width: 19, height: 19)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(
                                data.isActive
                                    ? Color.notchAccent.opacity(0.14)
                                    : Color.white.opacity(isHovering ? 0.09 : 0.05)
                            )
                    )

                Text(data.title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .lineLimit(1)
                    .fixedSize()

                Text(data.value)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(data.isActive ? Color.notchAccent : .white.opacity(0.72))
                    .lineLimit(1)

                Text(data.detail)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(Color.notchMuted)
                    .lineLimit(1)

                Spacer(minLength: 6)

                controls

                if data.isActive {
                    Circle()
                        .fill(Color.notchAccent)
                        .frame(width: 4.5, height: 4.5)
                        .shadow(color: Color.notchAccent.opacity(0.6), radius: 2.5)
                        .accessibilityHidden(true)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(Color.white.opacity(isHovering ? 0.55 : 0.18))
            }
            .padding(.horizontal, 7)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 20, maxHeight: 30)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.white.opacity(isHovering ? 0.05 : 0))
            )
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.14), value: isHovering)
        .accessibilityLabel("\(data.title): \(data.value), \(data.detail)")
    }
}
