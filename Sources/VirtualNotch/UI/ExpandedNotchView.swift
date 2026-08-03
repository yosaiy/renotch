import SwiftUI

struct ExpandedNotchView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var timer: TimerService
    @ObservedObject var clipboard: ClipboardService

    var body: some View {
        VStack(spacing: 0) {
            if model.selectedSection == .welcome {
                WelcomeView()
            } else {
                header

                Divider()
                    .overlay(Color.white.opacity(0.08))
                    .padding(.top, 6)

                Group {
                    switch model.selectedSection {
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
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
                .animation(.easeOut(duration: 0.16), value: model.selectedSection)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(spacing: 4) {
            ActivityStateDot(state: model.activity.primaryActivity.state)
                .padding(.trailing, 5)

            HStack(spacing: 2) {
                SectionButton(
                    title: "Activity",
                    icon: "bolt.fill",
                    isSelected: model.selectedSection == .activity
                ) { select(.activity) }
                SectionButton(
                    title: "Music",
                    icon: "waveform",
                    isSelected: model.selectedSection == .music
                ) { select(.music) }
                SectionButton(
                    title: "Timer",
                    icon: "timer",
                    isSelected: model.selectedSection == .timer
                ) { select(.timer) }
                SectionButton(
                    title: "Calendar",
                    icon: "calendar",
                    isSelected: model.selectedSection == .calendar
                ) { select(.calendar) }
                SectionButton(
                    title: "Shelf",
                    icon: "tray.full.fill",
                    isSelected: model.selectedSection == .shelf
                ) { select(.shelf) }
                SectionButton(
                    title: "Clipboard",
                    icon: "doc.on.clipboard",
                    isSelected: model.selectedSection == .clipboard
                ) { select(.clipboard) }
                SectionButton(
                    title: "Todos",
                    icon: "checklist",
                    isSelected: model.selectedSection == .todo
                ) { select(.todo) }
            }

            Spacer(minLength: 4)

            if timer.isActive {
                Text(TimerService.formatted(timer.remaining))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.notchAccent)
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
        model.selectedSection = section
        model.expand(pin: true)
    }
}
