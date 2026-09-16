import SwiftUI

struct TimerView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var timer: TimerService

    var body: some View {
        Group {
            if timer.isActive {
                activeTimer
            } else {
                timerPicker
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Setup / Picker

    private var timerPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // Focus Card
                durationCard(
                    title: "专注",
                    icon: "timer",
                    minutes: timer.focusMinutes,
                    presets: [15, 25, 45, 60],
                    recommended: 25,
                    tint: Color.notchAccent,
                    onSelectPreset: { timer.focusMinutes = $0 },
                    onAdjust: { delta in
                        timer.focusMinutes = (timer.focusMinutes + delta).clamped(to: 1...180)
                    }
                )

                // Break Card
                durationCard(
                    title: "休息",
                    icon: "cup.and.saucer.fill",
                    minutes: timer.breakMinutes,
                    presets: [5, 10, 15, 20],
                    recommended: 5,
                    tint: Color(red: 0.42, green: 0.78, blue: 0.98),
                    onSelectPreset: { timer.breakMinutes = $0 },
                    onAdjust: { delta in
                        timer.breakMinutes = (timer.breakMinutes + delta).clamped(to: 1...60)
                    }
                )
            }

            // Start Pomodoro Button
            Button {
                model.startPomodoro(
                    focusMinutes: timer.focusMinutes,
                    breakMinutes: timer.breakMinutes
                )
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .bold))

                    Text("开始番茄钟")
                        .font(.system(size: 12, weight: .bold))

                    Text("·  专注 \(timer.focusMinutes) 分钟  ➔  休息 \(timer.breakMinutes) 分钟")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.8))

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "bolt.badge.automatic.fill")
                            .font(.system(size: 9))
                        Text("自动休息")
                            .font(.system(size: 9.5, weight: .semibold))
                    }
                    .foregroundStyle(Color.notchAccent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Capsule().fill(Color.notchAccent.opacity(0.14)))
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.notchAccent.opacity(0.4), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func durationCard(
        title: String,
        icon: String,
        minutes: Int,
        presets: [Int],
        recommended: Int,
        tint: Color,
        onSelectPreset: @escaping (Int) -> Void,
        onAdjust: @escaping (Int) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                Text("\(minutes) 分钟")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
            }

            HStack(spacing: 4) {
                ForEach(presets, id: \.self) { preset in
                    let isSelected = minutes == preset
                    Button {
                        onSelectPreset(preset)
                    } label: {
                        Text("\(preset)")
                            .font(.system(size: 10.5, weight: isSelected ? .bold : .medium, design: .rounded))
                            .foregroundStyle(isSelected ? tint : .white.opacity(0.75))
                            .frame(maxWidth: .infinity)
                            .frame(height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(isSelected ? tint.opacity(0.2) : Color.white.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(isSelected ? tint.opacity(0.5) : Color.clear, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 2) {
                    Button {
                        let delta = title == "专注" ? (minutes > 5 ? -5 : -1) : -1
                        onAdjust(delta)
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 9, weight: .bold))
                            .frame(width: 18, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        let delta = title == "专注" ? 5 : 1
                        onAdjust(delta)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                            .frame(width: 18, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(tint)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(tint.opacity(0.12))
                )
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(tint.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Active Pomodoro View

    private var activeTimer: some View {
        VStack(spacing: 8) {
            // Phase Progress Indicator
            phaseBreadcrumb

            HStack(spacing: 16) {
                CircularTimerProgress(
                    progress: timer.progress,
                    text: TimerService.formatted(timer.remaining),
                    tint: timer.currentMode.tint
                )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Image(systemName: timer.currentMode.icon)
                            .font(.system(size: 10, weight: .bold))
                        Text(activeHeaderTitle)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(timer.currentMode.tint)

                    Text(activeSubtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    ProgressView(value: timer.progress)
                        .tint(timer.currentMode.tint)
                }

                Spacer(minLength: 4)

                VStack(spacing: 5) {
                    SmallActionButton(
                        title: timer.isPaused ? "继续" : "暂停",
                        icon: timer.isPaused ? "play.fill" : "pause.fill",
                        tint: timer.currentMode.tint
                    ) { timer.togglePause() }

                    HStack(spacing: 4) {
                        SmallActionButton(
                            title: timer.currentMode == .focus ? "休息" : "专注",
                            icon: "forward.fill"
                        ) {
                            timer.skip()
                        }
                        SmallActionButton(title: "取消", icon: "xmark") {
                            timer.cancel()
                        }
                    }
                }
            }
        }
    }

    private var phaseBreadcrumb: some View {
        HStack(spacing: 6) {
            let focusM = timer.storedTimer?.resolvedFocusMinutes ?? timer.focusMinutes
            let breakM = timer.storedTimer?.resolvedBreakMinutes ?? timer.breakMinutes
            let isFocus = timer.currentMode == .focus

            // Focus Chip
            HStack(spacing: 4) {
                Image(systemName: "timer")
                    .font(.system(size: 8.5, weight: .bold))
                Text("专注 \(focusM) 分钟")
                    .font(.system(size: 9.5, weight: isFocus ? .bold : .medium))
            }
            .foregroundStyle(isFocus ? Color.notchAccent : Color.white.opacity(0.45))
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .background(
                Capsule()
                    .fill(isFocus ? Color.notchAccent.opacity(0.18) : Color.white.opacity(0.04))
            )
            .overlay(
                Capsule()
                    .stroke(isFocus ? Color.notchAccent.opacity(0.4) : Color.clear, lineWidth: 1)
            )

            Image(systemName: "arrow.right")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.3))

            // Break Chip
            HStack(spacing: 4) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 8.5, weight: .bold))
                Text("休息 \(breakM) 分钟")
                    .font(.system(size: 9.5, weight: !isFocus ? .bold : .medium))
            }
            .foregroundStyle(!isFocus ? Color(red: 0.42, green: 0.78, blue: 0.98) : Color.white.opacity(0.45))
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .background(
                Capsule()
                    .fill(!isFocus ? Color(red: 0.42, green: 0.78, blue: 0.98).opacity(0.18) : Color.white.opacity(0.04))
            )
            .overlay(
                Capsule()
                    .stroke(!isFocus ? Color(red: 0.42, green: 0.78, blue: 0.98).opacity(0.4) : Color.clear, lineWidth: 1)
            )

            Spacer()

            if isFocus && (timer.storedTimer?.isAutoAdvance ?? timer.autoAdvance) {
                HStack(spacing: 3) {
                    Image(systemName: "bolt.badge.automatic.fill")
                        .font(.system(size: 8))
                    Text("结束后自动休息")
                        .font(.system(size: 8.5, weight: .medium))
                }
                .foregroundStyle(Color.notchMuted)
            }
        }
    }

    private var activeHeaderTitle: String {
        if timer.isPaused {
            return "\(timer.currentMode.title)已暂停"
        }
        return "\(timer.currentMode.title)进行中"
    }

    private var activeSubtitle: String {
        if timer.isPaused {
            return "准备好后随时继续。"
        }
        switch timer.currentMode {
        case .focus:
            let bMin = timer.storedTimer?.resolvedBreakMinutes ?? timer.breakMinutes
            return "时间结束后，自动开始 \(bMin) 分钟休息。"
        case .breakTime:
            return "放松一下，休息结束后会通知你。"
        }
    }
}


