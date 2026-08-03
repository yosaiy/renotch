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

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var screenManager: ScreenManager

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "switch.2") }
            appearanceTab
                .tabItem { Label("Appearance", systemImage: "capsule.tophalf.filled") }
            privacyTab
                .tabItem { Label("Privacy", systemImage: "hand.raised") }
        }
        .padding(20)
        .frame(width: 540, height: 430)
        .preferredColorScheme(.dark)
    }

    private var generalTab: some View {
        Form {
            Section("Behavior") {
                Toggle("Show Virtual Notch", isOn: visibilityBinding)
                Toggle("Launch at login", isOn: $model.settings.launchAtLogin)
                Picker("Default compact view", selection: compactContentBinding) {
                    ForEach(CompactNotchContent.allCases) { content in
                        Text(content.title).tag(content)
                    }
                }
                Toggle("Expand on hover", isOn: $model.settings.expandOnHover)
                Toggle("Expand on click", isOn: $model.settings.expandOnClick)
                Toggle("Always on top", isOn: $model.settings.alwaysOnTop)
                Toggle("Show over full-screen apps", isOn: $model.settings.showOnFullscreen)
            }

            Section("Display") {
                Picker("Target monitor", selection: $model.settings.targetDisplayID) {
                    Text("Main display").tag(nil as UInt32?)
                    ForEach(screenManager.displays) { display in
                        Text(display.name).tag(Optional(display.id))
                    }
                }

                ValueSlider(
                    title: "Collapse delay",
                    value: $model.settings.collapseDelay,
                    range: 0.3...1.2,
                    suffix: "s",
                    precision: 1
                )
                ValueSlider(
                    title: "Top offset",
                    value: $model.settings.verticalOffset,
                    range: 0...40,
                    suffix: " pt",
                    precision: 0
                )
            }

            if let error = model.settingsError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
    }

    private var appearanceTab: some View {
        Form {
            Section("Notch style") {
                Picker("Surface", selection: appearanceBinding) {
                    ForEach(NotchAppearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                }
                .pickerStyle(.segmented)

                if model.settings.resolvedAppearance == .glassmorphism,
                   #unavailable(macOS 26.0) {
                    Picker("Frosted blur", selection: glassMaterialBinding) {
                        ForEach(GlassMaterialLevel.allCases) { level in
                            Text(level.title).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
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
            }
            .animation(.easeInOut(duration: 0.24), value: model.settings.resolvedAppearance)

            Section("Compact notch") {
                ValueSlider(
                    title: "Width",
                    value: $model.settings.compactWidth,
                    range: NotchSettings.compactWidthRange,
                    suffix: " pt",
                    precision: 0
                )
                ValueSlider(
                    title: "Height",
                    value: $model.settings.compactHeight,
                    range: NotchSettings.compactHeightRange,
                    suffix: " pt",
                    precision: 0
                )
                ValueSlider(
                    title: "Corner radius",
                    value: compactCornerRadiusBinding,
                    range: NotchSettings.compactCornerRadiusRange,
                    suffix: " pt",
                    precision: 0
                )
            }

            Section("Expanded notch") {
                ValueSlider(
                    title: "Width",
                    value: $model.settings.expandedWidth,
                    range: NotchSettings.expandedWidthRange,
                    suffix: " pt",
                    precision: 0
                )
                ValueSlider(
                    title: "Height",
                    value: $model.settings.expandedHeight,
                    range: NotchSettings.expandedHeightRange,
                    suffix: " pt",
                    precision: 0
                )
            }

            HStack {
                Spacer()
                Button("Restore Defaults") { model.resetSettings() }
            }
        }
        .formStyle(.grouped)
    }

    private var privacyTab: some View {
        Form {
            Section("Clipboard history") {
                Toggle("Save clipboard history", isOn: $model.settings.clipboardHistoryEnabled)
                Text("Up to 20 text items are stored locally on this Mac. Consecutive duplicates and pasteboard entries marked as concealed, transient, or password data are ignored.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Text("Stored items")
                    Spacer()
                    Text("\(model.clipboard.items.count)")
                        .foregroundStyle(.secondary)
                    Button("Clear History", role: .destructive) { model.clipboard.clear() }
                        .disabled(model.clipboard.items.isEmpty)
                }
            }

            Section("Notifications") {
                Toggle("Notify when timers finish", isOn: $model.settings.timerNotificationsEnabled)
            }

            Section("About") {
                LabeledContent("Virtual Notch", value: "1.0.0")
                Text("No account, cloud sync, or analytics. Your data stays on this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
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

    private var glassMaterialBinding: Binding<GlassMaterialLevel> {
        Binding(
            get: { GlassMaterialLevel.resolve(model.settings.resolvedGlassBlurRadius) },
            set: { model.settings.glassBlurRadius = $0.rawValue }
        )
    }

    private var compactCornerRadiusBinding: Binding<Double> {
        Binding(
            get: { model.settings.resolvedCompactCornerRadius },
            set: { model.settings.compactCornerRadius = $0 }
        )
    }

    private var appearanceDescription: String {
        switch model.settings.resolvedAppearance {
        case .black:
            return "A solid black surface that matches the MacBook display cutout."
        case .glassmorphism:
            if #available(macOS 26.0, *) {
                return "Apple Liquid Glass that reflects nearby color and light, with native pointer interaction."
            }
            return "A frosted material fallback for macOS versions before Liquid Glass."
        }
    }
}

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
        .frame(height: 58)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
        case .glassmorphism:
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

private struct ValueSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let suffix: String
    let precision: Int

    var body: some View {
        HStack {
            Text(title)
                .frame(width: 100, alignment: .leading)
            Slider(value: $value, in: range)
            Text(value.formatted(.number.precision(.fractionLength(precision))) + suffix)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .trailing)
        }
    }
}
