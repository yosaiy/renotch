import Foundation

struct BrowserMediaActivity: Equatable, Identifiable {
    let sessionID: String
    let title: String
    let channel: String
    let pageURL: URL?
    let thumbnailURL: URL?
    let isPlaying: Bool
    let position: TimeInterval
    let duration: TimeInterval
    let updatedAt: Date

    var id: String { sessionID }

    var progress: Double? {
        guard duration > 0 else { return nil }
        return (position / duration).clamped(to: 0...1)
    }
}

enum BrowserDownloadState: String, Codable {
    case inProgress = "in_progress"
    case complete
    case interrupted
}

struct BrowserDownloadActivity: Equatable, Identifiable {
    let id: Int
    let filename: String
    let sourceURL: URL?
    let bytesReceived: Int64
    let totalBytes: Int64
    let state: BrowserDownloadState
    let paused: Bool
    let updatedAt: Date

    var displayName: String {
        let name = URL(fileURLWithPath: filename).lastPathComponent
        return name.isEmpty ? "Download" : name
    }

    var progress: Double? {
        guard totalBytes > 0 else { return nil }
        return (Double(bytesReceived) / Double(totalBytes)).clamped(to: 0...1)
    }

    var isFinished: Bool { state != .inProgress }
}

enum BrowserActivityPresentation: Hashable {
    case media(String, Bool, Int)
    case download(Int, BrowserDownloadState, Int64)
}

enum AdaptiveMediaSource: String, Equatable {
    case browser
    case music
}

enum AdaptiveMediaArbitrator {
    static func resolve(
        browserAvailable: Bool,
        browserIsPlaying: Bool,
        browserActivation: Date,
        musicIsPlaying: Bool,
        musicActivation: Date
    ) -> AdaptiveMediaSource? {
        if browserIsPlaying, musicIsPlaying {
            return musicActivation >= browserActivation ? .music : .browser
        }
        if musicIsPlaying { return .music }
        if browserIsPlaying { return .browser }
        return nil
    }
}
