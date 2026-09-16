import SwiftUI

/// Apple-grade unified dashboard for Re:notch.
/// Implements WWDC fluid interface principles:
/// - Translucent frosted materials with specular highlights
/// - Direct manipulation with spring-based press feedback
/// - Live dynamic indicators (pulsing dots, progress rings, animated waveforms)
/// - Bento-grid organization for instant glanceability and inline controls
struct DashboardView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var music: MusicService
    @ObservedObject var activity: DeveloperActivityService
    @ObservedObject var shelf: ShelfStore
    @ObservedObject var timer: TimerService
    @ObservedObject var todos: TodoStore
    @ObservedObject var calendar: AppleCalendarService
    let navigate: (NotchSection) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 8) {
                // Top Hero Bento: Media & Focus Timer
                HStack(spacing: 8) {
                    musicBentoCard
                    timerBentoCard
                }

                // Grid Bento: Activity, Calendar, Todos, Shelf
                LazyVGrid(columns: columns, spacing: 8) {
                    activityBentoCard
                    calendarBentoCard
                    todosBentoCard
                    shelfBentoCard
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 1. Music / Media Player Card

    private var musicBentoCard: some View {
        DashboardBentoCard(
            accentColor: Color.musicAccent,
            isActive: music.isPlaying,
            action: { navigate(.music) }
        ) {
            HStack(spacing: 10) {
                // Artwork or dynamic icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            music.isPlaying
                                ? Color.musicAccent.opacity(0.18)
                                : Color.white.opacity(0.06)
                        )
                    if let artwork = music.artwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else {
                        Image(systemName: music.isPlaying ? "waveform" : "music.note")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(music.isPlaying ? Color.musicAccent : Color.notchMuted)
                    }
                }
                .frame(width: 36, height: 36)
                .overlay(alignment: .bottomTrailing) {
                    if music.isPlaying {
                        Circle()
                            .fill(Color.musicAccent)
                            .frame(width: 6, height: 6)
                            .shadow(color: Color.musicAccent.opacity(0.8), radius: 3)
                            .offset(x: 1, y: 1)
                    }
                }

                // Track title & source
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("正在播放")
                            .font(.system(size: 8.5, weight: .semibold))
                            .textCase(.uppercase)
                            .tracking(0.4)
                            .foregroundStyle(Color.notchMuted)
                        Spacer(minLength: 0)
                        Text(music.isPlaying ? music.activeSource.displayName : "已暂停")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(music.isPlaying ? Color.musicAccent : Color.white.opacity(0.45))
                    }

                    Text(music.track?.title ?? "暂无播放内容")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.95))
                        .lineLimit(1)

                    Text(music.track?.artist ?? "QQ 音乐 / Apple Music / Spotify")
                        .font(.system(size: 9.5, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .lineLimit(1)
                }

                Spacer(minLength: 2)

                // Inline Play/Pause control
                if music.track != nil {
                    Button {
                        music.togglePlayback()
                    } label: {
                        Image(systemName: music.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.white)
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(music.isPlaying ? Color.musicAccent : Color.white.opacity(0.12))
                            )
                            .shadow(color: music.isPlaying ? Color.musicAccent.opacity(0.4) : .clear, radius: 4)
                    }
                    .buttonStyle(AppleSpringPressStyle())
                    .help(music.isPlaying ? "暂停" : "播放")
                    .accessibilityLabel(music.isPlaying ? "暂停音乐" : "播放音乐")
                }
            }
        }
    }

    // MARK: - 2. Focus / Pomodoro Timer Card

    private var timerBentoCard: some View {
        DashboardBentoCard(
            accentColor: timer.currentMode.tint,
            isActive: timer.isActive,
            action: { navigate(.timer) }
        ) {
            HStack(spacing: 10) {
                // Circular Progress Ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 2.5)
                    Circle()
                        .trim(from: 0, to: timer.isActive ? timer.progress : 1.0)
                        .stroke(
                            timer.isActive ? timer.currentMode.tint : Color.notchMuted.opacity(0.4),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.25), value: timer.progress)

                    Image(systemName: timer.currentMode.icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(timer.isActive ? timer.currentMode.tint : Color.notchMuted)
                }
                .frame(width: 32, height: 32)

                // Time remaining & mode
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(timer.isActive ? timer.currentMode.title.uppercased() : "专注计时")
                            .font(.system(size: 8.5, weight: .semibold))
                            .tracking(0.4)
                            .foregroundStyle(timer.isActive ? timer.currentMode.tint : Color.notchMuted)
                        Spacer(minLength: 0)
                        Text(timer.isPaused ? "已暂停" : (timer.isActive ? "运行中" : "25 分钟 / 5 分钟"))
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.45))
                    }

                    Text(timer.isActive ? TimerService.formatted(timer.remaining) : "番茄钟")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(timer.isActive ? Color.white : Color.white.opacity(0.85))

                    Text(timer.isActive ? "已完成 \(Int(timer.progress * 100))%" : "准备开始专注")
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .lineLimit(1)
                }

                Spacer(minLength: 2)

                // Inline quick action button
                Button {
                    if timer.isActive {
                        timer.togglePause()
                    } else {
                        model.startPomodoro(
                            focusMinutes: timer.focusMinutes,
                            breakMinutes: timer.breakMinutes
                        )
                    }
                } label: {
                    Image(systemName: timer.isActive ? (timer.isPaused ? "play.fill" : "pause.fill") : "play.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(timer.isActive ? Color.white : Color.black)
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(timer.isActive ? timer.currentMode.tint : Color.notchAccent)
                        )
                        .shadow(color: Color.notchAccent.opacity(0.35), radius: 3)
                }
                .buttonStyle(AppleSpringPressStyle())
                .help(timer.isActive ? (timer.isPaused ? "继续计时" : "暂停计时") : "开始专注")
            }
        }
    }

    // MARK: - 3. Developer / Coding Activity Card

    private var activityBentoCard: some View {
        let isLive = activity.runningCount > 0
        return DashboardBentoCard(
            accentColor: Color.notchAccent,
            isActive: isLive,
            action: { navigate(.activity) }
        ) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(
                            isLive
                                ? Color.notchAccent.opacity(0.16)
                                : Color.white.opacity(0.06)
                        )
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(isLive ? Color.notchAccent : Color.notchMuted)
                }
                .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 1.5) {
                    HStack(spacing: 4) {
                        Text("开发活动")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.9))
                        if isLive {
                            Circle()
                                .fill(Color.notchAccent)
                                .frame(width: 4.5, height: 4.5)
                                .shadow(color: Color.notchAccent.opacity(0.8), radius: 2.5)
                        }
                    }

                    Text(isLive ? "\(activity.runningCount) 项运行中 · \(activity.primaryActivity.title)" : "暂无运行中的服务")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(isLive ? Color.notchAccent : Color.notchMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.2))
            }
        }
    }

    // MARK: - 4. Apple Calendar Card

    private var calendarBentoCard: some View {
        let nextEvent = calendar.accessState == .authorized ? calendar.nextEvent : nil
        let isAuthorized = calendar.accessState == .authorized

        return DashboardBentoCard(
            accentColor: Color(red: 0.22, green: 0.65, blue: 1.0),
            isActive: nextEvent != nil,
            action: { navigate(.calendar) }
        ) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(
                            nextEvent != nil
                                ? Color(red: 0.22, green: 0.65, blue: 1.0).opacity(0.16)
                                : Color.white.opacity(0.06)
                        )
                    Image(systemName: "calendar")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(nextEvent != nil ? Color(red: 0.22, green: 0.65, blue: 1.0) : Color.notchMuted)
                }
                .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 1.5) {
                    Text("日历")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.9))

                    if let nextEvent {
                        Text("\(nextEvent.shortTime) · \(nextEvent.title)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color(red: 0.42, green: 0.78, blue: 1.0))
                            .lineLimit(1)
                    } else {
                        Text(isAuthorized ? "今天没有日程" : "点击连接")
                            .font(.system(size: 9, weight: .regular))
                            .foregroundStyle(Color.notchMuted)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.2))
            }
        }
    }

    // MARK: - 5. Todos Card

    private var todosBentoCard: some View {
        let hasRemaining = todos.remainingCount > 0
        let topTodo = todos.items.first(where: { !$0.isCompleted })

        return DashboardBentoCard(
            accentColor: Color(red: 0.35, green: 0.85, blue: 0.55),
            isActive: hasRemaining,
            action: { navigate(.todo) }
        ) {
            HStack(spacing: 8) {
                // Interactive quick completion if there's a top todo
                if let topTodo {
                    Button {
                        todos.toggle(topTodo)
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                            Image(systemName: "circle")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.notchAccent)
                        }
                        .frame(width: 26, height: 26)
                    }
                    .buttonStyle(AppleSpringPressStyle())
                    .help("完成待办：\(topTodo.title)")
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                        Image(systemName: "checklist")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(hasRemaining ? Color.notchAccent : Color.notchMuted)
                    }
                    .frame(width: 26, height: 26)
                }

                VStack(alignment: .leading, spacing: 1.5) {
                    HStack(spacing: 4) {
                        Text("待办")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.9))
                        if hasRemaining {
                            Text("\(todos.remainingCount)")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.black)
                                .padding(.horizontal, 4.5)
                                .padding(.vertical, 0.5)
                                .background(Capsule().fill(Color.notchAccent))
                        }
                    }

                    Text(topTodo?.title ?? (todos.items.isEmpty ? "待办已清空" : "所有待办均已完成"))
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(hasRemaining ? Color.white.opacity(0.8) : Color.notchMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.2))
            }
        }
    }

    // MARK: - 6. File Shelf Card

    private var shelfBentoCard: some View {
        let hasFiles = !shelf.items.isEmpty

        return DashboardBentoCard(
            accentColor: Color(red: 0.65, green: 0.50, blue: 0.98),
            isActive: hasFiles,
            action: { navigate(.shelf) }
        ) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(
                            hasFiles
                                ? Color(red: 0.65, green: 0.50, blue: 0.98).opacity(0.16)
                                : Color.white.opacity(0.06)
                        )
                    Image(systemName: "tray.full.fill")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(hasFiles ? Color(red: 0.75, green: 0.60, blue: 1.0) : Color.notchMuted)
                }
                .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 1.5) {
                    Text("文件暂存")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.9))

                    Text(hasFiles ? "已暂存 \(shelf.items.count) 个文件" : "拖入文件即可暂存")
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(hasFiles ? Color(red: 0.85, green: 0.75, blue: 1.0) : Color.notchMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.2))
            }
        }
    }
}

// MARK: - Apple Design Bento Card Container

private struct DashboardBentoCard<Content: View>: View {
    let accentColor: Color
    let isActive: Bool
    let action: () -> Void
    let content: Content

    @State private var isHovering = false

    init(
        accentColor: Color = .white,
        isActive: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.accentColor = accentColor
        self.isActive = isActive
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            content
                .padding(.horizontal, 9)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isHovering ? 0.09 : (isActive ? 0.07 : 0.045)),
                                    Color.white.opacity(isHovering ? 0.05 : (isActive ? 0.04 : 0.025))
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    isActive
                                        ? accentColor.opacity(isHovering ? 0.45 : 0.25)
                                        : Color.white.opacity(isHovering ? 0.16 : 0.07),
                                    Color.white.opacity(isHovering ? 0.06 : 0.02)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .scaleEffect(isHovering ? 1.012 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.82), value: isHovering)
                .animation(.easeOut(duration: 0.18), value: isActive)
        }
        .buttonStyle(AppleSpringPressStyle())
        .onHover { isHovering = $0 }
    }
}

// MARK: - Apple Fluid Spring Press Button Style

/// Implements Apple WWDC fluid press response: instant feedback on pointer-down
/// with continuous spring recovery.
private struct AppleSpringPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.24, dampingFraction: 0.78), value: configuration.isPressed)
    }
}
