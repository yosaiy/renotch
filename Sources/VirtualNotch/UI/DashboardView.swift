import SwiftUI

struct DashboardView: View {
    @ObservedObject var music: MusicService
    @ObservedObject var activity: DeveloperActivityService
    @ObservedObject var shelf: ShelfStore
    @ObservedObject var timer: TimerService
    @ObservedObject var todos: TodoStore
    @ObservedObject var calendar: AppleCalendarService
    let navigate: (NotchSection) -> Void

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 8),
        count: 3
    )

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            summaryCard(
                title: "Music",
                icon: "waveform",
                value: music.track?.title ?? "Nothing playing",
                detail: music.isPlaying ? music.activeSource.displayName : "Paused",
                isActive: music.isPlaying,
                section: .music
            )
            summaryCard(
                title: "Coding",
                icon: "chevron.left.forwardslash.chevron.right",
                value: activity.runningCount > 0
                    ? "\(activity.runningCount) active"
                    : "No active tasks",
                detail: activity.runningCount > 0
                    ? activity.primaryActivity.title
                    : "Ready",
                isActive: activity.runningCount > 0,
                section: .activity
            )
            summaryCard(
                title: "File Shelf",
                icon: "tray.full.fill",
                value: shelf.items.isEmpty
                    ? "Shelf is empty"
                    : "\(shelf.items.count) item\(shelf.items.count == 1 ? "" : "s")",
                detail: "Drop files to keep them close",
                isActive: !shelf.items.isEmpty,
                section: .shelf
            )
            summaryCard(
                title: "Timer",
                icon: "timer",
                value: timer.isActive
                    ? TimerService.formatted(timer.remaining)
                    : "No active timer",
                detail: timer.isPaused ? "Paused" : (timer.isActive ? "Running" : "Ready"),
                isActive: timer.isActive,
                section: .timer
            )
            summaryCard(
                title: "Todos",
                icon: "checklist",
                value: todos.remainingCount > 0
                    ? "\(todos.remainingCount) remaining"
                    : "All clear",
                detail: todos.items.isEmpty ? "Add your first task" : "View task list",
                isActive: todos.remainingCount > 0,
                section: .todo
            )
            summaryCard(
                title: "Calendar",
                icon: "calendar",
                value: calendar.nextEvent?.title ?? "No upcoming events",
                detail: calendar.nextEvent.map { "\($0.dayLabel) · \($0.shortTime)" }
                    ?? calendar.compactStatus,
                isActive: calendar.nextEvent != nil,
                section: .calendar
            )
        }
        .padding(.top, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func summaryCard(
        title: String,
        icon: String,
        value: String,
        detail: String,
        isActive: Bool,
        section: NotchSection
    ) -> some View {
        DashboardSummaryCard(
            title: title,
            icon: icon,
            value: value,
            detail: detail,
            isActive: isActive
        ) {
            navigate(section)
        }
    }
}

private struct DashboardSummaryCard: View {
    let title: String
    let icon: String
    let value: String
    let detail: String
    let isActive: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(.system(size: 9, weight: .semibold))
                    Text(title)
                        .font(.system(size: 9.5, weight: .semibold))
                    Spacer(minLength: 2)
                    Circle()
                        .fill(isActive ? Color.notchAccent : Color.white.opacity(0.16))
                        .frame(width: 5, height: 5)
                        .shadow(
                            color: isActive ? Color.notchAccent.opacity(0.65) : .clear,
                            radius: 3
                        )
                }
                .foregroundStyle(isActive ? Color.notchAccent : Color.notchMuted)

                Text(value)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(detail)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(Color.notchMuted)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(isHovering ? 0.075 : 0.045))
            )
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(Color.white.opacity(isHovering ? 0.55 : 0.2))
                    .padding(8)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .scaleEffect(isHovering ? 1.015 : 1)
        .animation(.easeOut(duration: 0.16), value: isHovering)
        .help("Open \(title)")
        .accessibilityLabel("\(title): \(value)")
    }
}
