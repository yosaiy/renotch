import AppKit
import Foundation

enum MusicSource: String, CaseIterable, Equatable {
    case appleMusic
    case spotify

    var displayName: String {
        switch self {
        case .appleMusic: return "Apple Music"
        case .spotify: return "Spotify"
        }
    }

    var bundleIdentifier: String {
        switch self {
        case .appleMusic: return "com.apple.Music"
        case .spotify: return "com.spotify.client"
        }
    }

    fileprivate var applicationName: String {
        switch self {
        case .appleMusic: return "Music"
        case .spotify: return "Spotify"
        }
    }

    fileprivate func durationInSeconds(_ value: Double) -> Double {
        self == .spotify ? value / 1_000 : value
    }
}

struct MusicTrack: Equatable {
    let id: String
    let source: MusicSource
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

enum MusicRepeatMode: String, Equatable {
    case off
    case all
    case one

    func next(for source: MusicSource) -> MusicRepeatMode {
        if source == .spotify {
            return self == .off ? .all : .off
        }
        switch self {
        case .off: return .all
        case .all: return .one
        case .one: return .off
        }
    }
}

struct MusicSnapshot: Equatable {
    let source: MusicSource
    let playbackState: MusicPlaybackState
    let track: MusicTrack?
    let position: TimeInterval
    let volume: Double
    let artworkURL: URL?
    let shuffleEnabled: Bool
    let repeatMode: MusicRepeatMode
}

final class MusicService: ObservableObject {
    @Published private(set) var track: MusicTrack?
    @Published private(set) var playbackState: MusicPlaybackState = .notRunning
    @Published private(set) var position: TimeInterval = 0
    @Published private(set) var volume: Double = 0.7
    @Published private(set) var artwork: NSImage?
    @Published private(set) var automationDenied = false
    @Published private(set) var playbackActivationDate = Date.distantPast
    @Published private(set) var activeSource: MusicSource = .appleMusic
    @Published private(set) var shuffleEnabled = false
    @Published private(set) var repeatMode: MusicRepeatMode = .off

    private let scriptQueue = DispatchQueue(label: "com.vincentyosi.virtualnotch.music")
    private var pollingTimer: Timer?
    private var refreshInFlight = false
    private var snapshots: [MusicSource: MusicSnapshot] = [:]
    private var activationDates: [MusicSource: Date] = [:]
    private var automationDeniedSources: Set<MusicSource> = []
    private var artworkDataTask: URLSessionDataTask?

    init() {
        refresh()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        pollingTimer?.tolerance = 0.2
    }

    deinit {
        pollingTimer?.invalidate()
        artworkDataTask?.cancel()
    }

    var isPlaying: Bool { playbackState == .playing }

    func togglePlayback() {
        runCommand("playpause")
    }

    func previousTrack() {
        runCommand("previous track")
    }

    func nextTrack() {
        runCommand("next track")
    }

    func toggleShuffle() {
        let nextValue = !shuffleEnabled
        shuffleEnabled = nextValue
        switch activeSource {
        case .appleMusic:
            runCommand("set shuffle enabled to \(nextValue)")
        case .spotify:
            runCommand("set shuffling to \(nextValue)")
        }
    }

    func cycleRepeatMode() {
        let nextMode = repeatMode.next(for: activeSource)
        repeatMode = nextMode
        switch activeSource {
        case .appleMusic:
            runCommand("set song repeat to \(nextMode.rawValue)")
        case .spotify:
            runCommand("set repeating to \(nextMode == .off ? "false" : "true")")
        }
    }

    func seek(to value: TimeInterval) {
        let safePosition = value.clamped(to: 0...(track?.duration ?? max(value, 0)))
        runCommand("set player position to \(safePosition)")
    }

    func setVolume(_ value: Double) {
        let safeVolume = value.clamped(to: 0...1)
        volume = safeVolume
        runCommand("set sound volume to \(Int((safeVolume * 100).rounded()))")
    }

    func open(_ source: MusicSource) {
        guard let applicationURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: source.bundleIdentifier
        ) else { return }
        NSWorkspace.shared.openApplication(
            at: applicationURL,
            configuration: NSWorkspace.OpenConfiguration()
        )
    }

    func openMusic() {
        open(.appleMusic)
    }

    func openSpotify() {
        open(.spotify)
    }

    func isInstalled(_ source: MusicSource) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: source.bundleIdentifier) != nil
    }

    func refresh() {
        guard !refreshInFlight else { return }
        refreshInFlight = true

        let runningSources = Set(
            MusicSource.allCases.filter {
                !NSRunningApplication.runningApplications(
                    withBundleIdentifier: $0.bundleIdentifier
                ).isEmpty
            }
        )

        scriptQueue.async { [weak self] in
            var results: [MusicSource: Result<String, AppleScriptFailure>] = [:]
            for source in MusicSource.allCases {
                results[source] = runningSources.contains(source)
                    ? Self.execute(Self.metadataScript(for: source))
                    : .success(MusicPlaybackState.notRunning.rawValue)
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.refreshInFlight = false
                self.apply(results)
            }
        }
    }

    static func formattedTime(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.down)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func parseMetadata(_ output: String, source: MusicSource) -> MusicSnapshot? {
        if let state = MusicPlaybackState(rawValue: output) {
            return MusicSnapshot(
                source: source,
                playbackState: state,
                track: nil,
                position: 0,
                volume: 0.7,
                artworkURL: nil,
                shuffleEnabled: false,
                repeatMode: .off
            )
        }

        let values = output.components(separatedBy: "\u{001F}")
        guard values.count >= 9,
              let state = MusicPlaybackState(rawValue: values[0]),
              let rawDuration = parseAppleScriptNumber(values[5]),
              let currentPosition = parseAppleScriptNumber(values[6]),
              let soundVolume = parseAppleScriptNumber(values[7]) else { return nil }

        let duration = source.durationInSeconds(rawDuration)
        let track = MusicTrack(
            id: "\(source.rawValue):\(values[1])",
            source: source,
            title: values[2],
            artist: values[3],
            album: values[4],
            duration: duration
        )
        return MusicSnapshot(
            source: source,
            playbackState: state,
            track: track,
            position: currentPosition.clamped(to: 0...max(duration, 0)),
            volume: (soundVolume / 100).clamped(to: 0...1),
            artworkURL: values[8].isEmpty ? nil : URL(string: values[8]),
            shuffleEnabled: values.count > 9 && Self.parseAppleScriptBoolean(values[9]),
            repeatMode: values.count > 10 ? Self.parseRepeatMode(values[10]) : .off
        )
    }

    /// AppleScript formats real numbers with the user's locale. Music apps can
    /// therefore return `36,584` on systems that use a decimal comma.
    static func parseAppleScriptNumber(_ value: String) -> Double? {
        if let number = Double(value) { return number }
        return Double(value.replacingOccurrences(of: ",", with: "."))
    }

    static func parseAppleScriptBoolean(_ value: String) -> Bool {
        ["true", "yes", "1"].contains(value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    static func parseRepeatMode(_ value: String) -> MusicRepeatMode {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "one": return .one
        case "all", "true", "yes", "1": return .all
        default: return .off
        }
    }

    private func runCommand(_ command: String) {
        let source = activeSource
        let script = "tell application \"\(source.applicationName)\" to \(command)"
        scriptQueue.async { [weak self] in
            let result = Self.execute(script)
            DispatchQueue.main.async {
                guard let self else { return }
                if case let .failure(error) = result {
                    if error.code == -1743 {
                        self.automationDeniedSources.insert(source)
                        self.automationDenied = source == self.activeSource
                    }
                }
                self.refresh()
            }
        }
    }

    private func apply(_ results: [MusicSource: Result<String, AppleScriptFailure>]) {
        var updatedSnapshots = snapshots

        for source in MusicSource.allCases {
            guard let result = results[source] else { continue }
            switch result {
            case let .failure(error):
                if error.code == -1743 {
                    automationDeniedSources.insert(source)
                }
                updatedSnapshots[source] = MusicSnapshot(
                    source: source,
                    playbackState: .stopped,
                    track: nil,
                    position: 0,
                    volume: snapshots[source]?.volume ?? 0.7,
                    artworkURL: nil,
                    shuffleEnabled: false,
                    repeatMode: .off
                )
            case let .success(output):
                automationDeniedSources.remove(source)
                guard let snapshot = Self.parseMetadata(output, source: source) else {
                    updatedSnapshots[source] = MusicSnapshot(
                        source: source,
                        playbackState: .stopped,
                        track: nil,
                        position: 0,
                        volume: snapshots[source]?.volume ?? 0.7,
                        artworkURL: nil,
                        shuffleEnabled: false,
                        repeatMode: .off
                    )
                    continue
                }

                let previous = snapshots[source]
                let becameActive = snapshot.playbackState == .playing && (
                    previous?.playbackState != .playing
                        || previous?.track?.id != snapshot.track?.id
                )
                if becameActive {
                    activationDates[source] = Date()
                }
                updatedSnapshots[source] = snapshot
            }
        }

        snapshots = updatedSnapshots
        let selectedSource = resolveActiveSource()
        let selectedSnapshot = snapshots[selectedSource]
        let previousTrackID = track?.id

        activeSource = selectedSource
        playbackState = selectedSnapshot?.playbackState ?? .notRunning
        track = selectedSnapshot?.track
        position = selectedSnapshot?.position ?? 0
        volume = selectedSnapshot?.volume ?? volume
        automationDenied = automationDeniedSources.contains(selectedSource)
        playbackActivationDate = activationDates[selectedSource] ?? .distantPast
        shuffleEnabled = selectedSnapshot?.shuffleEnabled ?? false
        repeatMode = selectedSnapshot?.repeatMode ?? .off

        if previousTrackID != track?.id {
            artworkDataTask?.cancel()
            artworkDataTask = nil
            artwork = nil
            if let track {
                loadArtwork(for: track, remoteURL: selectedSnapshot?.artworkURL)
            }
        }
    }

    private func resolveActiveSource() -> MusicSource {
        let playing = MusicSource.allCases.filter {
            snapshots[$0]?.playbackState == .playing
        }
        if let source = playing.max(by: {
            (activationDates[$0] ?? .distantPast) < (activationDates[$1] ?? .distantPast)
        }) {
            return source
        }

        if snapshots[activeSource]?.track != nil {
            return activeSource
        }

        let withTrack = MusicSource.allCases.filter { snapshots[$0]?.track != nil }
        if let source = withTrack.max(by: {
            (activationDates[$0] ?? .distantPast) < (activationDates[$1] ?? .distantPast)
        }) {
            return source
        }

        if automationDeniedSources.contains(.spotify) { return .spotify }
        if automationDeniedSources.contains(.appleMusic) { return .appleMusic }
        return activeSource
    }

    private func loadArtwork(for track: MusicTrack, remoteURL: URL?) {
        switch track.source {
        case .appleMusic:
            loadAppleMusicArtwork(for: track.id)
        case .spotify:
            loadRemoteArtwork(from: remoteURL, trackID: track.id)
        }
    }

    private func loadAppleMusicArtwork(for trackID: String) {
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

    private func loadRemoteArtwork(from url: URL?, trackID: String) {
        guard let url else { return }
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, _ in
            guard let data,
                  data.count <= 5_000_000,
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let image = NSImage(data: data) else { return }
            DispatchQueue.main.async {
                guard let self, self.track?.id == trackID else { return }
                self.artwork = image
            }
        }
        artworkDataTask = task
        task.resume()
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
                    message: error[NSAppleScript.errorMessage] as? String ?? "Music command failed."
                )
            )
        }
        return .success(descriptor.stringValue ?? "")
    }

    private static func metadataScript(for source: MusicSource) -> String {
        switch source {
        case .appleMusic:
            return appleMusicMetadataScript
        case .spotify:
            return spotifyMetadataScript
        }
    }

    private static let appleMusicMetadataScript = """
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
        try
            set shuffleState to (shuffle enabled as text)
        on error
            set shuffleState to "false"
        end try
        try
            set repeatState to (song repeat as text)
        on error
            set repeatState to "off"
        end try
        set separator to ASCII character 31
        return playbackState & separator & trackID & separator & trackTitle & separator & trackArtist & separator & trackAlbum & separator & trackDuration & separator & trackPosition & separator & currentVolume & separator & "" & separator & shuffleState & separator & repeatState
    end tell
    """

    private static let spotifyMetadataScript = """
    tell application "Spotify"
        set playbackState to (player state as text)
        if playbackState is "stopped" then return "stopped"
        set activeTrack to current track
        try
            set trackID to (spotify url of activeTrack as text)
        on error
            set trackID to (name of activeTrack as text)
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
        try
            set artworkAddress to (artwork url of activeTrack as text)
        on error
            set artworkAddress to ""
        end try
        set trackPosition to (player position as text)
        set currentVolume to (sound volume as text)
        try
            set shuffleState to (shuffling as text)
        on error
            set shuffleState to "false"
        end try
        try
            set repeatState to (repeating as text)
        on error
            set repeatState to "false"
        end try
        set separator to ASCII character 31
        return playbackState & separator & trackID & separator & trackTitle & separator & trackArtist & separator & trackAlbum & separator & trackDuration & separator & trackPosition & separator & currentVolume & separator & artworkAddress & separator & shuffleState & separator & repeatState
    end tell
    """
}

private struct AppleScriptFailure: Error {
    let code: Int
    let message: String
}
