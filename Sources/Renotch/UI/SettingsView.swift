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
    case privacy = "Privacy"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .general: return "switch.2"
        case .appearance: return "sparkles"
        case .privacy: return "hand.raised.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .general: return "Behavior, display target & timing"
        case .appearance: return "Notch style, sizing & padding"
        case .privacy: return "Clipboard history & permissions"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var screenManager: ScreenManager
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        HStack(spacing: 0) {
            sidebarView
                .frame(width: 200)
                .background(
                    ZStack {
                        VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow)
                        Color.black.opacity(0.2)
                    }
                )

            Divider()
                .opacity(0.15)

            detailContentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    ZStack {
                        Color(nsColor: .windowBackgroundColor).opacity(0.85)
                        VisualEffectBlur(material: .underWindowBackground, blendingMode: .behindWindow)
                    }
                )
        }
        .frame(minWidth: 760, idealWidth: 960, maxWidth: .infinity, minHeight: 500, idealHeight: 640, maxHeight: .infinity)
        .preferredColorScheme(.dark)
    }

    // MARK: - Sidebar

    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // App Header Branding
            HStack(spacing: 10) {
                appIconView(size: 32)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Re:notch")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("Preferences")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 16)

            Divider()
                .opacity(0.12)
                .padding(.horizontal, 10)

            // Sidebar Tabs
            VStack(spacing: 4) {
                ForEach(SettingsTab.allCases) { tab in
                    SidebarTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            // Footer info / Restore Defaults button
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        model.resetSettings()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11, weight: .medium))
                        Text("Restore Defaults")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)

                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                    Text("Version \(version)")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 4)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Detail Content Canvas

    private var detailContentView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 20) {
                // Header Title
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedTab.rawValue)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text(selectedTab.subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 4)

                switch selectedTab {
                case .general:
                    generalTabContent
                case .appearance:
                    appearanceTabContent
                case .privacy:
                    privacyTabContent
                }
            }
            .padding(24)
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }

    // MARK: - General Tab Content

    private var generalTabContent: some View {
        VStack(spacing: 16) {
            // Behavior Card
            SettingCard(title: "Behavior", icon: "gearshape.fill", iconColor: .blue) {
                VStack(spacing: 0) {
                    SettingRow(
                        title: "Show Re:notch",
                        subtitle: "Enable or hide the notch interface"
                    ) {
                        Toggle("", isOn: visibilityBinding)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    Divider().opacity(0.12).padding(.vertical, 8)

                    SettingRow(
                        title: "Launch at login",
                        subtitle: "Automatically start Re:notch on startup"
                    ) {
                        Toggle("", isOn: $model.settings.launchAtLogin)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    Divider().opacity(0.12).padding(.vertical, 8)

                    SettingRow(
                        title: "Default compact view",
                        subtitle: "Choose default widget for compact notch"
                    ) {
                        Picker("", selection: compactContentBinding) {
                            ForEach(CompactNotchContent.allCases) { content in
                                Text(content.title).tag(content)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 140)
                    }

                    Divider().opacity(0.12).padding(.vertical, 8)

                    SettingRow(
                        title: "Expand on hover",
                        subtitle: "Open full notch view when mouse hovers over notch"
                    ) {
                        Toggle("", isOn: $model.settings.expandOnHover)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    Divider().opacity(0.12).padding(.vertical, 8)

                    SettingRow(
                        title: "Expand on click",
                        subtitle: "Expand notch on mouse click"
                    ) {
                        Toggle("", isOn: $model.settings.expandOnClick)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    Divider().opacity(0.12).padding(.vertical, 8)

                    SettingRow(
                        title: "Always on top",
                        subtitle: "Keep notch window floating above regular app windows"
                    ) {
                        Toggle("", isOn: $model.settings.alwaysOnTop)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    Divider().opacity(0.12).padding(.vertical, 8)

                    SettingRow(
                        title: "Show over full-screen apps",
                        subtitle: "Maintain visibility even in full-screen space"
                    ) {
                        Toggle("", isOn: $model.settings.showOnFullscreen)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                }
            }

            // Display Card
            SettingCard(title: "Display & Timing", icon: "display", iconColor: .purple) {
                VStack(spacing: 0) {
                    SettingRow(
                        title: "Target monitor",
                        subtitle: "Select display to attach the Re:notch overlay"
                    ) {
                        Picker("", selection: $model.settings.targetDisplayID) {
                            Text("Main display").tag(nil as UInt32?)
                            ForEach(screenManager.displays) { display in
                                Text(display.name).tag(Optional(display.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 160)
                    }

                    Divider().opacity(0.12).padding(.vertical, 12)

                    AppleValueSlider(
                        title: "Collapse delay",
                        subtitle: "Time before notch shrinks back after pointer leaves",
                        value: $model.settings.collapseDelay,
                        range: 0.3...1.2,
                        suffix: "s",
                        precision: 1
                    )

                    Divider().opacity(0.12).padding(.vertical, 12)

                    AppleValueSlider(
                        title: "Top offset",
                        subtitle: "Vertical distance from the top edge of screen",
                        value: $model.settings.verticalOffset,
                        range: 0...40,
                        suffix: " pt",
                        precision: 0
                    )
                }
            }

            if let error = model.settingsError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.red.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.red.opacity(0.2), lineWidth: 0.8)
                )
            }
        }
    }

    // MARK: - Appearance Tab Content

    private var appearanceTabContent: some View {
        VStack(spacing: 16) {
            // Notch Style Card
            SettingCard(title: "Notch Style", icon: "paintpalette.fill", iconColor: .indigo) {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Surface Material")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)

                        Picker("Surface", selection: appearanceBinding) {
                            ForEach(NotchAppearance.allCases) { appearance in
                                Text(appearance.title).tag(appearance)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    if model.settings.resolvedAppearance == .liquidGlass,
                       #unavailable(macOS 26.0) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Frosted Material Blur Level")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)

                            Picker("Frosted blur", selection: glassMaterialBinding) {
                                ForEach(GlassMaterialLevel.allCases) { level in
                                    Text(level.title).tag(level)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    NotchAppearancePreview(
                        appearance: model.settings.resolvedAppearance,
                        blurRadius: model.settings.resolvedGlassBlurRadius,
                        cornerRadius: model.settings.resolvedCompactCornerRadius
                    )

                    Text(appearanceDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: model.settings.resolvedAppearance)

            // Compact Notch Section Card
            SettingCard(title: "Compact Notch Dimensions", icon: "rectangle.compress.vertical", iconColor: .cyan) {
                VStack(spacing: 0) {
                    SettingRow(
                        title: "Show song name & artist",
                        subtitle: "Applies to Music view. When off, only artwork and audio waveform appear."
                    ) {
                        Toggle("", isOn: compactTrackInfoBinding)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    Divider().opacity(0.12).padding(.vertical, 12)

                    AppleValueSlider(
                        title: "Width",
                        subtitle: "Compact width of the notch",
                        value: $model.settings.compactWidth,
                        range: NotchSettings.compactWidthRange,
                        suffix: " pt",
                        precision: 0
                    )

                    Divider().opacity(0.12).padding(.vertical, 12)

                    AppleValueSlider(
                        title: "Height",
                        subtitle: "Compact height of the notch",
                        value: $model.settings.compactHeight,
                        range: NotchSettings.compactHeightRange,
                        suffix: " pt",
                        precision: 0
                    )

                    Divider().opacity(0.12).padding(.vertical, 12)

                    AppleValueSlider(
                        title: "Corner radius",
                        subtitle: "Outer bottom corner radius",
                        value: compactCornerRadiusBinding,
                        range: NotchSettings.compactCornerRadiusRange,
                        suffix: " pt",
                        precision: 0
                    )

                    Group {
                        Divider().opacity(0.12).padding(.vertical, 12)

                        AppleValueSlider(
                            title: "Left padding",
                            subtitle: "Inner left margin",
                            value: paddingBinding(
                                \.compactContentLeadingPadding,
                                resolved: \.resolvedCompactContentLeadingPadding
                            ),
                            range: NotchSettings.compactContentHorizontalPaddingRange,
                            suffix: " pt",
                            precision: 0
                        )

                        Divider().opacity(0.12).padding(.vertical, 12)

                        AppleValueSlider(
                            title: "Right padding",
                            subtitle: "Inner right margin",
                            value: paddingBinding(
                                \.compactContentTrailingPadding,
                                resolved: \.resolvedCompactContentTrailingPadding
                            ),
                            range: NotchSettings.compactContentHorizontalPaddingRange,
                            suffix: " pt",
                            precision: 0
                        )

                        Divider().opacity(0.12).padding(.vertical, 12)

                        AppleValueSlider(
                            title: "Top padding",
                            subtitle: "Inner top margin",
                            value: paddingBinding(
                                \.compactContentTopPadding,
                                resolved: \.resolvedCompactContentTopPadding
                            ),
                            range: NotchSettings.compactContentVerticalPaddingRange,
                            suffix: " pt",
                            precision: 0
                        )

                        Divider().opacity(0.12).padding(.vertical, 12)

                        AppleValueSlider(
                            title: "Bottom padding",
                            subtitle: "Inner bottom margin",
                            value: paddingBinding(
                                \.compactContentBottomPadding,
                                resolved: \.resolvedCompactContentBottomPadding
                            ),
                            range: NotchSettings.compactContentVerticalPaddingRange,
                            suffix: " pt",
                            precision: 0
                        )
                    }
                }
            }

            // Hardware Notch & Navigation Card
            SettingCard(title: "Hardware Notch & Navigation", icon: "laptopcomputer.and.ipad", iconColor: .blue) {
                VStack(spacing: 0) {
                    SettingRow(
                        title: "Avoid MacBook Hardware Notch",
                        subtitle: "Adds top clearance so header icons are never covered by the physical MacBook screen notch"
                    ) {
                        Toggle("", isOn: avoidHardwareNotchBinding)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    Divider().opacity(0.12).padding(.vertical, 12)

                    SettingRow(
                        title: "Navigation Bar Style",
                        subtitle: model.settings.resolvedHeaderNavigationStyle.subtitle
                    ) {
                        Picker("", selection: headerNavigationStyleBinding) {
                            ForEach(HeaderNavigationStyle.allCases) { style in
                                Text(style.title).tag(style)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 190)
                    }
                }
            }

            // Expanded Notch Section Card
            SettingCard(title: "Expanded Notch Dimensions", icon: "rectangle.expand.vertical", iconColor: .orange) {
                VStack(spacing: 0) {
                    AppleValueSlider(
                        title: "Width",
                        subtitle: "Expanded width of the open notch panel",
                        value: $model.settings.expandedWidth,
                        range: NotchSettings.expandedWidthRange,
                        suffix: " pt",
                        precision: 0
                    )

                    Divider().opacity(0.12).padding(.vertical, 12)

                    SettingRow(
                        title: "Quick Width Preset",
                        subtitle: "Match expanded width directly to compact width"
                    ) {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                model.settings.expandedWidth = model.settings.compactWidth
                            }
                        } label: {
                            Label("Match compact width", systemImage: "arrow.right.to.line")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(model.settings.expandedWidth == model.settings.compactWidth)
                    }

                    Divider().opacity(0.12).padding(.vertical, 12)

                    AppleValueSlider(
                        title: "Height",
                        subtitle: "Expanded height when open",
                        value: $model.settings.expandedHeight,
                        range: NotchSettings.expandedHeightRange,
                        suffix: " pt",
                        precision: 0
                    )

                    Divider().opacity(0.12).padding(.vertical, 12)

                    AppleValueSlider(
                        title: "Left padding",
                        subtitle: "Expanded inner left margin",
                        value: paddingBinding(
                            \.expandedContentLeadingPadding,
                            resolved: \.resolvedExpandedContentLeadingPadding
                        ),
                        range: NotchSettings.expandedContentPaddingRange,
                        suffix: " pt",
                        precision: 0
                    )

                    Divider().opacity(0.12).padding(.vertical, 12)

                    AppleValueSlider(
                        title: "Right padding",
                        subtitle: "Expanded inner right margin",
                        value: paddingBinding(
                            \.expandedContentTrailingPadding,
                            resolved: \.resolvedExpandedContentTrailingPadding
                        ),
                        range: NotchSettings.expandedContentPaddingRange,
                        suffix: " pt",
                        precision: 0
                    )

                    Divider().opacity(0.12).padding(.vertical, 12)

                    AppleValueSlider(
                        title: "Top padding",
                        subtitle: "Expanded inner top margin",
                        value: paddingBinding(
                            \.expandedContentTopPadding,
                            resolved: \.resolvedExpandedContentTopPadding
                        ),
                        range: NotchSettings.expandedContentPaddingRange,
                        suffix: " pt",
                        precision: 0
                    )

                    Divider().opacity(0.12).padding(.vertical, 12)

                    AppleValueSlider(
                        title: "Bottom padding",
                        subtitle: "Expanded inner bottom margin",
                        value: paddingBinding(
                            \.expandedContentBottomPadding,
                            resolved: \.resolvedExpandedContentBottomPadding
                        ),
                        range: NotchSettings.expandedContentPaddingRange,
                        suffix: " pt",
                        precision: 0
                    )
                }
            }
        }
    }

    // MARK: - Privacy Tab Content

    private var privacyTabContent: some View {
        VStack(spacing: 16) {
            // Clipboard History Card
            SettingCard(title: "Clipboard History", icon: "doc.on.clipboard.fill", iconColor: .green) {
                VStack(spacing: 0) {
                    SettingRow(
                        title: "Save clipboard history",
                        subtitle: "Store up to 20 recent text items locally on this Mac. Concealed/password items are skipped."
                    ) {
                        Toggle("", isOn: $model.settings.clipboardHistoryEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    Divider().opacity(0.12).padding(.vertical, 12)

                    SettingRow(
                        title: "Stored Items",
                        subtitle: "\(model.clipboard.items.count) item\(model.clipboard.items.count == 1 ? "" : "s") currently saved in history"
                    ) {
                        Button("Clear History", role: .destructive) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                model.clipboard.clear()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(.red.opacity(0.8))
                        .disabled(model.clipboard.items.isEmpty)
                    }
                }
            }

            // Notifications Card
            SettingCard(title: "Notifications", icon: "bell.badge.fill", iconColor: .pink) {
                SettingRow(
                    title: "Notify when timers finish",
                    subtitle: "Send a system notification banner when a timer reaches zero"
                ) {
                    Toggle("", isOn: $model.settings.timerNotificationsEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            }

            // About Card
            SettingCard(title: "About & Privacy Guarantee", icon: "shield.checkerboard", iconColor: .blue) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        appIconView(size: 38)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Re:notch")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)

                            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.0")")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.green)
                    }

                    Divider().opacity(0.12)

                    HStack(spacing: 10) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)

                        Text("No account, cloud sync, or background analytics. All your data stays strictly local on this Mac.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineSpacing(2)
                    }
                }
            }
        }
    }

    // MARK: - Bindings & Helpers

    @ViewBuilder
    private func appIconView(size: CGFloat) -> some View {
        if let icon = NSApp.applicationIconImage {
            Image(nsImage: icon)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.35), radius: 3, y: 1.5)
        } else if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
                  let icon = NSImage(contentsOf: iconURL) {
            Image(nsImage: icon)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.35), radius: 3, y: 1.5)
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

    private func paddingBinding(
        _ setting: WritableKeyPath<NotchSettings, Double?>,
        resolved: KeyPath<NotchSettings, Double>
    ) -> Binding<Double> {
        Binding(
            get: { model.settings[keyPath: resolved] },
            set: { model.settings[keyPath: setting] = $0 }
        )
    }

    private var appearanceDescription: String {
        switch model.settings.resolvedAppearance {
        case .black:
            return "A solid deep black surface engineered to seamlessly merge with physical MacBook display cutouts."
        case .liquidGlass:
            if #available(macOS 26.0, *) {
                return "Apple Liquid Glass material that dynamically refracts background color and light."
            }
            return "A translucent frosted material fallback for macOS versions prior to native Liquid Glass."
        }
    }
}

// MARK: - Reusable Apple Design Components

private struct SidebarTabButton: View {
    let tab: SettingsTab
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: tab.iconName)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.white : (isHovered ? .primary : .secondary))
                    .frame(width: 18)

                Text(tab.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.white : (isHovered ? .primary : .secondary))

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.white.opacity(0.16), lineWidth: 0.8)
                            )
                            .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                    } else if isHovered {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                    }
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct SettingCard<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.2))

                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(iconColor)
                }
                .frame(width: 22, height: 22)

                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                Spacer()
            }

            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.white.opacity(0.03)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
    }
}

private struct SettingRow<Control: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let control: () -> Control

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 12)

            control()
        }
    }
}

private struct AppleValueSlider: View {
    let title: String
    let subtitle: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let suffix: String
    let precision: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)

                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(value.formatted(.number.precision(.fractionLength(precision))) + suffix)
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                            )
                    )
            }

            Slider(value: $value, in: range)
                .tint(.accentColor)
        }
    }
}

// MARK: - Live Preview Component

private struct NotchAppearancePreview: View {
    let appearance: NotchAppearance
    let blurRadius: Double
    let cornerRadius: Double

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.15, blue: 0.34),
                            Color(red: 0.28, green: 0.08, blue: 0.38)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(Color.cyan.opacity(0.75))
                .frame(width: 92, height: 92)
                .blur(radius: 24)
                .offset(x: -166, y: 20)

            Circle()
                .fill(Color.purple.opacity(0.7))
                .frame(width: 104, height: 104)
                .blur(radius: 28)
                .offset(x: 176, y: -18)

            previewSurface
                .frame(width: 210, height: 34)

            HStack(spacing: 7) {
                Image(systemName: appearance == .black ? "circle.lefthalf.filled" : "circle.hexagongrid.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text(appearance.title)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.88))
        }
        .frame(height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
        .animation(.easeInOut(duration: 0.25), value: appearance)
        .animation(.easeOut(duration: 0.16), value: blurRadius)
        .animation(.easeOut(duration: 0.16), value: cornerRadius)
    }

    private var glassMaterial: Material {
        switch blurRadius {
        case ..<10:
            return .ultraThinMaterial
        case ..<20:
            return .thinMaterial
        default:
            return .regularMaterial
        }
    }

    @ViewBuilder
    private var previewSurface: some View {
        let radius = CGFloat(cornerRadius)
        let shape = AttachedNotchShape(
            topCornerRadius: radius,
            bottomCornerRadius: radius
        )
        switch appearance {
        case .black:
            shape.fill(.black)
        case .liquidGlass:
            if #available(macOS 26.0, *) {
                shape
                    .fill(.clear)
                    .glassEffect(.regular, in: shape)
            } else {
                shape
                    .fill(glassMaterial)
                    .overlay(shape.stroke(Color.white.opacity(0.4), lineWidth: 0.8))
                    .shadow(color: Color.black.opacity(0.3), radius: 8, y: 4)
            }
        }
    }
}

// MARK: - Visual Effect Blur Helper

private struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
