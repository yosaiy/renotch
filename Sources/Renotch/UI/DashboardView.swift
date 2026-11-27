import AppKit
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var music: MusicService
    @ObservedObject var activity: DeveloperActivityService
    @ObservedObject var shelf: ShelfStore
    @ObservedObject var timer: TimerService
    @ObservedObject var todos: TodoStore
    @ObservedObject var calendar: AppleCalendarService
    let navigate: (NotchSection) -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Left Focal Column: Live Continuous Controls (Timer + Media)
            VStack(spacing: 0) {
                timerBlock
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)

                musicBlock
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity)

            // Structural Vertical Hairline
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)
                .padding(.vertical, 2)

            // Right Index Column: Scannable Utility Rows
            VStack(spacing: 0) {
                codingRow
                rowDivider
                calendarRow
                rowDivider
                todoRow
                rowDivider
                shelfRow
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.top, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 1)
    }

    // MARK: - Left Column: Focus Timer

    private var timerBlock: some View {
        DashboardInteractiveBlock(action: { navigate(.timer) }) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(timer.isActive ? (timer.isPaused ? Color.notchMuted : timer.currentMode.tint) : Color.white.opacity(0.28))
                            .frame(width: 5, height: 5)
                            .accessibilityHidden(true)

                        Text(timer.isActive ? (timer.isPaused ? "\(timer.currentMode.title) · Paused" : timer.currentMode.title) : "Focus Timer")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(timer.isActive ? timer.currentMode.tint : Color.notchMuted)
                            .lineLimit(1)
                    }

                    Text(timer.isActive ? TimerService.formatted(timer.remaining) : "\(timer.focusMinutes):00")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .tracking(-0.5)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Button {
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                    if timer.isActive {
                        timer.togglePause()
                    } else {
                        model.startPomodoro(
                            focusMinutes: timer.focusMinutes,
                            breakMinutes: timer.breakMinutes,
                            autoAdvance: timer.autoAdvance
                        )
                    }
                } label: {
                    Image(systemName: timer.isActive ? (timer.isPaused ? "play.fill" : "pause.fill") : "play.fill")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 26, height: 26)
                        .background(
                            Circle()
                                .fill(timer.isActive ? timer.currentMode.tint : Color.notchAccent)
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(NotchPressButtonStyle())
                .help(timer.isActive ? (timer.isPaused ? "Resume timer" : "Pause timer") : "Start focus session")
                .accessibilityLabel(timer.isActive ? (timer.isPaused ? "Resume timer" : "Pause timer") : "Start focus session")
            }
        }
    }

    // MARK: - Left Column: Now Playing

    private var musicBlock: some View {
        DashboardInteractiveBlock(action: { navigate(.music) }) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                    if let artwork = music.artwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    } else {
                        Image(systemName: music.isPlaying ? "waveform" : "music.note")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(music.isPlaying ? Color.musicAccent : Color.notchMuted)
                    }
                }
                .frame(width: 34, height: 34)
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.6)
                )

                VStack(alignment: .leading, spacing: 1.5) {
                    Text(music.track?.title ?? "Nothing playing")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(music.track?.artist ?? "Apple Music / Spotify")
                        .font(.system(size: 9.5, weight: .regular))
                        .foregroundStyle(Color.notchMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                if music.track != nil {
                    Button {
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                        music.togglePlayback()
                    } label: {
                        Image(systemName: music.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(
                                Circle()
                                    .fill(music.isPlaying ? Color.musicAccent : Color.white.opacity(0.14))
                            )
                            .contentShape(Circle())
                    }
                    .buttonStyle(NotchPressButtonStyle())
                    .help(music.isPlaying ? "Pause" : "Play")
                    .accessibilityLabel(music.isPlaying ? "Pause music" : "Play music")
                }
            }
        }
    }

    // MARK: - Right Column: Utility Rows

    private var codingRow: some View {
        let isLive = activity.runningCount > 0
        return DashboardIndexRow(
            icon: "chevron.left.forwardslash.chevron.right",
            iconTint: isLive ? Color.notchAccent : Color.notchMuted,
            title: "Coding",
            detail: isLive ? "\(activity.runningCount) active · \(activity.primaryActivity.title)" : "No active servers",
            detailTint: isLive ? Color.notchAccent : Color.notchMuted,
            showsDot: isLive,
            action: { navigate(.activity) }
        )
    }

    private var calendarRow: some View {
        let nextEvent = calendar.accessState == .authorized ? calendar.nextEvent : nil
        let isAuthorized = calendar.accessState == .authorized
        let detail: String = {
            if let nextEvent {
                return "\(nextEvent.shortTime) · \(nextEvent.title)"
            }
            return isAuthorized ? "No events today" : "Connect Calendar"
        }()

        return DashboardIndexRow(
            icon: "calendar",
            iconTint: nextEvent != nil ? Color.notchAccent : Color.notchMuted,
            title: "Calendar",
            detail: detail,
            detailTint: nextEvent != nil ? .white.opacity(0.86) : Color.notchMuted,
            showsDot: false,
            action: { navigate(.calendar) }
        )
    }

    private var todoRow: some View {
        let hasRemaining = todos.remainingCount > 0
        let topTodo = todos.items.first(where: { !$0.isCompleted })

        return DashboardInteractiveRow(action: { navigate(.todo) }) {
            HStack(spacing: 8) {
                if let topTodo {
                    Button {
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                        todos.toggle(topTodo)
                    } label: {
                        Image(systemName: "circle")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.notchAccent)
                            .frame(width: 18, height: 18)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(NotchPressButtonStyle())
                    .help("Complete task: \(topTodo.title)")
                    .accessibilityLabel("Complete task \(topTodo.title)")
                } else {
                    Image(systemName: "checklist")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(Color.notchMuted)
                        .frame(width: 18)
                }

                Text("Todos")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .fixedSize()

                Text(topTodo?.title ?? (todos.items.isEmpty ? "All caught up" : "All done"))
                    .font(.system(size: 9.5, weight: .regular))
                    .foregroundStyle(hasRemaining ? .white.opacity(0.76) : Color.notchMuted)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if hasRemaining {
                    Text("\(todos.remainingCount)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.black)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color.notchAccent))
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.32))
                }
            }
        }
    }

    private var shelfRow: some View {
        let hasFiles = !shelf.items.isEmpty
        return DashboardIndexRow(
            icon: "tray.full.fill",
            iconTint: hasFiles ? Color.notchAccent : Color.notchMuted,
            title: "Shelf",
            detail: hasFiles ? "\(shelf.items.count) \(shelf.items.count == 1 ? "file" : "files") pinned" : "Drop files to pin",
            detailTint: hasFiles ? .white.opacity(0.86) : Color.notchMuted,
            showsDot: false,
            action: { navigate(.shelf) }
        )
    }
}

// MARK: - Subcomponents

private struct DashboardInteractiveBlock<Content: View>: View {
    let action: () -> Void
    @ViewBuilder let content: () -> Content
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            content()
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(isHovering ? 0.065 : 0.0))
                )
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.14), value: isHovering)
    }
}

private struct DashboardInteractiveRow<Content: View>: View {
    let action: () -> Void
    @ViewBuilder let content: () -> Content
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            content()
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.white.opacity(isHovering ? 0.065 : 0.0))
                )
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.14), value: isHovering)
    }
}

private struct DashboardIndexRow: View {
    let icon: String
    let iconTint: Color
    let title: String
    let detail: String
    let detailTint: Color
    let showsDot: Bool
    let action: () -> Void

    var body: some View {
        DashboardInteractiveRow(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(iconTint)
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .fixedSize()

                if showsDot {
                    Circle()
                        .fill(Color.notchAccent)
                        .frame(width: 4.5, height: 4.5)
                        .accessibilityHidden(true)
                }

                Text(detail)
                    .font(.system(size: 9.5, weight: .regular))
                    .foregroundStyle(detailTint)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.32))
            }
        }
    }
}
