import SwiftUI

struct CompactNotchView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var music: MusicService
    @ObservedObject var browser: BrowserActivityService
    @ObservedObject var timer: TimerService
    @ObservedObject var shelf: ShelfStore
    @ObservedObject var activity: DeveloperActivityService

    var body: some View {
        Group {
            switch livePresentation {
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
                    CompactBrowserMediaView(media: media, artwork: browser.mediaArtwork)
                }
            case .music:
                CompactMusicView(
                    music: music,
                    message: model.transientMessage,
                    showsTrackInfo: model.settings.resolvedCompactMusicShowsTrackInfo
                )
            case .configured:
                configuredContent
            }
        }
        .id(presentationID)
        .transition(
            .move(edge: .bottom)
                .combined(with: .notchBlur(radius: 7))
                .combined(with: .opacity)
        )
        .animation(.snappy(duration: 0.35), value: model.settings.resolvedCompactContent)
        .animation(.snappy(duration: 0.35), value: browser.presentation)
        .animation(.snappy(duration: 0.35), value: model.activeMediaSource)
        .animation(.snappy(duration: 0.35), value: music.playbackActivationDate)
        .animation(.snappy(duration: 0.35), value: activity.glance?.id)
        .animation(.snappy(duration: 0.35), value: activity.primaryServerActivity.id)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.leading, compactContentLeadingInset)
        .padding(.trailing, compactContentTrailingInset)
        .padding(.top, model.settings.resolvedCompactContentTopPadding)
        .padding(.bottom, model.settings.resolvedCompactContentBottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var livePresentation: AdaptiveCompactPresentation {
        AdaptiveCompactArbitrator.resolve(
            downloadAvailable: browser.activeDownload != nil,
            codingGlanceAvailable: activity.glance != nil,
            mediaSource: model.activeMediaSource
        )
    }

    @ViewBuilder
    private var configuredContent: some View {
        switch model.settings.resolvedCompactContent {
        case .music:
            CompactMusicView(
                music: music,
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
        }
    }

    private var presentationID: String {
        if let download = browser.activeDownload {
            return "download-\(download.id)"
        }
        if let glance = activity.glance {
            return "coding-glance-\(glance.id.uuidString)"
        }
        switch model.activeMediaSource {
        case .browser:
            return "media-\(browser.media?.sessionID ?? "unknown")"
        case .music:
            return "music-\(music.track?.id ?? "unknown")"
        case nil:
            return "configured-\(model.settings.resolvedCompactContent.rawValue)"
        }
    }

    private var compactContentLeadingInset: CGFloat {
        CGFloat(model.settings.resolvedCompactContentLeadingPadding)
    }

    private var compactContentTrailingInset: CGFloat {
        CGFloat(model.settings.resolvedCompactContentTrailingPadding)
    }
}
