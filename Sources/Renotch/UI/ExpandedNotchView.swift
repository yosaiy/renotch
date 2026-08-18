import SwiftUI

struct ExpandedNotchView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var timer: TimerService
    @ObservedObject var clipboard: ClipboardService

    var body: some View {
        VStack(spacing: 0) {
            if model.selectedSection == .welcome, model.activeMediaSource == nil {
                WelcomeView()
            } else {
                header

                Divider()
                    .overlay(Color.white.opacity(0.08))
                    .padding(.top, 6)

                visibleContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
                .animation(.easeOut(duration: 0.16), value: model.selectedSection)
                .animation(.easeOut(duration: 0.16), value: model.activeMediaSource)
                .animation(.easeOut(duration: 0.16), value: model.expandedSectionOverride)
            }
        }
        .padding(.leading, model.settings.resolvedExpandedContentLeadingPadding)
        .padding(.trailing, model.settings.resolvedExpandedContentTrailingPadding)
        .padding(.top, model.settings.resolvedExpandedContentTopPadding)
        .padding(.bottom, model.settings.resolvedExpandedContentBottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var visibleContent: some View {
        if model.expandedSectionOverride != nil {
            selectedSectionContent
        } else if model.activeMediaSource == .browser,
                  let media = model.browser.media {
            ExpandedBrowserMediaView(media: media, artwork: model.browser.mediaArtwork)
        } else if model.activeMediaSource == .music {
            MusicPlayerView(music: model.music)
        } else {
            selectedSectionContent
        }
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
            MusicPlayerView(music: model.music)
        case .timer:
            TimerView(timer: timer)
        case .calendar:
            CalendarView(service: model.calendar)
        case .clipboard:
            ClipboardView(clipboard: clipboard)
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

            if timer.isActive {
                Text(TimerService.formatted(timer.remaining))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(timer.currentMode.tint)
            }

            Button {
                model.collapse(force: true)
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 25, height: 25)
                    .background(Circle().fill(Color.white.opacity(0.07)))
            }
            .buttonStyle(.plain)
        }
    }

    private func select(_ section: NotchSection) {
        model.expand(section: section, pin: true, preferSelectedSection: true)
    }

    private func isSelected(_ section: NotchSection) -> Bool {
        if model.expandedSectionOverride != nil {
            return model.selectedSection == section
        }
        switch model.activeMediaSource {
        case .music: return section == .music
        case .browser: return false
        case nil: return model.selectedSection == section
        }
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
