import AppKit
import SwiftUI

/// Continuous squircle curvature constants for Apple-grade smooth corners (G2 continuity).
enum ContinuousCurvature {
    static let p1: CGFloat = 0.38    // Ease-in control 1
    static let p2: CGFloat = 0.72    // Ease-in control 2
    static let p3: CGFloat = 0.90    // Corner peak
}

/// The attached-notch geometry with authentic Apple continuous G2 curvature (no corner kinks).
struct AttachedNotchShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let requestedTopRadius = max(0, topCornerRadius)
        let requestedBottomRadius = max(0, bottomCornerRadius)
        let radiusScale = min(
            1,
            rect.height / max(requestedTopRadius + requestedBottomRadius, 1)
        )
        let topRadius = requestedTopRadius * radiusScale
        let bottomRadius = requestedBottomRadius * radiusScale
        var path = Path()

        // Top Left Bezel Ear (Continuous ease-in from screen bezel)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.minX + topRadius, y: rect.minY + topRadius),
            control1: CGPoint(x: rect.minX + topRadius * 0.44, y: rect.minY),
            control2: CGPoint(x: rect.minX + topRadius * 0.88, y: rect.minY + topRadius * 0.42)
        )

        // Left Vertical Edge
        path.addLine(to: CGPoint(x: rect.minX + topRadius, y: rect.maxY - bottomRadius))

        // Bottom Left Corner (Continuous squircle curve)
        path.addCurve(
            to: CGPoint(x: rect.minX + topRadius + bottomRadius, y: rect.maxY),
            control1: CGPoint(x: rect.minX + topRadius, y: rect.maxY - bottomRadius * 0.44),
            control2: CGPoint(x: rect.minX + topRadius + bottomRadius * 0.44, y: rect.maxY)
        )

        // Bottom Horizontal Edge
        path.addLine(to: CGPoint(x: rect.maxX - topRadius - bottomRadius, y: rect.maxY))

        // Bottom Right Corner (Continuous squircle curve)
        path.addCurve(
            to: CGPoint(x: rect.maxX - topRadius, y: rect.maxY - bottomRadius),
            control1: CGPoint(x: rect.maxX - topRadius - bottomRadius * 0.44, y: rect.maxY),
            control2: CGPoint(x: rect.maxX - topRadius, y: rect.maxY - bottomRadius * 0.44)
        )

        // Right Vertical Edge
        path.addLine(to: CGPoint(x: rect.maxX - topRadius, y: rect.minY + topRadius))

        // Top Right Bezel Ear (Continuous ease-out to screen bezel)
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control1: CGPoint(x: rect.maxX - topRadius * 0.88, y: rect.minY + topRadius * 0.42),
            control2: CGPoint(x: rect.maxX - topRadius * 0.44, y: rect.minY)
        )
        path.closeSubpath()

        return path
    }
}

/// Dynamic Gooey Metaball Bridge that simulates fluid liquid tension between primary island and detached bubble.
struct GooeyBridgeShape: Shape {
    var primaryRect: CGRect
    var secondaryRect: CGRect
    var tension: CGFloat // 0.0 = no bridge, 1.0 = strong gooey bridge

    var animatableData: CGFloat {
        get { tension }
        set { tension = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard tension > 0.01 else { return path }

        let pRight = primaryRect.maxX
        let sLeft = secondaryRect.minX
        let gap = sLeft - pRight

        // Only draw bridge if elements are close enough to stretch
        guard gap > 0 && gap < 48 * tension else { return path }

        let topY = max(primaryRect.minY, secondaryRect.minY) + 2
        let pHeight = primaryRect.height - 4
        let sHeight = secondaryRect.height - 4
        let botY = min(primaryRect.minY + pHeight, secondaryRect.minY + sHeight)

        let midX = (pRight + sLeft) / 2
        let stretchFactor = 1.0 - (gap / (48 * tension))
        let pinchAmount = (botY - topY) * 0.38 * (1.0 - stretchFactor)

        let pTop = CGPoint(x: pRight, y: topY)
        let sTop = CGPoint(x: sLeft, y: topY)
        let sBot = CGPoint(x: sLeft, y: botY)
        let pBot = CGPoint(x: pRight, y: botY)

        let midTop = CGPoint(x: midX, y: topY + pinchAmount)
        let midBot = CGPoint(x: midX, y: botY - pinchAmount)

        path.move(to: pTop)
        path.addQuadCurve(to: sTop, control: midTop)
        path.addLine(to: sBot)
        path.addQuadCurve(to: pBot, control: midBot)
        path.closeSubpath()

        return path
    }
}

/// Tuned Apple Fluid Spring Physics for ultra-smooth harmonious motion.
enum DynamicNotchSprings {
    /// Harmonious fluid expansion with Apple-grade smooth settle
    static let fluidExpand = Animation.spring(response: 0.36, dampingFraction: 0.86, blendDuration: 0.10)
    /// Harmonious fluid collapse with silky smooth rhythm
    static let fluidCollapse = Animation.spring(response: 0.32, dampingFraction: 0.88, blendDuration: 0.08)
    /// Subtle bouncy feedback on interactive touch
    static let rubberBounce = Animation.spring(response: 0.26, dampingFraction: 0.75, blendDuration: 0.06)
    /// Fast responsive transition for content switches
    static let snappy = Animation.spring(response: 0.22, dampingFraction: 0.92, blendDuration: 0.05)
}

enum NotchLayout {
    /// Transparent room inside the NSPanel so the hover shadow is not
    /// clipped by the window boundary.
    static let shadowHorizontalPadding: CGFloat = 24
    static let shadowBottomPadding: CGFloat = 28
}

private struct NotchBlurModifier: ViewModifier {
    let radius: CGFloat

    func body(content: Content) -> some View {
        content.blur(radius: radius)
    }
}

private struct NotchScaleModifier: ViewModifier {
    let x: CGFloat
    let y: CGFloat
    let anchor: UnitPoint

    func body(content: Content) -> some View {
        content.scaleEffect(x: x, y: y, anchor: anchor)
    }
}

extension AnyTransition {
    static func notchBlur(radius: CGFloat) -> AnyTransition {
        .modifier(
            active: NotchBlurModifier(radius: radius),
            identity: NotchBlurModifier(radius: 0)
        )
    }

    static func notchScale(
        x: CGFloat = 1,
        y: CGFloat = 1,
        anchor: UnitPoint = .center
    ) -> AnyTransition {
        .modifier(
            active: NotchScaleModifier(x: x, y: y, anchor: anchor),
            identity: NotchScaleModifier(x: 1, y: 1, anchor: anchor)
        )
    }
}

struct NotchIcon: View {
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.57, green: 0.98, blue: 0.66).opacity(0.18))
            Image(systemName: "waveform")
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(Color(red: 0.62, green: 1.0, blue: 0.70))
        }
        .frame(width: size, height: size)
    }
}

struct SectionButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .frame(width: 13)
                if isSelected {
                    Text(title)
                        .lineLimit(1)
                        .fixedSize()
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(isSelected ? .white : .secondary)
            .padding(.horizontal, isSelected ? 10 : 7)
            .frame(height: 26)
            .background(
                Capsule()
                    .fill(isSelected ? Color.white.opacity(0.14) : Color.white.opacity(0.035))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
        .animation(.snappy(duration: 0.24), value: isSelected)
    }
}

struct ActivityStateDot: View {
    let state: DeveloperActivityState

    var body: some View {
        Circle()
            .fill(state.tint)
            .frame(width: 6, height: 6)
            .shadow(color: state.tint.opacity(state == .running ? 0.8 : 0), radius: 4)
            .overlay {
                if state == .running {
                    Circle()
                        .stroke(state.tint.opacity(0.55), lineWidth: 1)
                        .scaleEffect(1.8)
                        .opacity(0.5)
                }
            }
            .accessibilityHidden(true)
    }
}

struct ServerFaviconImage: View {
    let faviconData: Data?
    let fallbackTint: Color
    var size: CGFloat

    var body: some View {
        Group {
            if let faviconData, let favicon = NSImage(data: faviconData) {
                Image(nsImage: favicon)
                    .resizable()
                    .scaledToFit()
            } else {
                fallbackIcon
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var fallbackIcon: some View {
        Image(systemName: "network")
            .font(.system(size: size * 0.62, weight: .semibold))
            .foregroundStyle(fallbackTint)
    }
}

extension DeveloperActivityKind {
    var title: String {
        switch self {
        case .localhost: return "本地服务"
        case .build: return "构建"
        case .docker: return "Docker"
        case .git: return "Git"
        case .deployment: return "部署"
        case .terminal: return "终端"
        }
    }

    var symbol: String {
        switch self {
        case .localhost: return "network"
        case .build: return "hammer.fill"
        case .docker: return "shippingbox.fill"
        case .git: return "arrow.triangle.branch"
        case .deployment: return "icloud.and.arrow.up.fill"
        case .terminal: return "terminal.fill"
        }
    }

    var tint: Color {
        switch self {
        case .localhost: return .notchAccent
        case .build: return Color(red: 0.98, green: 0.72, blue: 0.38)
        case .docker: return Color(red: 0.42, green: 0.72, blue: 0.96)
        case .git: return Color(red: 0.92, green: 0.52, blue: 0.36)
        case .deployment: return Color(red: 0.45, green: 0.82, blue: 0.78)
        case .terminal: return Color(red: 0.72, green: 0.75, blue: 0.80)
        }
    }
}

extension DeveloperActivityState {
    var tint: Color {
        switch self {
        case .running: return .notchAccent
        case .success: return Color(red: 0.46, green: 0.86, blue: 0.57)
        case .failed: return Color(red: 0.96, green: 0.38, blue: 0.38)
        case .idle: return Color.notchMuted
        }
    }

    var compactLabel: String {
        switch self {
        case .running: return "进行中"
        case .success: return "已完成"
        case .failed: return "失败"
        case .idle: return "就绪"
        }
    }
}

struct SmallActionButton: View {
    let title: String
    let icon: String
    var tint: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 11)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.white.opacity(0.09))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct CircularTimerProgress: View {
    let progress: Double
    let text: String
    var tint: Color = Color.notchAccent

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 5)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .frame(width: 64, height: 64)
    }
}

extension PomodoroMode {
    var tint: Color {
        switch self {
        case .focus:
            return Color.notchAccent
        case .breakTime:
            return Color(red: 0.42, green: 0.78, blue: 0.98)
        }
    }
}

extension Color {
    static let notchAccent = Color(red: 0.58, green: 0.98, blue: 0.67)
    static let notchMuted = Color(red: 0.62, green: 0.64, blue: 0.70)
    static let musicAccent = Color(red: 0.96, green: 0.20, blue: 0.36)
}

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .fullScreenUI
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        visualEffectView.translatesAutoresizingMaskIntoConstraints = true
        visualEffectView.autoresizingMask = [.width, .height]
        return visualEffectView
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
