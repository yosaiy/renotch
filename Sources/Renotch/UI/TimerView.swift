import AppKit
import SwiftUI

struct TimerView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var timer: TimerService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isStartHovered = false
    @State private var isPauseHovered = false
    @State private var isSkipHovered = false
    @State private var isStopHovered = false

    private let focusPresets = [15, 25, 45, 60]
    private let breakPresets = [5, 10, 15, 20]

    var body: some View {
        Group {
            if timer.isActive {
                activeSessionView
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98)))
            } else {
                setupSessionView
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 4)
        .padding(.bottom, 0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: timer.isActive)
    }

    // MARK: - Idle / Setup Instrument

    private var setupSessionView: some View {
        HStack(alignment: .center, spacing: 14) {
            // Focal Point: Live Session Preview + Primary Action
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.notchAccent)
                        .frame(width: 5, height: 5)
                        .accessibilityHidden(true)

                    Text(timer.autoAdvance ? "Focus, then \(timer.breakMinutes)m break" : "Single focus block")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.notchMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 2)

                Text(formattedMinutes(timer.focusMinutes))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .tracking(-1.0)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .contentTransition(reduceMotion ? .identity : .numericText())
                    .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: timer.focusMinutes)

                Spacer(minLength: 6)

                Button {
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                    model.startPomodoro(
                        focusMinutes: timer.focusMinutes,
                        breakMinutes: timer.breakMinutes,
                        autoAdvance: timer.autoAdvance
                    )
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 9.5, weight: .bold))
                        Text("Start Focus")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 29)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.notchAccent.opacity(isStartHovered ? 1.0 : 0.92))
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(NotchPressButtonStyle())
                .onHover { isStartHovered = $0 }
                .animation(.easeOut(duration: 0.14), value: isStartHovered)
                .help("Start \(timer.focusMinutes)-minute focus session")
                .accessibilityLabel("Start \(timer.focusMinutes) minute focus session")
            }
            .frame(width: 152, alignment: .leading)

            // Structural Hairline Separator
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)
                .padding(.vertical, 2)

            // Precision Duration Controls
            VStack(spacing: 6) {
                durationRow(
                    label: "Focus",
                    minutes: timer.focusMinutes,
                    presets: focusPresets,
                    tint: Color.notchAccent,
                    stepDown: timer.focusMinutes > 5 ? -5 : -1,
                    stepUp: 5,
                    range: 1...180,
                    onChange: { timer.focusMinutes = $0 }
                )

                durationRow(
                    label: "Break",
                    minutes: timer.breakMinutes,
                    presets: breakPresets,
                    tint: Color.notchBreak,
                    stepDown: -1,
                    stepUp: 1,
                    range: 1...60,
                    onChange: { timer.breakMinutes = $0 }
                )

                // Functional Auto-Advance Toggle
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "repeat")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(timer.autoAdvance ? Color.notchAccent : Color.notchMuted)
                        Text("Auto-start break")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.84))
                    }

                    Spacer(minLength: 6)

                    Button {
                        timer.autoAdvance.toggle()
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                    } label: {
                        Text(timer.autoAdvance ? "On" : "Off")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(timer.autoAdvance ? Color.notchAccent : Color.notchMuted)
                            .padding(.horizontal, 9)
                            .frame(height: 20)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(timer.autoAdvance ? Color.notchAccent.opacity(0.14) : Color.white.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .stroke(
                                                timer.autoAdvance ? Color.notchAccent.opacity(0.35) : Color.white.opacity(0.08),
                                                lineWidth: 0.8
                                            )
                                    )
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(NotchPressButtonStyle())
                    .help(timer.autoAdvance ? "Disable automatic break after focus" : "Automatically start break when focus ends")
                    .accessibilityLabel("Auto-start break")
                    .accessibilityValue(timer.autoAdvance ? "On" : "Off")
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func durationRow(
        label: String,
        minutes: Int,
        presets: [Int],
        tint: Color,
        stepDown: Int,
        stepUp: Int,
        range: ClosedRange<Int>,
        onChange: @escaping (Int) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))

                Spacer(minLength: 4)

                HStack(spacing: 2) {
                    TimerStepperButton(
                        icon: "minus",
                        label: "Decrease \(label.lowercased()) minutes",
                        isDisabled: minutes <= range.lowerBound
                    ) {
                        onChange((minutes + stepDown).clamped(to: range))
                    }

                    Text("\(minutes)m")
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(tint)
                        .frame(minWidth: 32)
                        .multilineTextAlignment(.center)

                    TimerStepperButton(
                        icon: "plus",
                        label: "Increase \(label.lowercased()) minutes",
                        isDisabled: minutes >= range.upperBound
                    ) {
                        onChange((minutes + stepUp).clamped(to: range))
                    }
                }
            }

            HStack(spacing: 4) {
                ForEach(presets, id: \.self) { preset in
                    TimerPresetChip(
                        minutes: preset,
                        isSelected: minutes == preset,
                        tint: tint
                    ) {
                        onChange(preset)
                    }
                }
            }
        }
    }

    // MARK: - Active Session Chronometer

    private var activeSessionView: some View {
        let tint = timer.currentMode.tint
        let isFocus = timer.currentMode == .focus
        let breakMin = timer.storedTimer?.resolvedBreakMinutes ?? timer.breakMinutes
        let willAutoBreak = isFocus && (timer.storedTimer?.isAutoAdvance ?? timer.autoAdvance)

        return VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 16) {
                // Focal Point: Countdown + Context
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(timer.isPaused ? Color.notchMuted : tint)
                            .frame(width: 6, height: 6)
                            .accessibilityHidden(true)

                        Text(timer.currentMode.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(timer.isPaused ? Color.notchMuted : tint)

                        if timer.isPaused {
                            Text("Paused")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.84))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1.5)
                                .background(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(Color.white.opacity(0.1))
                                )
                        } else if willAutoBreak {
                            Text("· \(breakMin)m break next")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.notchMuted)
                                .lineLimit(1)
                        }
                    }

                    Text(TimerService.formatted(timer.remaining))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .tracking(-1.2)
                        .foregroundStyle(timer.isPaused ? Color.white.opacity(0.68) : Color.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .contentTransition(reduceMotion ? .identity : .numericText(countsDown: true))
                        .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: Int(timer.remaining.rounded(.up)))
                }

                Spacer(minLength: 8)

                // Right Control Cluster
                VStack(spacing: 6) {
                    Button {
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                        timer.togglePause()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: timer.isPaused ? "play.fill" : "pause.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text(timer.isPaused ? "Resume" : "Pause")
                                .font(.system(size: 11.5, weight: .semibold))
                        }
                        .foregroundStyle(timer.isPaused ? Color.black : tint)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(
                                    timer.isPaused
                                        ? Color.white.opacity(isPauseHovered ? 1.0 : 0.92)
                                        : tint.opacity(isPauseHovered ? 0.22 : 0.14)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(
                                            timer.isPaused ? Color.clear : tint.opacity(0.32),
                                            lineWidth: 0.8
                                        )
                                )
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(NotchPressButtonStyle())
                    .onHover { isPauseHovered = $0 }
                    .animation(.easeOut(duration: 0.14), value: isPauseHovered)
                    .help(timer.isPaused ? "Resume \(timer.currentMode.title.lowercased())" : "Pause \(timer.currentMode.title.lowercased())")
                    .accessibilityLabel(timer.isPaused ? "Resume timer" : "Pause timer")

                    HStack(spacing: 6) {
                        Button {
                            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                            timer.skip()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "forward.end.fill")
                                    .font(.system(size: 9, weight: .semibold))
                                Text(isFocus ? "Break" : "Done")
                                    .font(.system(size: 10.5, weight: .medium))
                            }
                            .foregroundStyle(isSkipHovered ? .white : .white.opacity(0.84))
                            .frame(maxWidth: .infinity)
                            .frame(height: 26)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color.white.opacity(isSkipHovered ? 0.13 : 0.07))
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        }
                        .buttonStyle(NotchPressButtonStyle())
                        .onHover { isSkipHovered = $0 }
                        .animation(.easeOut(duration: 0.14), value: isSkipHovered)
                        .help(isFocus ? "Skip to break" : "Finish break")
                        .accessibilityLabel(isFocus ? "Skip to break" : "Finish break")

                        Button {
                            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                            timer.cancel()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                Text("Stop")
                                    .font(.system(size: 10.5, weight: .medium))
                            }
                            .foregroundStyle(isStopHovered ? Color.notchDanger : Color.notchMuted)
                            .frame(maxWidth: .infinity)
                            .frame(height: 26)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(isStopHovered ? Color.notchDanger.opacity(0.14) : Color.white.opacity(0.06))
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        }
                        .buttonStyle(NotchPressButtonStyle())
                        .onHover { isStopHovered = $0 }
                        .animation(.easeOut(duration: 0.14), value: isStopHovered)
                        .help("Stop and reset timer")
                        .accessibilityLabel("Stop timer")
                    }
                }
                .frame(width: 146)
            }

            // Single Unified Progress Track + Real End Time
            VStack(spacing: 5) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(Color.white.opacity(0.1))

                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(timer.isPaused ? Color.notchMuted : tint)
                            .frame(width: max(0, proxy.size.width * timer.progress))
                            .animation(reduceMotion ? nil : .linear(duration: 0.25), value: timer.progress)
                    }
                }
                .frame(height: 4)

                HStack {
                    Text("\(Int((timer.progress * 100).rounded()))% elapsed")
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.notchMuted)

                    Spacer()

                    Text(endTimeLabel)
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.notchMuted)
                }
            }
        }
    }

    // MARK: - Helpers

    private var endTimeLabel: String {
        if timer.isPaused {
            return "Timer paused"
        }
        guard let endDate = timer.storedTimer?.endDate else {
            return ""
        }
        return "Ends at \(endDate.formatted(.dateTime.hour().minute()))"
    }

    private func formattedMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours > 0 {
            return String(format: "%d:%02d:00", hours, remainder)
        }
        return String(format: "%02d:00", minutes)
    }
}

// MARK: - Subcomponents

private struct TimerPresetChip: View {
    let minutes: Int
    let isSelected: Bool
    let tint: Color
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text("\(minutes)m")
                .font(.system(size: 10.5, weight: isSelected ? .semibold : .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isSelected ? tint : (isHovering ? .white : Color.notchMuted))
                .frame(maxWidth: .infinity)
                .frame(height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            isSelected
                                ? tint.opacity(0.16)
                                : Color.white.opacity(isHovering ? 0.09 : 0.045)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(isSelected ? tint.opacity(0.42) : Color.clear, lineWidth: 0.8)
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(NotchPressButtonStyle())
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.14), value: isHovering)
        .animation(.easeOut(duration: 0.14), value: isSelected)
        .accessibilityLabel("\(minutes) minutes")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct TimerStepperButton: View {
    let icon: String
    let label: String
    let isDisabled: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 8.5, weight: .bold))
                .foregroundStyle(isDisabled ? Color.white.opacity(0.25) : (isHovering ? .white : Color.notchMuted))
                .frame(width: 18, height: 18)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.white.opacity(isDisabled ? 0.03 : (isHovering ? 0.12 : 0.06)))
                )
                .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(NotchPressButtonStyle())
        .disabled(isDisabled)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .help(label)
        .accessibilityLabel(label)
    }
}
