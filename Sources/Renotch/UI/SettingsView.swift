import AppKit
import SwiftUI

private enum GlassMaterialLevel: Double, CaseIterable, Identifiable {
    case ultraThin = 6
    case thin = 16
    case regular = 26

    var id: Double { rawValue }

    var title: String {
        switch self {
        case .ultraThin: return "Ultra Thin"
        case .thin: return "Thin"
        case .regular: return "Regular"
        }
    }

    static func resolve(_ blurRadius: Double) -> Self {
        switch blurRadius {
        case ..<10: return .ultraThin
        case ..<20: return .thin
        default: return .regular
        }
    }
}

private enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case appearance = "Appearance"
    case blocker = "Focus Blocker"
    case privacy = "Privacy"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .general: return "switch.2"
        case .appearance: return "circle.lefthalf.filled"
        case .blocker: return "shield.lefthalf.filled"
        case .privacy: return "hand.raised.fill"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var screenManager: ScreenManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedTab: SettingsTab = .general
    @State private var newRuleInput = ""
    @State private var showPaddingControls = false
    @State private var isRestoreHovered = false

    private let quickPresets = [
        "youtube.com",
        "threads.net",
        "instagram.com",
        "x.com",
        "tiktok.com",
        "reddit.com",
        "netflix.com"
    ]

    var body: some View {
        HStack(spacing: 0) {
            sidebarView
                .frame(width: 184)
                .background(
                    ZStack {
                        VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow)
                        Color.black.opacity(0.24)
                    }
                )

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)

            detailContentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 0.08, green: 0.08, blue: 0.09))
        }
        .frame(minWidth: 660, idealWidth: 760, maxWidth: .infinity, minHeight: 460, idealHeight: 540, maxHeight: .infinity)
        .preferredColorScheme(.dark)
        .onAppear {
            model.focusBlocker.checkAccessibilityStatus()
        }
    }

    // MARK: - Sidebar

    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                appIconView(size: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Re:notch")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Settings")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Color.notchMuted)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 16)

            VStack(spacing: 2) {
                ForEach(SettingsTab.allCases) { tab in
                    SidebarTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab
                    ) {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                        model.resetSettings()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 10.5, weight: .medium))
                        Text("Restore Defaults")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(isRestoreHovered ? .white : Color.notchMuted)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(isRestoreHovered ? 0.1 : 0.045))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.white.opacity(isRestoreHovered ? 0.14 : 0.08), lineWidth: 0.6)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(NotchPressButtonStyle())
                .onHover { isRestoreHovered = $0 }
                .animation(.easeOut(duration: 0.12), value: isRestoreHovered)

                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                    Text("Version \(version)")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Color.notchMuted)
                        .padding(.leading, 2)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Detail Canvas

    private var detailContentView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 18) {
                Text(selectedTab.rawValue)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                switch selectedTab {
                case .general:
                    generalTabContent
                case .appearance:
                    appearanceTabContent
                case .blocker:
                    focusBlockerTabContent
                case .privacy:
                    privacyTabContent
                }
            }
            .padding(22)
        }
    }

    // MARK: - General Tab (Simplified)

    private var generalTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingSection("Startup & Display") {
                SettingToggleRow("Show Re:notch", isOn: visibilityBinding)
                sectionDivider
                SettingToggleRow("Launch at login", isOn: $model.settings.launchAtLogin)
                sectionDivider
                SettingRow("Default compact view") {
                    Picker("", selection: compactContentBinding) {
                        ForEach(CompactNotchContent.allCases) { content in
                            Text(content.title).tag(content)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 148)
                }
                sectionDivider
                SettingRow("Target monitor") {
                    Picker("", selection: $model.settings.targetDisplayID) {
                        Text("Main display").tag(nil as UInt32?)
                        ForEach(screenManager.displays) { display in
                            Text(display.name).tag(Optional(display.id))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 148)
                }
            }

            SettingSection("Behavior & Positioning") {
                SettingToggleRow("Enlarge on hover", isOn: $model.settings.expandOnHover)
                sectionDivider
                SettingToggleRow("Expand on click", isOn: $model.settings.expandOnClick)
                sectionDivider
                SettingToggleRow("Always on top", isOn: $model.settings.alwaysOnTop)
                sectionDivider
                SettingToggleRow("Show over full-screen apps", isOn: $model.settings.showOnFullscreen)
                sectionDivider
                HStack(spacing: 16) {
                    CompactValueSlider(
                        title: "Collapse delay",
                        value: $model.settings.collapseDelay,
                        range: 0.3...1.2,
                        suffix: "s",
                        precision: 1
                    )
                    CompactValueSlider(
                        title: "Top offset",
                        value: $model.settings.verticalOffset,
                        range: 0...40,
                        suffix: " pt",
                        precision: 0
                    )
                }
                .padding(.top, 2)
            }

            if let error = model.settingsError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.notchDanger)
                    Text(error)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color.notchDanger)
                }
                .padding(11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.notchDanger.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.notchDanger.opacity(0.24), lineWidth: 0.8)
                        )
                )
            }
        }
    }

    // MARK: - Appearance Tab (Simplified)

    private var appearanceTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingSection("Surface") {
                VStack(alignment: .leading, spacing: 12) {
                    NotchAppearancePreview(
                        appearance: model.settings.resolvedAppearance,
                        blurRadius: model.settings.resolvedGlassBlurRadius,
                        cornerRadius: model.settings.resolvedCompactCornerRadius
                    )

                    SettingRow("Material") {
                        Picker("", selection: appearanceBinding) {
                            ForEach(NotchAppearance.allCases) { appearance in
                                Text(appearance.title).tag(appearance)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 210)
                    }

                    if model.settings.resolvedAppearance == .liquidGlass,
                       #unavailable(macOS 26.0) {
                        sectionDivider
                        SettingRow("Frosted blur") {
                            Picker("", selection: glassMaterialBinding) {
                                ForEach(GlassMaterialLevel.allCases) { level in
                                    Text(level.title).tag(level)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width: 210)
                        }
                    }
                }
            }

            SettingSection("Layout") {
                SettingToggleRow("Avoid MacBook hardware notch", isOn: avoidHardwareNotchBinding)
                sectionDivider
                SettingRow("Navigation bar") {
                    Picker("", selection: headerNavigationStyleBinding) {
                        ForEach(HeaderNavigationStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 185)
                }
                sectionDivider
                SettingToggleRow("Show track title in compact mode", isOn: compactTrackInfoBinding)
            }

            SettingSection("Size") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 16) {
                        CompactValueSlider(
                            title: "Compact width",
                            value: $model.settings.compactWidth,
                            range: NotchSettings.compactWidthRange,
                            suffix: " pt",
                            precision: 0
                        )
                        CompactValueSlider(
                            title: "Compact height",
                            value: $model.settings.compactHeight,
                            range: NotchSettings.compactHeightRange,
                            suffix: " pt",
                            precision: 0
                        )
                    }

                    CompactValueSlider(
                        title: "Compact corner radius",
                        value: compactCornerRadiusBinding,
                        range: NotchSettings.compactCornerRadiusRange,
                        suffix: " pt",
                        precision: 0
                    )

                    sectionDivider

                    HStack(spacing: 16) {
                        CompactValueSlider(
                            title: "Expanded width",
                            value: $model.settings.expandedWidth,
                            range: NotchSettings.expandedWidthRange,
                            suffix: " pt",
                            precision: 0
                        )
                        CompactValueSlider(
                            title: "Expanded height",
                            value: $model.settings.expandedHeight,
                            range: NotchSettings.expandedHeightRange,
                            suffix: " pt",
                            precision: 0
                        )
                    }

                    HStack {
                        Button("Match compact width") {
                            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                                model.settings.expandedWidth = model.settings.compactWidth
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(model.settings.expandedWidth == model.settings.compactWidth)

                        Spacer()

                        Button {
                            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                                showPaddingControls.toggle()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text("Inner Padding")
                                Image(systemName: showPaddingControls ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 9, weight: .semibold))
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.notchMuted)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(showPaddingControls ? "Hide inner padding controls" : "Show inner padding controls")
                    }

                    if showPaddingControls {
                        sectionDivider

                        Text("Compact Padding")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(Color.notchMuted)

                        HStack(spacing: 16) {
                            CompactValueSlider(
                                title: "Left",
                                value: paddingBinding(\.compactContentLeadingPadding, resolved: \.resolvedCompactContentLeadingPadding),
                                range: NotchSettings.compactContentHorizontalPaddingRange,
                                suffix: " pt",
                                precision: 0
                            )
                            CompactValueSlider(
                                title: "Right",
                                value: paddingBinding(\.compactContentTrailingPadding, resolved: \.resolvedCompactContentTrailingPadding),
                                range: NotchSettings.compactContentHorizontalPaddingRange,
                                suffix: " pt",
                                precision: 0
                            )
                        }
                        HStack(spacing: 16) {
                            CompactValueSlider(
                                title: "Top",
                                value: paddingBinding(\.compactContentTopPadding, resolved: \.resolvedCompactContentTopPadding),
                                range: NotchSettings.compactContentVerticalPaddingRange,
                                suffix: " pt",
                                precision: 0
                            )
                            CompactValueSlider(
                                title: "Bottom",
                                value: paddingBinding(\.compactContentBottomPadding, resolved: \.resolvedCompactContentBottomPadding),
                                range: NotchSettings.compactContentVerticalPaddingRange,
                                suffix: " pt",
                                precision: 0
                            )
                        }

                        Text("Expanded Padding")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(Color.notchMuted)
                            .padding(.top, 4)

                        HStack(spacing: 16) {
                            CompactValueSlider(
                                title: "Left",
                                value: paddingBinding(\.expandedContentLeadingPadding, resolved: \.resolvedExpandedContentLeadingPadding),
                                range: NotchSettings.expandedContentPaddingRange,
                                suffix: " pt",
                                precision: 0
                            )
                            CompactValueSlider(
                                title: "Right",
                                value: paddingBinding(\.expandedContentTrailingPadding, resolved: \.resolvedExpandedContentTrailingPadding),
                                range: NotchSettings.expandedContentPaddingRange,
                                suffix: " pt",
                                precision: 0
                            )
                        }
                        HStack(spacing: 16) {
                            CompactValueSlider(
                                title: "Top",
                                value: paddingBinding(\.expandedContentTopPadding, resolved: \.resolvedExpandedContentTopPadding),
                                range: NotchSettings.expandedContentPaddingRange,
                                suffix: " pt",
                                precision: 0
                            )
                            CompactValueSlider(
                                title: "Bottom",
                                value: paddingBinding(\.expandedContentBottomPadding, resolved: \.resolvedExpandedContentBottomPadding),
                                range: NotchSettings.expandedContentPaddingRange,
                                suffix: " pt",
                                precision: 0
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Focus Blocker Tab (Simplified)

    private var focusBlockerTabContent: some View {
        let activeRules = model.settings.resolvedFocusBlockerCustomRules
        let availablePresets = quickPresets.filter { !activeRules.contains($0) }
        let isRuleEmpty = newRuleInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return VStack(alignment: .leading, spacing: 16) {
            SettingSection("Protection") {
                SettingToggleRow("Enable Focus Blocker", isOn: focusBlockerEnabledBinding)
                sectionDivider
                SettingToggleRow(
                    "Strict Pomodoro only",
                    subtitle: "Block sites only while a Focus session is running",
                    isOn: focusBlockerStrictBinding
                )
                sectionDivider
                SettingRow(
                    "Accessibility permission",
                    subtitle: model.focusBlocker.isAccessibilityGranted
                        ? "Active for frontmost browser window detection"
                        : "Required to detect active browser tabs"
                ) {
                    HStack(spacing: 8) {
                        if model.focusBlocker.isAccessibilityGranted {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.notchAccent)
                                    .frame(width: 6, height: 6)
                                Text("Active")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.notchAccent)
                            }
                            .padding(.horizontal, 8)
                            .frame(height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.notchAccent.opacity(0.12))
                            )
                        } else {
                            Button("Grant Access") {
                                model.focusBlocker.requestAccessibilityPermission()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .tint(Color.notchAccent)
                            .foregroundStyle(.black)
                        }

                        Button {
                            model.triggerFocusTakeover(
                                site: "youtube.com",
                                appName: "Google Chrome",
                                targetApp: NSWorkspace.shared.frontmostApplication
                            )
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "eye")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("Preview")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(.white.opacity(0.88))
                            .padding(.horizontal, 9)
                            .frame(height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(NotchPressButtonStyle())
                        .help("Preview fullscreen focus takeover overlay")
                    }
                }
            }

            SettingSection("Blocked Sites (\(activeRules.count))") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        TextField("Add domain or keyword (e.g. reddit.com)…", text: $newRuleInput)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .padding(.horizontal, 10)
                            .frame(height: 30)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 0.6)
                            )
                            .onSubmit(addRule)

                        Button(action: addRule) {
                            Text("Add")
                                .font(.system(size: 11.5, weight: .semibold))
                                .padding(.horizontal, 12)
                                .frame(height: 30)
                                .background(isRuleEmpty ? Color.white.opacity(0.08) : Color.notchAccent)
                                .foregroundStyle(isRuleEmpty ? Color.notchMuted : .black)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        }
                        .buttonStyle(NotchPressButtonStyle())
                        .disabled(isRuleEmpty)

                        if activeRules != FocusBlockerService.defaultRules {
                            Button("Reset") {
                                model.settings.focusBlockerCustomRules = FocusBlockerService.defaultRules
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.notchMuted)
                            .buttonStyle(.plain)
                            .help("Restore default blocked sites")
                        }
                    }

                    if activeRules.isEmpty {
                        Text("Using default list while empty. Add a domain above or click Reset.")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.notchMuted)
                    } else {
                        FlowLayout(spacing: 6) {
                            ForEach(activeRules, id: \.self) { rule in
                                HStack(spacing: 6) {
                                    Text(rule)
                                        .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.92))

                                    Button {
                                        removeRule(rule)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 8.5, weight: .bold))
                                            .foregroundStyle(Color.notchMuted)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Remove \(rule)")
                                    .accessibilityLabel("Remove \(rule)")
                                }
                                .padding(.horizontal, 9)
                                .frame(height: 25)
                                .background(Color.white.opacity(0.07))
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(Color.white.opacity(0.11), lineWidth: 0.6)
                                )
                            }
                        }
                    }

                    if !availablePresets.isEmpty {
                        sectionDivider

                        FlowLayout(spacing: 6) {
                            ForEach(availablePresets, id: \.self) { preset in
                                Button {
                                    togglePreset(preset)
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 8.5, weight: .bold))
                                        Text(preset)
                                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                                    }
                                    .padding(.horizontal, 8)
                                    .frame(height: 23)
                                    .background(Color.white.opacity(0.04))
                                    .foregroundStyle(Color.notchMuted)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .stroke(Color.white.opacity(0.08), lineWidth: 0.6)
                                    )
                                }
                                .buttonStyle(NotchPressButtonStyle())
                                .accessibilityLabel("Block \(preset)")
                            }
                        }
                    }
                }
            }

            Text("Tip: You can also toggle Focus Blocker, snooze for 5 minutes, or edit rules directly from the Blocker tab in the notch.")
                .font(.system(size: 11))
                .foregroundStyle(Color.notchMuted)
        }
    }

    // MARK: - Privacy Tab (Simplified)

    private var privacyTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingSection("Notifications") {
                SettingToggleRow(
                    "Notify when timers finish",
                    isOn: $model.settings.timerNotificationsEnabled
                )
            }

            SettingSection("About") {
                HStack(spacing: 12) {
                    appIconView(size: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Re:notch")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.0")")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.notchMuted)
                    }

                    Spacer()

                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.notchAccent)
                }

                sectionDivider

                Text("All settings, todos, and shelf references stay strictly local on this Mac. No account, cloud sync, or analytics.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.notchMuted)
                    .lineSpacing(2)
            }
        }
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 1)
            .padding(.vertical, 6)
    }

    // MARK: - Actions & Bindings

    private func addRule() {
        let trimmed = newRuleInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return }
        var current = model.settings.resolvedFocusBlockerCustomRules
        if !current.contains(trimmed) {
            current.append(trimmed)
            model.settings.focusBlockerCustomRules = current
        }
        newRuleInput = ""
    }

    private func removeRule(_ rule: String) {
        var current = model.settings.resolvedFocusBlockerCustomRules
        current.removeAll { $0 == rule }
        model.settings.focusBlockerCustomRules = current
    }

    private func togglePreset(_ preset: String) {
        var current = model.settings.resolvedFocusBlockerCustomRules
        if current.contains(preset) {
            current.removeAll { $0 == preset }
        } else {
            current.append(preset)
        }
        model.settings.focusBlockerCustomRules = current
    }

    @ViewBuilder
    private func appIconView(size: CGFloat) -> some View {
        if let icon = NSApp.applicationIconImage {
            Image(nsImage: icon)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
                  let icon = NSImage(contentsOf: iconURL) {
            Image(nsImage: icon)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "capsule.tophalf.filled")
                .font(.system(size: size * 0.5, weight: .bold))
                .frame(width: size, height: size)
        }
    }

    private var visibilityBinding: Binding<Bool> {
        Binding(
            get: { model.settings.isEnabled },
            set: { model.setVisible($0) }
        )
    }

    private var compactContentBinding: Binding<CompactNotchContent> {
        Binding(
            get: { model.settings.resolvedCompactContent },
            set: { model.settings.compactContent = $0 }
        )
    }

    private var appearanceBinding: Binding<NotchAppearance> {
        Binding(
            get: { model.settings.resolvedAppearance },
            set: { model.settings.notchAppearance = $0 }
        )
    }

    private var compactTrackInfoBinding: Binding<Bool> {
        Binding(
            get: { model.settings.resolvedCompactMusicShowsTrackInfo },
            set: { model.settings.compactMusicShowsTrackInfo = $0 }
        )
    }

    private var glassMaterialBinding: Binding<GlassMaterialLevel> {
        Binding(
            get: { GlassMaterialLevel.resolve(model.settings.resolvedGlassBlurRadius) },
            set: { model.settings.glassBlurRadius = $0.rawValue }
        )
    }

    private var avoidHardwareNotchBinding: Binding<Bool> {
        Binding(
            get: { model.settings.resolvedAvoidHardwareNotch },
            set: { model.settings.avoidHardwareNotch = $0 }
        )
    }

    private var headerNavigationStyleBinding: Binding<HeaderNavigationStyle> {
        Binding(
            get: { model.settings.resolvedHeaderNavigationStyle },
            set: { model.settings.headerNavigationStyle = $0 }
        )
    }

    private var compactCornerRadiusBinding: Binding<Double> {
        Binding(
            get: { model.settings.resolvedCompactCornerRadius },
            set: { model.settings.compactCornerRadius = $0 }
        )
    }

    private var focusBlockerEnabledBinding: Binding<Bool> {
        Binding(
            get: { model.settings.resolvedFocusBlockerEnabled },
            set: { model.settings.focusBlockerEnabled = $0 }
        )
    }

    private var focusBlockerStrictBinding: Binding<Bool> {
        Binding(
            get: { model.settings.resolvedFocusBlockerStrictPomodoroOnly },
            set: { model.settings.focusBlockerStrictPomodoroOnly = $0 }
        )
    }

    private func paddingBinding(
        _ setting: WritableKeyPath<NotchSettings, Double?>,
        resolved: KeyPath<NotchSettings, Double>
    ) -> Binding<Double> {
        Binding(
            get: { model.settings[keyPath: resolved] },
            set: { model.settings[keyPath: setting] = $0 }
        )
    }
}

// MARK: - Simplified Reusable Components

private struct SidebarTabButton: View {
    let tab: SettingsTab
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: tab.iconName)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.notchAccent : (isHovered ? .white : Color.notchMuted))
                    .frame(width: 16)

                Text(tab.rawValue)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : (isHovered ? .white.opacity(0.9) : Color.notchMuted))

                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.09) : Color.white.opacity(isHovered ? 0.045 : 0.0))
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(Color.notchAccent)
                        .frame(width: 2.5, height: 14)
                        .padding(.leading, 2)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct SettingSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.notchMuted)
                .padding(.leading, 2)

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.7)
            )
        }
    }
}

private struct SettingRow<Control: View>: View {
    let title: String
    var subtitle: String = ""
    @ViewBuilder let control: () -> Control

    init(_ title: String, subtitle: String = "", @ViewBuilder control: @escaping () -> Control) {
        self.title = title
        self.subtitle = subtitle
        self.control = control
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 1.5) {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.notchMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 10)

            control()
        }
    }
}

private struct SettingToggleRow: View {
    let title: String
    var subtitle: String = ""
    @Binding var isOn: Bool

    init(_ title: String, subtitle: String = "", isOn: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
    }

    var body: some View {
        SettingRow(title, subtitle: subtitle) {
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
    }
}

private struct CompactValueSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let suffix: String
    let precision: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text(value.formatted(.number.precision(.fractionLength(precision))) + suffix)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.notchMuted)
            }

            Slider(value: $value, in: range)
                .controlSize(.small)
                .tint(Color.notchAccent)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Live Preview

private struct NotchAppearancePreview: View {
    let appearance: NotchAppearance
    let blurRadius: Double
    let cornerRadius: Double

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.16, green: 0.19, blue: 0.22),
                            Color(red: 0.10, green: 0.12, blue: 0.13)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 16)

            previewSurface
                .frame(width: 200, height: 32)
                .overlay {
                    HStack(spacing: 6) {
                        Image(systemName: appearance == .black ? "circle.lefthalf.filled" : "circle.hexagongrid.fill")
                            .font(.system(size: 9.5, weight: .semibold))
                        Text(appearance.title)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.9))
                }
        }
        .frame(height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.white.opacity(0.11), lineWidth: 0.7)
        )
        .animation(.easeInOut(duration: 0.2), value: appearance)
        .animation(.easeOut(duration: 0.14), value: blurRadius)
        .animation(.easeOut(duration: 0.14), value: cornerRadius)
    }

    private var glassMaterial: Material {
        switch blurRadius {
        case ..<10: return .ultraThinMaterial
        case ..<20: return .thinMaterial
        default: return .regularMaterial
        }
    }

    @ViewBuilder
    private var previewSurface: some View {
        let radius = CGFloat(cornerRadius)
        let shape = AttachedNotchShape(topCornerRadius: radius, bottomCornerRadius: radius)
        switch appearance {
        case .black:
            shape.fill(.black)
        case .liquidGlass:
            if #available(macOS 26.0, *) {
                shape.fill(.clear).glassEffect(.regular, in: shape)
            } else {
                shape
                    .fill(glassMaterial)
                    .overlay(shape.stroke(Color.white.opacity(0.38), lineWidth: 0.8))
            }
        }
    }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 400
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
