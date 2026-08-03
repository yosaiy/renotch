import SwiftUI

struct TimerView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var timer: TimerService

    private let presets = [5, 10, 15, 25]

    var body: some View {
        Group {
            if timer.isActive {
                activeTimer
            } else {
                timerPicker
            }
        }
        .padding(.vertical, 8)
    }

    private var timerPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start a focus timer")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Choose a preset or set your own duration.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 7) {
                ForEach(presets, id: \.self) { minutes in
                    Button {
                        model.startTimer(minutes: minutes)
                    } label: {
                        VStack(spacing: 2) {
                            Text("\(minutes)")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                            Text("min")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(Color.white.opacity(minutes == 25 ? 0.11 : 0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .stroke(minutes == 25 ? Color.notchAccent.opacity(0.4) : .clear, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 4) {
                    Button {
                        model.customTimerMinutes = max(1, model.customTimerMinutes - 5)
                    } label: {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.plain)

                    Button {
                        model.startCustomTimer()
                    } label: {
                        VStack(spacing: 2) {
                            Text("\(model.customTimerMinutes)")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                            Text("custom")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        model.customTimerMinutes = min(120, model.customTimerMinutes + 5)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain)
                }
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.notchAccent)
                .padding(.horizontal, 7)
                .frame(width: 86, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.notchAccent.opacity(0.08))
                )
            }
        }
    }

    private var activeTimer: some View {
        HStack(spacing: 18) {
            CircularTimerProgress(
                progress: timer.progress,
                text: TimerService.formatted(timer.remaining)
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(timer.isPaused ? "Timer paused" : "Focus in progress")
                    .font(.system(size: 14, weight: .semibold))
                Text(timer.isPaused ? "Resume whenever you’re ready." : "We’ll let you know when time is up.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                ProgressView(value: timer.progress)
                    .tint(Color.notchAccent)
            }

            Spacer(minLength: 5)

            VStack(spacing: 7) {
                SmallActionButton(
                    title: timer.isPaused ? "Resume" : "Pause",
                    icon: timer.isPaused ? "play.fill" : "pause.fill",
                    tint: Color.notchAccent
                ) { timer.togglePause() }
                SmallActionButton(title: "Cancel", icon: "xmark") { timer.cancel() }
            }
        }
    }
}
