import AppKit
import Foundation

struct MusicTrack: Equatable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
}

enum MusicPlaybackState: String {
    case notRunning
    case stopped
    case paused
    case playing
}

final class MusicService: ObservableObject {
    @Published private(set) var track: MusicTrack?
    @Published private(set) var playbackState: MusicPlaybackState = .notRunning
    @Published private(set) var position: TimeInterval = 0
    @Published private(set) var volume: Double = 0.7
    @Published private(set) var artwork: NSImage?
    @Published private(set) var automationDenied = false

    private let scriptQueue = DispatchQueue(label: "com.vincentyosi.virtualnotch.music")
    private var pollingTimer: Timer?
    private var refreshInFlight = false

    init() {
        refresh()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        pollingTimer?.tolerance = 0.2
    }

    deinit {
        pollingTimer?.invalidate()
    }

    var isPlaying: Bool { playbackState == .playing }

    func togglePlayback() {
        runCommand("tell application \"Music\" to playpause")
    }

    func previousTrack() {
        runCommand("tell application \"Music\" to previous track")
    }

    func nextTrack() {
        runCommand("tell application \"Music\" to next track")
    }

    func seek(to value: TimeInterval) {
        let safePosition = value.clamped(to: 0...(track?.duration ?? max(value, 0)))
        runCommand("tell application \"Music\" to set player position to \(safePosition)")
    }

    func setVolume(_ value: Double) {
        let safeVolume = value.clamped(to: 0...1)
        volume = safeVolume
        runCommand("tell application \"Music\" to set sound volume to \(Int((safeVolume * 100).rounded()))")
    }

    func openMusic() {
        runCommand("tell application \"Music\" to activate")
    }

    func refresh() {
        guard !refreshInFlight else { return }
        refreshInFlight = true

        scriptQueue.async { [weak self] in
            let result = Self.execute(Self.metadataScript)
            DispatchQueue.main.async {
                guard let self else { return }
                self.refreshInFlight = false
                self.apply(result)
            }
        }
    }

    static func formattedTime(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.down)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func runCommand(_ source: String) {
        scriptQueue.async { [weak self] in
            let result = Self.execute(source)
            DispatchQueue.main.async {
                guard let self else { return }
                if case let .failure(error) = result {
                    self.automationDenied = error.code == -1743
                }
                self.refresh()
            }
        }
    }

    private func apply(_ result: Result<String, AppleScriptFailure>) {
        switch result {
        case let .failure(error):
            automationDenied = error.code == -1743
            playbackState = .stopped
            track = nil
            artwork = nil
        case let .success(output):
            automationDenied = false
            let values = output.components(separatedBy: "\u{001F}")
            guard values.count == 8,
                  let state = MusicPlaybackState(rawValue: values[0]),
                  let duration = Self.parseAppleScriptNumber(values[5]),
                  let currentPosition = Self.parseAppleScriptNumber(values[6]),
                  let soundVolume = Self.parseAppleScriptNumber(values[7]) else {
                playbackState = output == MusicPlaybackState.notRunning.rawValue ? .notRunning : .stopped
                track = nil
                position = 0
                artwork = nil
                return
            }

            let newTrack = MusicTrack(
                id: values[1],
                title: values[2],
                artist: values[3],
                album: values[4],
                duration: duration
            )
            let trackChanged = newTrack.id != track?.id
            playbackState = state
            track = newTrack
            position = currentPosition.clamped(to: 0...max(duration, 0))
            volume = (soundVolume / 100).clamped(to: 0...1)

            if trackChanged {
                artwork = nil
                loadArtwork(for: newTrack.id)
            }
        }
    }

    private func loadArtwork(for trackID: String) {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("virtual-notch-artwork-\(UUID().uuidString)")
            .path
        let escapedPath = path.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        set outputFile to POSIX file "\(escapedPath)"
        tell application "Music"
            try
                set artworkData to data of artwork 1 of current track
            on error
                return "missing"
            end try
        end tell
        try
            set fileHandle to open for access outputFile with write permission
            set eof fileHandle to 0
            write artworkData to fileHandle starting at 0
            close access fileHandle
            return "ok"
        on error
            try
                close access outputFile
            end try
            return "missing"
        end try
        """

        scriptQueue.async { [weak self] in
            let result = Self.execute(script)
            let image: NSImage?
            if case .success("ok") = result {
                image = NSImage(contentsOfFile: path)
            } else {
                image = nil
            }
            try? FileManager.default.removeItem(atPath: path)
            DispatchQueue.main.async {
                guard let self, self.track?.id == trackID else { return }
                self.artwork = image
            }
        }
    }

    private static func execute(_ source: String) -> Result<String, AppleScriptFailure> {
        guard let script = NSAppleScript(source: source) else {
            return .failure(AppleScriptFailure(code: -1, message: "AppleScript could not be created."))
        }
        var error: NSDictionary?
        let descriptor = script.executeAndReturnError(&error)
        if let error {
            return .failure(
                AppleScriptFailure(
                    code: error[NSAppleScript.errorNumber] as? Int ?? -1,
                    message: error[NSAppleScript.errorMessage] as? String ?? "Apple Music command failed."
                )
            )
        }
        return .success(descriptor.stringValue ?? "")
    }

    /// AppleScript formats real numbers with the user's locale. Music can
    /// therefore return `36,584` on systems that use a decimal comma.
    static func parseAppleScriptNumber(_ value: String) -> Double? {
        if let number = Double(value) { return number }
        return Double(value.replacingOccurrences(of: ",", with: "."))
    }

    private static let metadataScript = """
    if application "Music" is not running then return "notRunning"
    tell application "Music"
        set playbackState to (player state as text)
        if playbackState is "stopped" then return "stopped"
        set activeTrack to current track
        try
            set trackID to (database ID of activeTrack as text)
        on error
            set trackID to (persistent ID of activeTrack as text)
        end try
        try
            set trackTitle to (name of activeTrack as text)
        on error
            set trackTitle to "Unknown title"
        end try
        try
            set trackArtist to (artist of activeTrack as text)
        on error
            set trackArtist to "Unknown artist"
        end try
        try
            set trackAlbum to (album of activeTrack as text)
        on error
            set trackAlbum to ""
        end try
        try
            set trackDuration to (duration of activeTrack as text)
        on error
            set trackDuration to "0"
        end try
        set trackPosition to (player position as text)
        set currentVolume to (sound volume as text)
        set separator to ASCII character 31
        return playbackState & separator & trackID & separator & trackTitle & separator & trackArtist & separator & trackAlbum & separator & trackDuration & separator & trackPosition & separator & currentVolume
    end tell
    """
}

private struct AppleScriptFailure: Error {
    let code: Int
    let message: String
}
