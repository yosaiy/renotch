import AppKit
import Foundation

@MainActor
final class BrowserActivityService: ObservableObject {
    static let notificationName = Notification.Name("com.vincentyosi.virtualnotch.browser-activity")

    @Published private(set) var media: BrowserMediaActivity?
    @Published private(set) var mediaArtwork: NSImage?
    @Published private(set) var downloads: [Int: BrowserDownloadActivity] = [:]
    @Published private(set) var playbackActivationDate = Date.distantPast

    private var notificationToken: NSObjectProtocol?
    private var mediaExpiryWorkItem: DispatchWorkItem?
    private var artworkTask: Task<Void, Never>?
    private var downloadRemovalWorkItems: [Int: DispatchWorkItem] = [:]

    init(observeBridge: Bool = true) {
        guard observeBridge else { return }
        notificationToken = DistributedNotificationCenter.default().addObserver(
            forName: Self.notificationName,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let payload = notification.userInfo?["payload"] as? String,
                  let data = payload.data(using: .utf8) else { return }
            Task { @MainActor in self?.ingest(data) }
        }
    }

    deinit {
        if let notificationToken {
            DistributedNotificationCenter.default().removeObserver(notificationToken)
        }
        mediaExpiryWorkItem?.cancel()
        artworkTask?.cancel()
        downloadRemovalWorkItems.values.forEach { $0.cancel() }
    }

    var activeDownload: BrowserDownloadActivity? {
        downloads.values.sorted { lhs, rhs in
            if lhs.state == .inProgress, rhs.state != .inProgress { return true }
            if lhs.state != .inProgress, rhs.state == .inProgress { return false }
            return lhs.updatedAt > rhs.updatedAt
        }.first
    }

    var presentation: BrowserActivityPresentation? {
        if let download = activeDownload {
            return .download(download.id, download.state, download.bytesReceived)
        }
        if let media {
            return .media(media.sessionID, media.isPlaying, Int(media.position.rounded(.down)))
        }
        return nil
    }

    func ingest(_ data: Data) {
        guard let message = try? JSONDecoder().decode(BrowserBridgeMessage.self, from: data),
              message.version == 1 else { return }

        switch message.kind {
        case "media": ingestMedia(message)
        case "download": ingestDownload(message)
        default: break
        }
    }

    private func ingestMedia(_ message: BrowserBridgeMessage) {
        guard let sessionID = message.sessionID else { return }
        if message.action == "clear" {
            guard media?.sessionID == sessionID else { return }
            clearMedia()
            return
        }

        guard let title = message.title, !title.isEmpty else { return }
        let thumbnailURL = message.thumbnailURL.flatMap(URL.init(string:))
        let pageURL = message.url.flatMap(URL.init(string:))
        let isPlaying = message.isPlaying ?? false
        let becameActive = isPlaying && (
            media?.sessionID != sessionID
                || media?.isPlaying != true
                || media?.pageURL != pageURL
        )
        let previousThumbnailURL = media?.thumbnailURL
        media = BrowserMediaActivity(
            sessionID: sessionID,
            title: title,
            channel: message.channel ?? "YouTube",
            pageURL: pageURL,
            thumbnailURL: thumbnailURL,
            isPlaying: isPlaying,
            position: max(0, message.position ?? 0),
            duration: max(0, message.duration ?? 0),
            updatedAt: Date()
        )

        if becameActive {
            playbackActivationDate = Date()
        }

        if thumbnailURL != previousThumbnailURL {
            loadArtwork(from: thumbnailURL, sessionID: sessionID)
        }
        scheduleMediaExpiry(sessionID: sessionID)
    }

    private func ingestDownload(_ message: BrowserBridgeMessage) {
        guard let id = message.downloadID else { return }
        downloadRemovalWorkItems.removeValue(forKey: id)?.cancel()

        if message.action == "clear" {
            downloads.removeValue(forKey: id)
            return
        }

        guard let rawState = message.state,
              let state = BrowserDownloadState(rawValue: rawState) else { return }
        downloads[id] = BrowserDownloadActivity(
            id: id,
            filename: message.filename ?? "Download",
            sourceURL: message.url.flatMap(URL.init(string:)),
            bytesReceived: max(0, message.bytesReceived ?? 0),
            totalBytes: message.totalBytes ?? -1,
            state: state,
            paused: message.paused ?? false,
            updatedAt: Date()
        )

        guard state != .inProgress else { return }
        let work = DispatchWorkItem { [weak self] in
            self?.downloads.removeValue(forKey: id)
            self?.downloadRemovalWorkItems.removeValue(forKey: id)
        }
        downloadRemovalWorkItems[id] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4, execute: work)
    }

    private func scheduleMediaExpiry(sessionID: String) {
        mediaExpiryWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard self?.media?.sessionID == sessionID else { return }
            self?.clearMedia()
        }
        mediaExpiryWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 7, execute: work)
    }

    private func loadArtwork(from url: URL?, sessionID: String) {
        artworkTask?.cancel()
        mediaArtwork = nil
        guard let url else { return }

        artworkTask = Task { [weak self] in
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled,
                      data.count <= 5_000_000,
                      (response as? HTTPURLResponse)?.statusCode == 200,
                      let image = NSImage(data: data),
                      self?.media?.sessionID == sessionID else { return }
                self?.mediaArtwork = image
            } catch {
                // A missing thumbnail should not hide the media activity.
            }
        }
    }

    private func clearMedia() {
        mediaExpiryWorkItem?.cancel()
        mediaExpiryWorkItem = nil
        artworkTask?.cancel()
        artworkTask = nil
        media = nil
        mediaArtwork = nil
    }
}

private struct BrowserBridgeMessage: Decodable {
    let version: Int
    let kind: String
    let action: String?
    let sessionID: String?
    let title: String?
    let channel: String?
    let url: String?
    let thumbnailURL: String?
    let isPlaying: Bool?
    let position: Double?
    let duration: Double?
    let downloadID: Int?
    let filename: String?
    let bytesReceived: Int64?
    let totalBytes: Int64?
    let state: String?
    let paused: Bool?
}
