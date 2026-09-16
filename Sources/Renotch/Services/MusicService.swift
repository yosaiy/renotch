import AppKit
import Foundation

enum MusicSource: String, CaseIterable, Equatable, Sendable {
    case appleMusic
    case spotify
    case qqMusic

    var displayName: String {
        switch self {
        case .appleMusic: return "Apple Music"
        case .spotify: return "Spotify"
        case .qqMusic: return "QQ 音乐"
        }
    }

    var bundleIdentifier: String {
        switch self {
        case .appleMusic: return "com.apple.Music"
        case .spotify: return "com.spotify.client"
        case .qqMusic: return "com.tencent.QQMusicMac"
        }
    }

    fileprivate var applicationName: String {
        switch self {
        case .appleMusic: return "Music"
        case .spotify: return "Spotify"
        case .qqMusic: return "QQMusic"
        }
    }

    fileprivate func durationInSeconds(_ value: Double) -> Double {
        self == .spotify ? value / 1_000 : value
    }
}

struct MusicTrack: Equatable, Sendable {
    let id: String
    let source: MusicSource
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval

    var cacheKey: String {
        "\(source.rawValue):\(title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()):\(artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }
}

enum MusicPlaybackState: String, Sendable {
    case notRunning
    case stopped
    case paused
    case playing
}

enum MusicRepeatMode: String, Equatable, Sendable {
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

struct MusicSnapshot: Equatable, Sendable {
    let source: MusicSource
    let playbackState: MusicPlaybackState
    let track: MusicTrack?
    let position: TimeInterval
    let volume: Double
    let artworkURL: URL?
    let shuffleEnabled: Bool
    let repeatMode: MusicRepeatMode
    var artworkData: Data? = nil
    var hasPosition: Bool = true
}

@MainActor
final class MusicService: ObservableObject {
    @Published private(set) var track: MusicTrack?
    @Published private(set) var playbackState: MusicPlaybackState = .notRunning
    @Published private(set) var position: TimeInterval = 0
    @Published private(set) var positionIsAvailable = true
    @Published private(set) var volume: Double = 0.7
    @Published private(set) var artwork: NSImage?
    @Published private(set) var automationDenied = false
    @Published private(set) var playbackActivationDate = Date.distantPast
    @Published private(set) var activeSource: MusicSource = .appleMusic
    @Published private(set) var shuffleEnabled = false
    @Published private(set) var repeatMode: MusicRepeatMode = .off
    @Published private(set) var qqMusicError: String?
    private let qqMusic = QQMusicBridge()

    private static let artworkCache = NSCache<NSString, NSImage>()
    private var pollingTimer: Timer?
    private var refreshInFlight = false
    private var snapshots: [MusicSource: MusicSnapshot] = [:]
    private var activationDates: [MusicSource: Date] = [:]
    private var automationDeniedSources: Set<MusicSource> = []
    private var artworkTask: Task<Void, Never>?
    private var artworkRequestID = UUID()
    private var loadingTrackID: String?

    init() {
        qqMusic.onSnapshot = { [weak self] snapshot in self?.applyQQMusic(snapshot) }
        qqMusic.onError = { [weak self] error in self?.qqMusicError = error }
        qqMusic.start()
        refresh()
        setupDistributedObservers()
        updatePollingTimerState()
    }

    deinit {
        pollingTimer?.invalidate()
        artworkTask?.cancel()
        DistributedNotificationCenter.default().removeObserver(self)
    }

    private func setupDistributedObservers() {
        let center = DistributedNotificationCenter.default()
        center.addObserver(
            forName: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        center.addObserver(
            forName: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func updatePollingTimerState() {
        if isPlaying {
            guard pollingTimer == nil else { return }
            pollingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }
            pollingTimer?.tolerance = 0.25
        } else {
            pollingTimer?.invalidate()
            pollingTimer = nil
        }
    }

    func pause() {
        qqMusic.stop()
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    func resume() {
        qqMusic.start()
        refresh()
        updatePollingTimerState()
    }

    var isPlaying: Bool { playbackState == .playing }
    var supportsExtendedControls: Bool { activeSource != .qqMusic }

    func togglePlayback() {
        if activeSource == .qqMusic { qqMusic.send(.toggle); return }
        runCommand("playpause")
    }

    func previousTrack() {
        if activeSource == .qqMusic { qqMusic.send(.previous); return }
        runCommand("previous track")
    }

    func nextTrack() {
        if activeSource == .qqMusic { qqMusic.send(.next); return }
        runCommand("next track")
    }

    func toggleShuffle() {
        guard supportsExtendedControls else { return }
        let nextValue = !shuffleEnabled
        shuffleEnabled = nextValue
        switch activeSource {
        case .appleMusic:
            runCommand("set shuffle enabled to \(nextValue)")
        case .spotify:
            runCommand("set shuffling to \(nextValue)")
        case .qqMusic: break
        }
    }

    func cycleRepeatMode() {
        guard supportsExtendedControls else { return }
        let nextMode = repeatMode.next(for: activeSource)
        repeatMode = nextMode
        switch activeSource {
        case .appleMusic:
            runCommand("set song repeat to \(nextMode.rawValue)")
        case .spotify:
            runCommand("set repeating to \(nextMode == .off ? "false" : "true")")
        case .qqMusic: break
        }
    }

    func seek(to value: TimeInterval) {
        guard supportsExtendedControls else { return }
        let safePosition = value.clamped(to: 0...(track?.duration ?? max(value, 0)))
        runCommand("set player position to \(safePosition)")
    }

    func setVolume(_ value: Double) {
        guard supportsExtendedControls else { return }
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

        Task {
            let results = await Self.fetchMetadata(runningSources: runningSources)
            self.refreshInFlight = false
            self.apply(results)
        }
    }

    nonisolated private static func fetchMetadata(
        runningSources: Set<MusicSource>
    ) async -> [MusicSource: Result<String, AppleScriptFailure>] {
        var results: [MusicSource: Result<String, AppleScriptFailure>] = [:]
        for source in MusicSource.allCases {
            guard source != .qqMusic else { continue }
            results[source] = runningSources.contains(source)
                ? execute(metadataScript(for: source))
                : .success(MusicPlaybackState.notRunning.rawValue)
        }
        return results
    }

    nonisolated static func formattedTime(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.down)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    nonisolated static func parseMetadata(_ output: String, source: MusicSource) -> MusicSnapshot? {
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
        let rawID = values[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let trackID = rawID.isEmpty
            ? "\(source.rawValue):\(values[2]):\(values[3]):\(values[4])"
            : "\(source.rawValue):\(rawID)"
        let track = MusicTrack(
            id: trackID,
            source: source,
            title: values[2],
            artist: values[3],
            album: values[4],
            duration: duration
        )
        let rawArtworkURL = values[8].trimmingCharacters(in: .whitespacesAndNewlines)
        return MusicSnapshot(
            source: source,
            playbackState: state,
            track: track,
            position: currentPosition.clamped(to: 0...max(duration, 0)),
            volume: (soundVolume / 100).clamped(to: 0...1),
            artworkURL: rawArtworkURL.isEmpty ? nil : URL(string: rawArtworkURL),
            shuffleEnabled: values.count > 9 && Self.parseAppleScriptBoolean(values[9]),
            repeatMode: values.count > 10 ? Self.parseRepeatMode(values[10]) : .off
        )
    }

    /// AppleScript formats real numbers with the user's locale. Music apps can
    /// therefore return `36,584` on systems that use a decimal comma.
    nonisolated static func parseAppleScriptNumber(_ value: String) -> Double? {
        if let number = Double(value) { return number }
        return Double(value.replacingOccurrences(of: ",", with: "."))
    }

    nonisolated static func parseAppleScriptBoolean(_ value: String) -> Bool {
        ["true", "yes", "1"].contains(value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    nonisolated static func parseRepeatMode(_ value: String) -> MusicRepeatMode {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "one": return .one
        case "all", "true", "yes", "1": return .all
        default: return .off
        }
    }

    private func runCommand(_ command: String) {
        let source = activeSource
        let script = "tell application \"\(source.applicationName)\" to \(command)"
        Task {
            let result = await Self.executeAsync(script)
            if case let .failure(error) = result {
                if error.code == -1743 {
                    self.automationDeniedSources.insert(source)
                    self.automationDenied = source == self.activeSource
                }
            }
            self.refresh()
        }
    }

    nonisolated private static func executeAsync(_ script: String) async -> Result<String, AppleScriptFailure> {
        execute(script)
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
        positionIsAvailable = selectedSnapshot?.hasPosition ?? false
        volume = selectedSnapshot?.volume ?? volume
        automationDenied = automationDeniedSources.contains(selectedSource)
        playbackActivationDate = activationDates[selectedSource] ?? .distantPast
        shuffleEnabled = selectedSnapshot?.shuffleEnabled ?? false
        repeatMode = selectedSnapshot?.repeatMode ?? .off
        updatePollingTimerState()

        let trackChanged = previousTrackID != track?.id
        if trackChanged {
            artworkTask?.cancel()
            artworkTask = nil
            artworkRequestID = UUID()
            loadingTrackID = nil

            if let track, let cached = Self.artworkCache.object(forKey: track.cacheKey as NSString) {
                artwork = cached
            } else {
                artwork = nil
            }
        }

        if selectedSource == .qqMusic {
            // QQ supplies artwork only on some system versions. Never search a
            // different catalogue and present an unrelated cover as its artwork.
            artwork = selectedSnapshot?.artworkData.flatMap(NSImage.init(data:))
        } else if let track {
            if trackChanged || (artwork == nil && loadingTrackID != track.id) {
                loadArtwork(for: track, remoteURL: selectedSnapshot?.artworkURL)
            }
        } else {
            artwork = nil
        }
    }

    private func applyQQMusic(_ snapshot: MusicSnapshot?) {
        let previous = snapshots[.qqMusic]
        if snapshot?.playbackState == .playing && (previous?.playbackState != .playing || previous?.track?.id != snapshot?.track?.id) {
            activationDates[.qqMusic] = Date()
        }
        snapshots[.qqMusic] = snapshot
        apply([:])
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
        if let cached = Self.artworkCache.object(forKey: track.cacheKey as NSString) {
            artwork = cached
            loadingTrackID = nil
            return
        }

        loadingTrackID = track.id
        let requestID = artworkRequestID
        artworkTask?.cancel()
        artworkTask = Task {
            let loadedImage: NSImage?
            switch track.source {
            case .appleMusic:
                loadedImage = await Self.fetchAppleMusicArtwork()
            case .spotify:
                loadedImage = await Self.fetchRemoteArtwork(url: remoteURL)
            case .qqMusic:
                return
            }

            guard !Task.isCancelled else { return }

            if let loadedImage {
                Self.artworkCache.setObject(loadedImage, forKey: track.cacheKey as NSString)
                if self.track?.id == track.id && self.artworkRequestID == requestID {
                    self.artwork = loadedImage
                    self.loadingTrackID = nil
                }
            } else {
                let fallback = await Self.searchOnlineArtwork(for: track)
                guard !Task.isCancelled else { return }
                if let fallback {
                    Self.artworkCache.setObject(fallback, forKey: track.cacheKey as NSString)
                    if self.track?.id == track.id && self.artworkRequestID == requestID {
                        self.artwork = fallback
                        self.loadingTrackID = nil
                    }
                } else if self.track?.id == track.id && self.artworkRequestID == requestID {
                    self.loadingTrackID = nil
                }
            }
        }
    }

    nonisolated private static func fetchAppleMusicArtwork() async -> NSImage? {
        let script = """
        tell application "Music"
            try
                return data of artwork 1 of current track
            on error
                return missing value
            end try
        end tell
        """
        guard let scriptObject = NSAppleScript(source: script) else { return nil }
        var error: NSDictionary?
        let descriptor = scriptObject.executeAndReturnError(&error)
        guard descriptor.data.count > 0 else { return nil }
        return NSImage(data: descriptor.data)
    }

    nonisolated private static func fetchRemoteArtwork(url: URL?) async -> NSImage? {
        guard let url else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  data.count <= 5_000_000 else { return nil }
            return NSImage(data: data)
        } catch {
            return nil
        }
    }

    nonisolated private static func searchOnlineArtwork(for track: MusicTrack) async -> NSImage? {
        guard !track.title.isEmpty, track.title != "未知歌曲" else { return nil }
        var query = track.title
        if !track.artist.isEmpty && track.artist != "未知歌手" {
            query += " \(track.artist)"
        }
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let searchURL = URL(string: "https://itunes.apple.com/search?term=\(encoded)&entity=song&limit=1") else {
            return nil
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: searchURL)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first,
                  let artworkUrlString = (first["artworkUrl100"] as? String)?
                    .replacingOccurrences(of: "100x100bb", with: "600x600bb"),
                  let imageURL = URL(string: artworkUrlString) else { return nil }
            let (imgData, imgResponse) = try await URLSession.shared.data(from: imageURL)
            guard (imgResponse as? HTTPURLResponse)?.statusCode == 200,
                  imgData.count <= 5_000_000 else { return nil }
            return NSImage(data: imgData)
        } catch {
            return nil
        }
    }

    nonisolated private static func execute(_ source: String) -> Result<String, AppleScriptFailure> {
        guard let script = NSAppleScript(source: source) else {
            return .failure(AppleScriptFailure(code: -1, message: "无法创建自动化脚本。"))
        }
        var error: NSDictionary?
        let descriptor = script.executeAndReturnError(&error)
        if let error {
            return .failure(
                AppleScriptFailure(
                    code: error[NSAppleScript.errorNumber] as? Int ?? -1,
                    message: error[NSAppleScript.errorMessage] as? String ?? "音乐控制命令执行失败。"
                )
            )
        }
        return .success(descriptor.stringValue ?? "")
    }

    nonisolated private static func metadataScript(for source: MusicSource) -> String {
        switch source {
        case .appleMusic:
            return appleMusicMetadataScript
        case .spotify:
            return spotifyMetadataScript
        case .qqMusic:
            return "" // QQ uses the local media bridge, never AppleScript.
        }
    }

    nonisolated private static let appleMusicMetadataScript = """
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
            set trackTitle to "未知歌曲"
        end try
        try
            set trackArtist to (artist of activeTrack as text)
        on error
            set trackArtist to "未知歌手"
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

    nonisolated private static let spotifyMetadataScript = """
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
            set trackTitle to "未知歌曲"
        end try
        try
            set trackArtist to (artist of activeTrack as text)
        on error
            set trackArtist to "未知歌手"
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

private struct AppleScriptFailure: Error, Equatable, Sendable {
    let code: Int
    let message: String
}
