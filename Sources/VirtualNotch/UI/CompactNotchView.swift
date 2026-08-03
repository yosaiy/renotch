import SwiftUI

struct CompactNotchView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var music: MusicService
    @ObservedObject var timer: TimerService
    @ObservedObject var shelf: ShelfStore

    var body: some View {
        Group {
            switch model.settings.resolvedCompactContent {
            case .music:
                CompactMusicView(music: music, message: model.transientMessage)
            case .servers:
                CompactServerView(service: model.activity, message: model.transientMessage)
            case .timer:
                CompactTimerView(timer: timer, message: model.transientMessage)
            case .calendar:
                CompactCalendarView(service: model.calendar)
            case .shelf:
                CompactShelfView(shelf: shelf)
            }
        }
        .id(model.settings.resolvedCompactContent)
        .transition(
            .move(edge: .bottom)
                .combined(with: .notchBlur(radius: 7))
                .combined(with: .opacity)
        )
        .animation(.snappy(duration: 0.35), value: model.settings.resolvedCompactContent)
        .animation(.snappy(duration: 0.35), value: model.activity.primaryServerActivity.id)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, compactContentHorizontalInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var compactContentHorizontalInset: CGFloat {
        let radius = CGFloat(model.settings.resolvedCompactCornerRadius)
        let effectiveRadius = min(radius, CGFloat(model.settings.compactHeight) / 2)
        return max(NotchLayout.compactContentHorizontalInset, effectiveRadius + 18)
    }
}
