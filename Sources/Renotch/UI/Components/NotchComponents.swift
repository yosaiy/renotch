import AppKit
import SwiftUI

/// The attached-notch geometry used by DynamicNotchKit's `.notch` style.
/// Adapted from Kai Azim's MIT-licensed DynamicNotchKit.
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
        let curve: CGFloat = 0.552_284_75
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.minX + topRadius, y: rect.minY + topRadius),
            control1: CGPoint(x: rect.minX + topRadius * curve, y: rect.minY),
            control2: CGPoint(x: rect.minX + topRadius, y: rect.minY + topRadius * (1 - curve))
        )
        path.addLine(to: CGPoint(x: rect.minX + topRadius, y: rect.maxY - bottomRadius))
        path.addCurve(
            to: CGPoint(
                x: rect.minX + topRadius + bottomRadius,
                y: rect.maxY
            ),
            control1: CGPoint(
                x: rect.minX + topRadius,
                y: rect.maxY - bottomRadius * (1 - curve)
            ),
            control2: CGPoint(
                x: rect.minX + topRadius + bottomRadius * (1 - curve),
                y: rect.maxY
            )
        )
        path.addLine(
            to: CGPoint(
                x: rect.maxX - topRadius - bottomRadius,
                y: rect.maxY
            )
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX - topRadius, y: rect.maxY - bottomRadius),
            control1: CGPoint(
                x: rect.maxX - topRadius - bottomRadius * (1 - curve),
                y: rect.maxY
            ),
            control2: CGPoint(
                x: rect.maxX - topRadius,
                y: rect.maxY - bottomRadius * (1 - curve)
            )
        )
        path.addLine(to: CGPoint(x: rect.maxX - topRadius, y: rect.minY + topRadius))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control1: CGPoint(x: rect.maxX - topRadius, y: rect.minY + topRadius * (1 - curve)),
            control2: CGPoint(x: rect.maxX - topRadius * curve, y: rect.minY)
        )
        path.closeSubpath()

        return path
    }
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
        case .localhost: return "Servers"
        case .build: return "Build"
        case .docker: return "Docker"
        case .git: return "Git"
        case .deployment: return "Deploy"
        case .terminal: return "Terminal"
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
        case .running: return "LIVE"
        case .success: return "DONE"
        case .failed: return "FAILED"
        case .idle: return "READY"
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

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 5)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color(red: 0.58, green: 0.98, blue: 0.67),
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

extension Color {
    static let notchAccent = Color(red: 0.58, green: 0.98, blue: 0.67)
    static let notchMuted = Color(red: 0.62, green: 0.64, blue: 0.70)
    static let musicAccent = Color(red: 0.96, green: 0.20, blue: 0.36)
}
