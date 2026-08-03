import SwiftUI

struct CompactTimerView: View {
    @ObservedObject var timer: TimerService
    let message: String?

    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: timer.progress)
                    .stroke(
                        Color.notchAccent,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.25), value: timer.progress)
                Image(systemName: timer.isPaused ? "pause.fill" : "timer")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.notchAccent)
                    .id(timer.isPaused)
                    .transition(.opacity.combined(with: .scale(scale: 0.72)))
                    .animation(.easeOut(duration: 0.2), value: timer.isPaused)
            }
            .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(message ?? (timer.isPaused ? "Timer paused" : "Focus timer"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(timer.isPaused ? "Click to manage" : "In progress")
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(Color.notchMuted)
            }

            Spacer(minLength: 6)

            Text(TimerService.formatted(timer.remaining))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.notchAccent)
                .contentTransition(.numericText(countsDown: true))
                .animation(.smooth(duration: 0.25), value: Int(timer.remaining.rounded(.up)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(timer.isPaused ? "Timer paused" : "Focus timer running")
        .accessibilityValue(TimerService.formatted(timer.remaining))
    }
}
