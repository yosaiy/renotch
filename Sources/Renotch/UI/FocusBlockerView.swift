import AppKit
import SwiftUI

struct FocusBlockerView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var blocker: FocusBlockerService
    @ObservedObject var timer: TimerService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var newRuleInput = ""
    @State private var isPreviewHovered = false
    @State private var isBypassHovered = false
    @State private var isGrantHovered = false
    @FocusState private var isRuleFieldFocused: Bool

    private let quickPresets = [
        "youtube.com",
        "threads.net",
        "instagram.com",
        "x.com",
        "tiktok.com",
        "reddit.com",
        "netflix.com"
    ]

    private var isEnabled: Bool {
        model.settings.resolvedFocusBlockerEnabled
    }

    private var isStrictPomodoro: Bool {
        model.settings.resolvedFocusBlockerStrictPomodoroOnly
    }

    private var activeRules: [String] {
        model.settings.resolvedFocusBlockerCustomRules
    }

    private var isFocusRunning: Bool {
        timer.isActive && !timer.isPaused && timer.currentMode == .focus
    }

    private var statusInfo: (label: String, detail: String, tint: Color) {
        if !isEnabled {
            return ("Shield Off", "Distractions allowed", Color.notchMuted)
        }
        if !blocker.isAccessibilityGranted {
            return ("Access Needed", "Grant macOS Accessibility", Color.notchDanger)
        }
        if blocker.isBypassed {
            return ("Snoozed", "Blocking paused briefly", Color.notchBreak)
        }
        if isStrictPomodoro && !isFocusRunning {
            return ("Standby", "Blocks during Focus timer", Color.notchAccent)
        }
        return ("Shield Active", "\(activeRules.isEmpty ? FocusBlockerService.defaultRules.count : activeRules.count) rules guarding", Color.notchDanger)
    }

    var body: some View {
        HStack(spacing: 14) {
            // Left Control Column: Status, Master/Strict Toggles & Quick Actions
            controlColumn
                .frame(width: 174, alignment: .leading)

            // Structural Hairline Divider
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)
                .padding(.vertical, 2)

            // Right Rules Workspace: Inline Composer + Active Rules & Presets
            rulesColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.top, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            blocker.checkAccessibilityStatus()
        }
    }

    // MARK: - Left Control Column

    private var controlColumn: some View {
        let status = statusInfo
        return VStack(alignment: .leading, spacing: 0) {
            // Status Headline + Master Switch
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 1.5) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(status.tint)
                            .frame(width: 6, height: 6)
                            .accessibilityHidden(true)

                        Text(status.label)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }

                    Text(status.detail)
                        .font(.system(size: 9.5, weight: .regular))
                        .foregroundStyle(Color.notchMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { model.settings.focusBlockerEnabled = $0 }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .accessibilityLabel("Enable Focus Blocker")
            }

            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
                .padding(.vertical, 8)

            // Strict Pomodoro Toggle Row
            HStack(spacing: 6) {
                Text("Strict Pomodoro")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.86))
                    .lineLimit(1)

                Spacer(minLength: 4)

                Button {
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                    model.settings.focusBlockerStrictPomodoroOnly = !isStrictPomodoro
                } label: {
                    Text(isStrictPomodoro ? "On" : "Off")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(isStrictPomodoro ? Color.notchAccent : Color.notchMuted)
                        .padding(.horizontal, 8)
                        .frame(height: 20)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(isStrictPomodoro ? Color.notchAccent.opacity(0.14) : Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .stroke(
                                            isStrictPomodoro ? Color.notchAccent.opacity(0.35) : Color.white.opacity(0.08),
                                            lineWidth: 0.8
                                        )
                                )
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(NotchPressButtonStyle())
                .help("Only block websites while a Focus session is actively running")
                .accessibilityLabel("Strict Pomodoro only")
                .accessibilityValue(isStrictPomodoro ? "On" : "Off")
            }

            Spacer(minLength: 8)

            // Bottom Action Bar: Accessibility Grant OR Snooze + Preview
            if !blocker.isAccessibilityGranted {
                Button {
                    blocker.requestAccessibilityPermission()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 9.5, weight: .semibold))
                        Text("Grant Access")
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.notchAccent.opacity(isGrantHovered ? 1.0 : 0.92))
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(NotchPressButtonStyle())
                .onHover { isGrantHovered = $0 }
                .animation(.easeOut(duration: 0.12), value: isGrantHovered)
                .help("Request macOS Accessibility permission to detect browser tabs")
            } else {
                HStack(spacing: 6) {
                    Button {
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                        if blocker.isBypassed {
                            blocker.clearBypass()
                        } else {
                            blocker.bypass(minutes: 5)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: blocker.isBypassed ? "shield.fill" : "clock")
                                .font(.system(size: 9, weight: .semibold))
                            Text(blocker.isBypassed ? "Resume" : "Snooze 5m")
                                .font(.system(size: 10, weight: .medium))
                                .lineLimit(1)
                        }
                        .foregroundStyle(
                            blocker.isBypassed
                                ? Color.black
                                : (isBypassHovered ? .white : .white.opacity(0.84))
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 25)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(
                                    blocker.isBypassed
                                        ? Color.notchAccent.opacity(isBypassHovered ? 1.0 : 0.92)
                                        : Color.white.opacity(isBypassHovered ? 0.13 : 0.07)
                                )
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(NotchPressButtonStyle())
                    .disabled(!isEnabled)
                    .opacity(isEnabled ? 1 : 0.4)
                    .onHover { isBypassHovered = $0 }
                    .animation(.easeOut(duration: 0.12), value: isBypassHovered)
                    .help(blocker.isBypassed ? "Resume blocking immediately" : "Pause blocking for 5 minutes")

                    Button {
                        model.triggerFocusTakeover(
                            site: "youtube.com",
                            appName: "Google Chrome",
                            targetApp: NSWorkspace.shared.frontmostApplication
                        )
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "eye")
                                .font(.system(size: 9, weight: .semibold))
                            Text("Test")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(isPreviewHovered ? .white : Color.notchMuted)
                        .padding(.horizontal, 9)
                        .frame(height: 25)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(isPreviewHovered ? 0.13 : 0.06))
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(NotchPressButtonStyle())
                    .onHover { isPreviewHovered = $0 }
                    .animation(.easeOut(duration: 0.12), value: isPreviewHovered)
                    .help("Preview fullscreen focus takeover overlay")
                    .accessibilityLabel("Preview focus takeover")
                }
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Right Rules Column

    private var rulesColumn: some View {
        let canAdd = !newRuleInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let availablePresets = quickPresets.filter { !activeRules.contains($0) }

        return VStack(alignment: .leading, spacing: 0) {
            // Inline Domain Input + Reset
            HStack(spacing: 7) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isRuleFieldFocused ? Color.notchAccent : Color.notchMuted)

                TextField("Block domain or keyword…", text: $newRuleInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .focused($isRuleFieldFocused)
                    .onSubmit(addRule)

                if canAdd {
                    Button(action: addRule) {
                        Text("Add")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 8)
                            .frame(height: 20)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(Color.notchAccent)
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                    .buttonStyle(NotchPressButtonStyle())
                    .transition(.opacity)
                } else if activeRules != FocusBlockerService.defaultRules {
                    Button("Reset") {
                        model.settings.focusBlockerCustomRules = FocusBlockerService.defaultRules
                    }
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Color.notchMuted)
                    .buttonStyle(.plain)
                    .help("Restore default blocked sites")
                }
            }
            .frame(height: 24)
            .padding(.bottom, 4)

            Rectangle()
                .fill(Color.white.opacity(isRuleFieldFocused ? 0.22 : 0.08))
                .frame(height: 1)
                .animation(.easeOut(duration: 0.14), value: isRuleFieldFocused)

            // Active Rules + Quick Presets
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 7) {
                    if activeRules.isEmpty {
                        Text("Using default list while empty. Add a site above or click Reset.")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(Color.notchMuted)
                            .padding(.top, 4)
                    } else {
                        BlockerChipFlowLayout(spacing: 5) {
                            ForEach(activeRules, id: \.self) { rule in
                                BlockerRuleChip(rule: rule) {
                                    removeRule(rule)
                                }
                            }
                        }
                    }

                    if !availablePresets.isEmpty {
                        BlockerChipFlowLayout(spacing: 5) {
                            ForEach(availablePresets, id: \.self) { preset in
                                BlockerPresetChip(domain: preset) {
                                    addPreset(preset)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 7)
                .padding(.bottom, 2)
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: activeRules)
        }
    }

    // MARK: - Actions

    private func addRule() {
        let trimmed = newRuleInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return }
        var current = activeRules
        if !current.contains(trimmed) {
            current.append(trimmed)
            model.settings.focusBlockerCustomRules = current
        }
        newRuleInput = ""
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
    }

    private func addPreset(_ preset: String) {
        var current = activeRules
        guard !current.contains(preset) else { return }
        current.append(preset)
        model.settings.focusBlockerCustomRules = current
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
    }

    private func removeRule(_ rule: String) {
        var current = activeRules
        current.removeAll { $0 == rule }
        model.settings.focusBlockerCustomRules = current
    }
}

// MARK: - Chips & Flow Layout

private struct BlockerRuleChip: View {
    let rule: String
    let remove: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 5) {
            Text(rule)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)

            Button(action: remove) {
                Image(systemName: "xmark")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(isHovering ? Color.notchDanger : Color.notchMuted)
                    .frame(width: 12, height: 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Remove \(rule)")
            .accessibilityLabel("Remove \(rule)")
        }
        .padding(.horizontal, 7)
        .frame(height: 22)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.white.opacity(isHovering ? 0.1 : 0.065))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(Color.white.opacity(isHovering ? 0.16 : 0.1), lineWidth: 0.6)
                )
        )
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}

private struct BlockerPresetChip: View {
    let domain: String
    let add: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: add) {
            HStack(spacing: 3.5) {
                Image(systemName: "plus")
                    .font(.system(size: 7.5, weight: .bold))
                Text(domain)
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .lineLimit(1)
            }
            .foregroundStyle(isHovering ? .white : Color.notchMuted)
            .padding(.horizontal, 7)
            .frame(height: 21)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.white.opacity(isHovering ? 0.08 : 0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(Color.white.opacity(isHovering ? 0.14 : 0.06), lineWidth: 0.6)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(NotchPressButtonStyle())
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .help("Block \(domain)")
        .accessibilityLabel("Block \(domain)")
    }
}

private struct BlockerChipFlowLayout: Layout {
    var spacing: CGFloat = 5

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 280
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return CGSize(width: width, height: currentY + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
