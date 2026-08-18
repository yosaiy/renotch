import SwiftUI

struct CompactTimerView: View {
    @ObservedObject var timer: TimerService
    let message: String?

    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 2)
                if timer.isActive {
                    Circle()
                        .trim(from: 0, to: timer.progress)
                        .stroke(
                            timer.currentMode.tint,
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.25), value: timer.progress)
                }
                Image(systemName: timer.isActive ? (timer.isPaused ? "pause.fill" : timer.currentMode.icon) : "timer")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(timer.isActive ? timer.currentMode.tint : Color.notchAccent)
                    .id("\(timer.isActive)-\(timer.isPaused)-\(timer.currentMode.rawValue)")
                    .transition(.opacity.combined(with: .scale(scale: 0.72)))
                    .animation(.easeOut(duration: 0.2), value: timer.isPaused)
            }
            .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(titleText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(subtitleText)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(Color.notchMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Text(trailingText)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(timer.isActive ? timer.currentMode.tint : Color.white.opacity(0.75))
                .contentTransition(.numericText(countsDown: true))
                .animation(.smooth(duration: 0.25), value: Int(timer.remaining.rounded(.up)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(timer.isActive ? (timer.isPaused ? "\(timer.currentMode.title) timer paused" : "\(timer.currentMode.title) timer running") : "Pomodoro timer ready")
        .accessibilityValue(timer.isActive ? TimerService.formatted(timer.remaining) : "\(timer.focusMinutes) minutes")
    }

    private var titleText: String {
        if let message { return message }
        if timer.isActive {
            return timer.isPaused ? "\(timer.currentMode.title) paused" : "\(timer.currentMode.title) timer"
        }
        return "Pomodoro"
    }

    private var subtitleText: String {
        if timer.isActive {
            if timer.isPaused { return "Click to manage" }
            if timer.currentMode == .focus && (timer.storedTimer?.isAutoAdvance ?? timer.autoAdvance) {
                let breakM = timer.storedTimer?.resolvedBreakMinutes ?? timer.breakMinutes
                return "Break \(breakM)m next"
            }
            return "In progress"
        }
        return "Ready · \(timer.focusMinutes)m + \(timer.breakMinutes)m"
    }

    private var trailingText: String {
        if timer.isActive {
            return TimerService.formatted(timer.remaining)
        }
        return "\(timer.focusMinutes)m"
    }
}


