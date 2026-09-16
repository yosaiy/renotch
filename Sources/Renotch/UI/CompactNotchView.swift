import SwiftUI

struct CompactNotchView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var music: MusicService
    @ObservedObject var browser: BrowserActivityService
    @ObservedObject var timer: TimerService
    @ObservedObject var shelf: ShelfStore
    @ObservedObject var activity: DeveloperActivityService
    @ObservedObject var todos: TodoStore

    var body: some View {
        Group {
            if model.authGlance == nil && model.codex.shouldPresent {
                CompactCodexView(service: model.codex, usage: model.codexUsage)
            } else {
            switch livePresentation {
            case .faceID(let auth):
                CompactFaceIDView(auth: auth)
            case .download:
                if let download = browser.activeDownload {
                    CompactBrowserDownloadView(download: download)
                }
            case .codingGlance:
                if let glance = activity.glance {
                    CompactActivityGlanceView(glance: glance)
                }
            case .browserMedia:
                if let media = browser.media {
                    CompactBrowserMediaView(media: media, artwork: browser.mediaArtwork, timer: timer)
                }
            case .music:
                CompactMusicView(
                    music: music,
                    timer: timer,
                    message: model.transientMessage,
                    showsTrackInfo: model.settings.resolvedCompactMusicShowsTrackInfo
                )
            case .configured:
                configuredContent
            }
            }
        }
        .id(presentationID)
        .transition(.identity)
        .animation(.spring(response: 0.32, dampingFraction: 0.92), value: presentationID)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.leading, compactContentLeadingInset)
        .padding(.trailing, compactContentTrailingInset)
        .padding(.top, model.settings.resolvedCompactContentTopPadding)
        .padding(.bottom, model.settings.resolvedCompactContentBottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .clipped()
    }

    private var livePresentation: AdaptiveCompactPresentation {
        AdaptiveCompactArbitrator.resolve(
            authGlance: model.authGlance,
            downloadAvailable: browser.activeDownload != nil,
            codingGlanceAvailable: activity.glance != nil,
            mediaSource: model.activeMediaSource,
            configuredContent: model.settings.resolvedCompactContent,
            isTimerActive: timer.isActive
        )
    }

    @ViewBuilder
    private var configuredContent: some View {
        switch model.settings.resolvedCompactContent {
        case .codex:
            CompactCodexView(service: model.codex, usage: model.codexUsage)
        case .music:
            CompactMusicView(
                music: music,
                timer: timer,
                message: model.transientMessage,
                showsTrackInfo: model.settings.resolvedCompactMusicShowsTrackInfo
            )
        case .servers:
            CompactServerView(service: activity, message: model.transientMessage)
        case .timer:
            CompactTimerView(timer: timer, message: model.transientMessage)
        case .calendar:
            CompactCalendarView(service: model.calendar)
        case .shelf:
            CompactShelfView(shelf: shelf)
        case .todo:
            CompactTodoView(store: todos, message: model.transientMessage)
        }
    }

    private var presentationID: String {
        if model.authGlance == nil && model.codex.shouldPresent { return "codex" }
        switch livePresentation {
        case .faceID(let auth):
            return "faceid-\(auth.id.uuidString)"
        case .download:
            return "download-\(browser.activeDownload?.id ?? 0)"
        case .codingGlance:
            return "coding-glance-\(activity.glance?.id.uuidString ?? "")"
        case .browserMedia:
            return "browser-media-\(browser.media?.sessionID ?? "unknown")"
        case .music:
            return "music-\(music.track?.id ?? "unknown")"
        case .configured:
            return "configured-\(model.settings.resolvedCompactContent.rawValue)-\(timer.isActive ? "active" : "idle")"
        }
    }

    private var compactContentLeadingInset: CGFloat {
        CGFloat(model.settings.resolvedCompactContentLeadingPadding)
    }

    private var compactContentTrailingInset: CGFloat {
        CGFloat(model.settings.resolvedCompactContentTrailingPadding)
    }
}
