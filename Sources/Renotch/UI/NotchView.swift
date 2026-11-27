import AppKit
import SwiftUI

struct NotchView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    private var isEnlargedOnHover: Bool {
        model.mode == .compact && model.isHovered && model.settings.expandOnHover
    }

    private var topCornerRadius: CGFloat {
        switch model.mode {
        case .compact:
            return CGFloat(model.settings.resolvedCompactCornerRadius) + (isEnlargedOnHover ? 2 : 0)
        case .expanded, .fileDrop, .success:
            return 18
        case .focusTakeover:
            return 0
        }
    }

    private var bottomCornerRadius: CGFloat {
        switch model.mode {
        case .compact:
            return CGFloat(model.settings.resolvedCompactCornerRadius) + (isEnlargedOnHover ? 4 : 0)
        case .expanded:
            return 26
        case .fileDrop, .success:
            return 30
        case .focusTakeover:
            return 0
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
        case .compact: return isEnlargedOnHover ? 0.28 : 0.08
        case .expanded: return 0.42
        case .fileDrop: return 0.65
        case .success: return 0.45
        case .focusTakeover: return 0.65
        }
    }

    private var shadowRadius: CGFloat {
        switch model.mode {
        case .compact: return isEnlargedOnHover ? 16 : 4
        case .expanded: return 16
        case .fileDrop: return 22
        case .success: return 18
        case .focusTakeover: return 32
        }
    }

    private var shadowColor: Color {
        switch model.settings.resolvedAppearance {
        case .black:
            return .black.opacity(shadowOpacity)
        case .liquidGlass:
            return Color(red: 0.02, green: 0.06, blue: 0.1).opacity(shadowOpacity * 0.85)
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
            return DynamicNotchSprings.fluidCollapse
        case .expanded:
            return DynamicNotchSprings.fluidExpand
        case .fileDrop:
            return DynamicNotchSprings.rubberBounce
        case .success:
            return DynamicNotchSprings.rubberBounce
        case .focusTakeover:
            return .spring(response: 0.48, dampingFraction: 0.90)
        }
    }

    private var notchWidth: CGFloat {
        model.currentSize.width
    }

    private var notchHeight: CGFloat {
        model.currentSize.height
    }

    var body: some View {
        ZStack(alignment: .top) {
            if model.mode == .focusTakeover {
                FocusTakeoverView(
                    timer: model.timer,
                    site: model.focusTakeoverSite,
                    appName: model.focusTakeoverAppName
                )
                .transition(.opacity)
            } else {
                unifiedIslandSurface
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .preferredColorScheme(.dark)
    }

    // MARK: - Unified Island Surface

    private var unifiedIslandSurface: some View {
        styledUnifiedSurface
            .contentShape(notchShape)
            .onTapGesture {
                if model.mode == .compact {
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                    withAnimation(reduceMotion ? nil : DynamicNotchSprings.fluidExpand) {
                        model.notchClicked()
                    }
                }
            }
            .animation(containerAnimation, value: model.currentSize)
            .animation(containerAnimation, value: model.mode)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: model.settings.resolvedAppearance)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: model.settings.resolvedGlassBlurRadius)
            .onHover { hovering in
                guard hovering != isHovering else { return }
                isHovering = hovering
                if hovering {
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                }
                withAnimation(reduceMotion ? nil : DynamicNotchSprings.fluidHover) {
                    model.hoverChanged(hovering)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                model.removeMissingShelfFiles()
            }
    }

    @ViewBuilder
    private var styledUnifiedSurface: some View {
        let content = notchContent
            .frame(width: notchWidth, height: notchHeight, alignment: .top)
            .clipped()

        switch model.settings.resolvedAppearance {
        case .black:
            content
                .background(Color.black.padding(-50))
                .mask(notchShape.padding(.horizontal, 0.5))
                .overlay {
                    notchShape
                        .stroke(
                            model.mode == .fileDrop || model.mode == .success
                                ? Color.notchAccent.opacity(0.35)
                                : Color.white.opacity(isEnlargedOnHover ? 0.12 : 0.0),
                            lineWidth: model.mode == .fileDrop || model.mode == .success ? 1 : 0.6
                        )
                        .padding(.horizontal, 0.5)
                        .allowsHitTesting(false)
                }
                .shadow(color: shadowColor, radius: shadowRadius)
        case .liquidGlass:
            if #available(macOS 26.0, *) {
                content
                    .glassEffect(.regular.interactive(), in: notchShape)
            } else {
                content
                    .background(Rectangle().fill(glassMaterial).padding(-50))
                    .mask(notchShape.padding(.horizontal, 0.5))
                    .overlay {
                        notchShape
                            .stroke(Color.white.opacity(isEnlargedOnHover ? 0.52 : 0.38), lineWidth: 0.8)
                            .padding(.horizontal, 0.8)
                            .allowsHitTesting(false)
                    }
                    .shadow(color: shadowColor, radius: shadowRadius)
            }
        }
    }

    // MARK: - Notch Content Switcher

    private var notchContent: some View {
        ZStack(alignment: .top) {
            if model.mode == .expanded {
                ExpandedNotchView(timer: model.timer)
                    .frame(
                        width: notchWidth,
                        height: notchHeight,
                        alignment: .top
                    )
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .offset(y: -4)),
                            removal: .opacity.combined(with: .offset(y: -8))
                        )
                    )
            } else if model.mode == .fileDrop {
                FileDropView(isTargeted: model.isDraggingFileOver)
                    .transition(.opacity)
            } else if model.mode == .success {
                FileDropSuccessView()
                    .transition(.opacity)
            } else if model.mode == .compact {
                CompactNotchView(
                    music: model.music,
                    browser: model.browser,
                    timer: model.timer,
                    shelf: model.shelf,
                    activity: model.activity,
                    todos: model.todos
                )
                .frame(width: notchWidth, height: notchHeight, alignment: .center)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .opacity.combined(with: .scale(scale: 0.90))
                    )
                )
            }
        }
    }
}
