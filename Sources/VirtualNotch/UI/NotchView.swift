import AppKit
import SwiftUI

struct NotchView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false
    @State private var displayedWidth: CGFloat = NotchSettings.default.compactWidth
    @State private var displayedHeight: CGFloat = NotchSettings.default.compactHeight

    private var topCornerRadius: CGFloat {
        model.mode == .compact
            ? CGFloat(model.settings.resolvedCompactCornerRadius)
            : 18
    }

    private var bottomCornerRadius: CGFloat {
        switch model.mode {
        case .compact: return CGFloat(model.settings.resolvedCompactCornerRadius)
        case .expanded: return 26
        case .fileDrop, .success: return 30
        }
    }

    private var notchShape: AttachedNotchShape {
        AttachedNotchShape(
            topCornerRadius: topCornerRadius,
            bottomCornerRadius: bottomCornerRadius
        )
    }

    private var shadowOpacity: Double {
        switch model.mode {
        case .compact: return isHovering ? 0.18 : 0
        case .expanded: return 0.38
        case .fileDrop: return 0.62
        case .success: return 0.42
        }
    }

    private var shadowRadius: CGFloat {
        switch model.mode {
        case .compact: return isHovering ? 8 : 0
        case .expanded: return 14
        case .fileDrop: return 20
        case .success: return 16
        }
    }

    private var shadowColor: Color {
        if model.mode == .fileDrop || model.mode == .success {
            return Color.notchAccent.opacity(shadowOpacity)
        }
        switch model.settings.resolvedAppearance {
        case .black:
            return .black.opacity(shadowOpacity)
        case .glassmorphism:
            return Color(red: 0.02, green: 0.06, blue: 0.1).opacity(shadowOpacity * 0.82)
        }
    }

    private var glassMaterial: Material {
        switch model.settings.resolvedGlassBlurRadius {
        case ..<10:
            return .ultraThinMaterial
        case ..<20:
            return .thinMaterial
        default:
            return .regularMaterial
        }
    }

    private var containerAnimation: Animation? {
        guard !reduceMotion else { return nil }
        switch model.mode {
        case .compact:
            return .spring(response: 0.28, dampingFraction: 0.88)
        case .expanded:
            return .spring(response: 0.32, dampingFraction: 0.82, blendDuration: 0.08)
        case .fileDrop:
            return .spring(response: 0.28, dampingFraction: 0.72)
        case .success:
            return .spring(response: 0.28, dampingFraction: 0.82)
        }
    }

    private var contentAnimation: Animation? {
        reduceMotion
            ? .easeOut(duration: 0.12)
            : .easeOut(duration: 0.18).delay(0.08)
    }

    private var contentTransition: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity)
    }

    private var notchWidth: CGFloat {
        model.currentSize.width
    }

    private var notchHeight: CGFloat {
        model.currentSize.height
    }

    private var animationTarget: NotchAnimationTarget {
        NotchAnimationTarget(
            mode: model.mode,
            width: notchWidth,
            height: notchHeight,
            reduceMotion: reduceMotion
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            notchSurface
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .preferredColorScheme(.dark)
        .task(id: animationTarget) {
            await animateContainer(to: animationTarget)
        }
    }

    private var notchContent: some View {
        ZStack(alignment: .top) {
            switch model.mode {
            case .expanded:
                ExpandedNotchView(timer: model.timer, clipboard: model.clipboard)
                    .transition(contentTransition)
            case .fileDrop:
                FileDropView(isTargeted: model.isDraggingFileOver)
                    .transition(contentTransition)
            case .success:
                FileDropSuccessView()
                    .transition(contentTransition)
            case .compact:
                CompactNotchView(music: model.music, timer: model.timer, shelf: model.shelf)
                    .transition(contentTransition)
                    .onTapGesture {
                        model.notchClicked()
                    }
            }
        }
        .animation(contentAnimation, value: model.mode)
    }

    private var animatedNotchContent: some View {
        notchContent
            .frame(width: displayedWidth, height: displayedHeight, alignment: .top)
    }

    @ViewBuilder
    private var styledNotchSurface: some View {
        switch model.settings.resolvedAppearance {
        case .black:
            animatedNotchContent
                .background(Color.black.padding(-50))
                .mask(notchShape.padding(.horizontal, 0.5))
                .shadow(color: shadowColor, radius: shadowRadius)
        case .glassmorphism:
            if #available(macOS 26.0, *) {
                animatedNotchContent
                    .glassEffect(.regular.interactive(), in: notchShape)
            } else {
                animatedNotchContent
                    .background(Rectangle().fill(glassMaterial).padding(-50))
                    .mask(notchShape.padding(.horizontal, 0.5))
                    .overlay {
                        notchShape
                            .stroke(Color.white.opacity(0.4), lineWidth: 0.8)
                            .padding(.horizontal, 0.8)
                            .allowsHitTesting(false)
                    }
                    .shadow(color: shadowColor, radius: shadowRadius)
            }
        }
    }

    private var notchSurface: some View {
        styledNotchSurface
        .contentShape(notchShape)
        .animation(containerAnimation, value: bottomCornerRadius)
        .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.88), value: isHovering)
        .animation(.easeInOut(duration: 0.28), value: model.settings.resolvedAppearance)
        .animation(.easeOut(duration: 0.16), value: model.settings.resolvedGlassBlurRadius)
        .onHover { hovering in
            guard hovering != isHovering else { return }
            isHovering = hovering
            if hovering {
                NSHapticFeedbackManager.defaultPerformer.perform(
                    .alignment,
                    performanceTime: .default
                )
            }
            model.hoverChanged(hovering)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.removeMissingShelfFiles()
        }
    }

    @MainActor
    private func animateContainer(to target: NotchAnimationTarget) async {
        guard !target.reduceMotion else {
            displayedWidth = target.width
            displayedHeight = target.height
            return
        }

        let isGrowing = target.width > displayedWidth || target.height > displayedHeight
        if isGrowing {
            withAnimation(containerAnimation) {
                displayedWidth = target.width
            }
            try? await Task.sleep(nanoseconds: 40_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(containerAnimation) {
                displayedHeight = target.height
            }
        } else {
            withAnimation(containerAnimation) {
                displayedHeight = target.height
            }
            try? await Task.sleep(nanoseconds: 40_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(containerAnimation) {
                displayedWidth = target.width
            }
        }
    }
}

private struct NotchAnimationTarget: Hashable {
    let mode: NotchMode
    let width: CGFloat
    let height: CGFloat
    let reduceMotion: Bool
}
