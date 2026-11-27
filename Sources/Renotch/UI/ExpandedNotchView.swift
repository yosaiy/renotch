import SwiftUI

struct ExpandedNotchView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var timer: TimerService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isCollapseHovered = false

    var body: some View {
        VStack(spacing: 0) {
            if model.selectedSection == .welcome {
                WelcomeView()
            } else {
                header

                Divider()
                    .overlay(Color.white.opacity(0.08))
                    .padding(.top, 8)

                visibleContent
                .padding(.top, 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
                .animation(.easeOut(duration: 0.16), value: model.selectedSection)
                .animation(.easeOut(duration: 0.16), value: model.activeMediaSource)
                .animation(.easeOut(duration: 0.16), value: model.expandedSectionOverride)

                if model.settings.resolvedHeaderNavigationStyle == .bottomDock {
                    Divider()
                        .overlay(Color.white.opacity(0.08))
                        .padding(.vertical, 6)

                    bottomDockView
                }
            }
        }
        .padding(.leading, model.settings.resolvedExpandedContentLeadingPadding + 14)
        .padding(.trailing, model.settings.resolvedExpandedContentTrailingPadding + 14)
        .padding(.top, model.settings.resolvedExpandedContentTopPadding + 4)
        .padding(.bottom, model.settings.resolvedExpandedContentBottomPadding + 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var visibleContent: some View {
        selectedSectionContent
    }

    @ViewBuilder
    private var selectedSectionContent: some View {
        switch model.selectedSection {
        case .dashboard:
            DashboardView(
                music: model.music,
                activity: model.activity,
                shelf: model.shelf,
                timer: timer,
                todos: model.todos,
                calendar: model.calendar,
                navigate: select
            )
        case .activity:
            DeveloperActivityView(service: model.activity)
        case .music:
            if model.activeMediaSource == .browser,
               let media = model.browser.media {
                ExpandedBrowserMediaView(media: media, artwork: model.browser.mediaArtwork)
            } else {
                MusicPlayerView(music: model.music)
            }
        case .timer:
            TimerView(timer: timer)
        case .blocker:
            FocusBlockerView(blocker: model.focusBlocker, timer: timer)
        case .calendar:
            CalendarView(service: model.calendar)
        case .shelf:
            FileShelfView(shelf: model.shelf)
        case .todo:
            TodoView(store: model.todos)
        case .welcome:
            WelcomeView()
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            DashboardHeaderButton(isSelected: isSelected(.dashboard)) {
                select(.dashboard)
            }

            Spacer(minLength: 12)

            if model.settings.resolvedHeaderNavigationStyle != .bottomDock {
                HStack(spacing: 2) {
                    SectionButton(
                        title: "Music",
                        icon: "waveform",
                        isSelected: isSelected(.music)
                    ) { select(.music) }
                    SectionButton(
                        title: "Coding",
                        icon: "chevron.left.forwardslash.chevron.right",
                        isSelected: isSelected(.activity)
                    ) { select(.activity) }
                    SectionButton(
                        title: "File Shelf",
                        icon: "tray.full.fill",
                        isSelected: isSelected(.shelf)
                    ) { select(.shelf) }
                    SectionButton(
                        title: "Timer",
                        icon: "timer",
                        isSelected: isSelected(.timer)
                    ) { select(.timer) }
                    SectionButton(
                        title: "Blocker",
                        icon: "shield.lefthalf.filled",
                        isSelected: isSelected(.blocker)
                    ) { select(.blocker) }
                    SectionButton(
                        title: "Todos",
                        icon: "checklist",
                        isSelected: isSelected(.todo)
                    ) { select(.todo) }
                    SectionButton(
                        title: "Calendar",
                        icon: "calendar",
                        isSelected: isSelected(.calendar)
                    ) { select(.calendar) }
                }
            }

            if timer.isActive {
                HStack(spacing: 4) {
                    Circle()
                        .fill(timer.currentMode.tint)
                        .frame(width: 5, height: 5)
                    Text(TimerService.formatted(timer.remaining))
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(timer.currentMode.tint)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(
                    Capsule()
                        .fill(timer.currentMode.tint.opacity(0.14))
                )
                .overlay(
                    Capsule()
                        .stroke(timer.currentMode.tint.opacity(0.25), lineWidth: 0.5)
                )
                .fixedSize()
            }

            Button {
                withAnimation(reduceMotion ? nil : DynamicNotchSprings.fluidCollapse) {
                    model.collapse(force: true)
                }
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isCollapseHovered ? .white : Color.notchMuted)
                    .frame(width: 25, height: 25)
                    .background(Circle().fill(Color.white.opacity(isCollapseHovered ? 0.14 : 0.07)))
                    .contentShape(Circle())
            }
            .buttonStyle(NotchPressButtonStyle())
            .onHover { isCollapseHovered = $0 }
            .animation(.easeOut(duration: 0.14), value: isCollapseHovered)
            .help("Collapse notch")
            .accessibilityLabel("Collapse notch")
            .fixedSize()
        }
    }

    private var bottomDockView: some View {
        HStack(spacing: 3) {
            SectionButton(
                title: "Music",
                icon: "waveform",
                isSelected: isSelected(.music)
            ) { select(.music) }
            SectionButton(
                title: "Coding",
                icon: "chevron.left.forwardslash.chevron.right",
                isSelected: isSelected(.activity)
            ) { select(.activity) }
            SectionButton(
                title: "File Shelf",
                icon: "tray.full.fill",
                isSelected: isSelected(.shelf)
            ) { select(.shelf) }
            SectionButton(
                title: "Timer",
                icon: "timer",
                isSelected: isSelected(.timer)
            ) { select(.timer) }
            SectionButton(
                title: "Blocker",
                icon: "shield.lefthalf.filled",
                isSelected: isSelected(.blocker)
            ) { select(.blocker) }
            SectionButton(
                title: "Todos",
                icon: "checklist",
                isSelected: isSelected(.todo)
            ) { select(.todo) }
            SectionButton(
                title: "Calendar",
                icon: "calendar",
                isSelected: isSelected(.calendar)
            ) { select(.calendar) }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.05))
        )
    }

    private func select(_ section: NotchSection) {
        model.expand(section: section, pin: true, preferSelectedSection: true)
    }

    private func isSelected(_ section: NotchSection) -> Bool {
        model.selectedSection == section
    }
}

private struct DashboardHeaderButton: View {
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "rectangle.grid.2x2.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text("Dashboard")
                    .font(.system(size: 10.5, weight: .semibold))
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundStyle(isSelected ? .white : Color.white.opacity(0.78))
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(isSelected ? 0.14 : (isHovering ? 0.085 : 0.045)))
            )
            .overlay(alignment: .bottom) {
                if isSelected {
                    Capsule()
                        .fill(Color.notchAccent)
                        .frame(width: 18, height: 1.5)
                        .offset(y: 1)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.16), value: isHovering)
        .animation(.snappy(duration: 0.24), value: isSelected)
        .help("Quick activity summary")
        .accessibilityLabel("Dashboard")
    }
}
