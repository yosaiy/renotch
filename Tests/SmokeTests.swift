import AppKit
import Foundation

@main
struct SmokeTests {
    @MainActor
    static func main() throws {
        var failures: [String] = []

        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            if !condition() { failures.append(message) }
        }

        var settings = NotchSettings.default
        settings.compactWidth = 1
        settings.compactHeight = 900
        settings.expandedWidth = 900
        settings.expandedHeight = 900
        settings.compactCornerRadius = 900
        settings.compactContentLeadingPadding = 900
        settings.compactContentTrailingPadding = 900
        settings.compactContentTopPadding = 900
        settings.compactContentBottomPadding = 900
        settings.expandedContentLeadingPadding = 900
        settings.expandedContentTrailingPadding = 900
        settings.expandedContentTopPadding = 900
        settings.expandedContentBottomPadding = 900
        settings.collapseDelay = 0
        settings.clampValues()
        expect(settings.compactWidth == 180, "compact width lower bound")
        expect(settings.compactHeight == 300, "compact height upper bound")
        expect(settings.expandedWidth == 800, "expanded width upper bound")
        expect(settings.expandedHeight == 260, "expanded height upper bound")
        expect(settings.resolvedCompactCornerRadius == 40, "compact corner radius upper bound")
        expect(settings.resolvedCompactContentLeadingPadding == 100, "compact content leading padding upper bound")
        expect(settings.resolvedCompactContentTrailingPadding == 100, "compact content trailing padding upper bound")
        expect(settings.resolvedCompactContentTopPadding == 20, "compact content top padding upper bound")
        expect(settings.resolvedCompactContentBottomPadding == 20, "compact content bottom padding upper bound")
        expect(settings.resolvedExpandedContentLeadingPadding == 80, "expanded content leading padding upper bound")
        expect(settings.resolvedExpandedContentBottomPadding == 80, "expanded content bottom padding upper bound")
        expect(settings.collapseDelay == 0.3, "collapse delay lower bound")
        expect(settings.resolvedCompactContent == .music, "music is the default compact content")
        expect(CompactNotchContent.calendar.section == .calendar, "calendar compact destination")
        expect(
            NotchSettings.compactWidthRange == NotchSettings.expandedWidthRange,
            "compact and expanded width ranges match"
        )

        var minimumCompactSettings = NotchSettings.default
        minimumCompactSettings.compactHeight = 1
        minimumCompactSettings.clampValues()
        expect(minimumCompactSettings.compactHeight == 28, "compact height lower bound")

        var customCompactSettings = NotchSettings.default
        customCompactSettings.compactWidth = 512
        customCompactSettings.compactHeight = 96
        customCompactSettings.clampValues()
        expect(customCompactSettings.compactWidth == 512, "custom compact width is preserved")
        expect(customCompactSettings.compactHeight == 96, "custom compact height is preserved")

        expect(NotchSettings.default.compactWidth == 335, "collapsed width")
        expect(NotchSettings.default.compactHeight == 30, "recommended compact height")
        expect(NotchSettings.default.expandedWidth == 460, "recommended expanded width")
        expect(NotchSettings.default.expandedHeight == 220, "expanded menu height")
        expect(NotchSettings.codingExpandedWidth == 500, "coding menu width")
        expect(NotchSettings.codingExpandedHeight == 240, "coding menu height")
        expect(NotchSettings.expandedMinWidth == 440, "expanded header minimum width")
        expect(NotchSettings.default.resolvedCompactCornerRadius == 11, "default compact corner radius")
        expect(NotchSettings.default.resolvedCompactContentLeadingPadding == 19, "default compact content leading padding")
        expect(NotchSettings.default.resolvedCompactContentTrailingPadding == 19, "default compact content trailing padding")
        expect(NotchSettings.default.resolvedCompactContentTopPadding == 0, "default compact content top padding")
        expect(NotchSettings.default.resolvedCompactContentBottomPadding == 4, "default compact content bottom padding")
        expect(NotchSettings.default.resolvedExpandedContentLeadingPadding == 28, "default expanded content leading padding")
        expect(NotchSettings.default.resolvedExpandedContentTrailingPadding == 28, "default expanded content trailing padding")
        expect(NotchSettings.default.resolvedExpandedContentTopPadding == 12, "default expanded content top padding")
        expect(NotchSettings.default.resolvedExpandedContentBottomPadding == 14, "default expanded content bottom padding")
        expect(NotchSettings.dragWidth == 500, "drag width")
        expect(NotchSettings.dragHeight == 120, "drag height")

        expect(TimerService.formatted(65) == "01:05", "minute timer formatting")
        expect(TimerService.formatted(3_661) == "1:01:01", "hour timer formatting")
        expect(TimerService.formatted(-1) == "00:00", "negative timer formatting")

        let timerDefaults = UserDefaults(suiteName: "renotch.tests.timer.\(UUID().uuidString)")!
        let timerService = TimerService(defaults: timerDefaults)
        expect(timerService.selectedMode == .focus, "initial timer mode is focus")
        timerService.startPomodoro(focusMinutes: 25, breakMinutes: 5, autoAdvance: true, notify: false)
        expect(timerService.isActive, "timer is active after start")
        expect(timerService.currentMode == .focus, "active timer mode is focus")
        expect(timerService.duration == 1500, "25 min focus duration")
        expect(timerService.focusMinutes == 25, "focus minutes configured")
        expect(timerService.breakMinutes == 5, "break minutes configured")
        timerService.skip()
        expect(timerService.isActive, "break timer active after skipping focus")
        expect(timerService.currentMode == .breakTime, "active timer mode is break after skip")
        expect(timerService.duration == 300, "5 min break duration")
        timerService.skip()
        expect(!timerService.isActive, "timer inactive after skipping break")
        expect(timerService.selectedMode == .focus, "mode reset to focus after break")
        timerService.cancel()
        expect(!timerService.isActive, "timer inactive after cancel")

        expect(MusicService.parseAppleScriptNumber("309.389") == 309.389, "music dot-decimal parsing")
        expect(MusicService.parseAppleScriptNumber("309,389") == 309.389, "music comma-decimal parsing")
        let separator = "\u{001F}"
        let spotifySnapshot = MusicService.parseMetadata(
            [
                "playing",
                "spotify:track:demo",
                "Spotify Track",
                "Spotify Artist",
                "Spotify Album",
                "245000",
                "61",
                "75",
                "https://i.scdn.co/image/demo",
                "true",
                "all"
            ].joined(separator: separator),
            source: .spotify
        )
        expect(spotifySnapshot?.track?.source == .spotify, "Spotify metadata source")
        expect(spotifySnapshot?.track?.duration == 245, "Spotify millisecond duration conversion")
        expect(spotifySnapshot?.position == 61, "Spotify playback position")
        expect(spotifySnapshot?.volume == 0.75, "Spotify volume normalization")
        expect(spotifySnapshot?.shuffleEnabled == true, "Spotify shuffle state parsing")
        expect(spotifySnapshot?.repeatMode == .all, "Spotify repeat state parsing")
        expect(MusicService.parseAppleScriptBoolean("true"), "AppleScript boolean parsing")
        expect(MusicService.parseRepeatMode("one") == .one, "repeat-one parsing")
        expect(MusicRepeatMode.off.next(for: .appleMusic) == .all, "Apple Music repeat starts with all")
        expect(MusicRepeatMode.all.next(for: .appleMusic) == .one, "Apple Music repeat cycles to one")
        expect(MusicRepeatMode.one.next(for: .appleMusic) == .off, "Apple Music repeat cycles off")
        expect(MusicRepeatMode.all.next(for: .spotify) == .off, "Spotify repeat toggles off")

        let browser = BrowserActivityService(observeBridge: false)
        let mediaMessage = try JSONSerialization.data(withJSONObject: [
            "version": 1,
            "kind": "media",
            "action": "update",
            "sessionID": "tab-1",
            "title": "Adaptive Notch Demo",
            "channel": "Virtual Notch",
            "url": "https://www.youtube.com/watch?v=demo",
            "isPlaying": true,
            "position": 30,
            "duration": 120
        ])
        browser.ingest(mediaMessage)
        expect(browser.media?.title == "Adaptive Notch Demo", "browser media title ingestion")
        expect(browser.media?.progress == 0.25, "browser media progress")

        let downloadMessage = try JSONSerialization.data(withJSONObject: [
            "version": 1,
            "kind": "download",
            "action": "update",
            "downloadID": 7,
            "filename": "/Users/test/Downloads/archive.zip",
            "bytesReceived": 500,
            "totalBytes": 1000,
            "state": "in_progress",
            "paused": false
        ])
        browser.ingest(downloadMessage)
        expect(browser.activeDownload?.displayName == "archive.zip", "browser download filename")
        expect(browser.activeDownload?.progress == 0.5, "browser download progress")
        if case let .download(id, state, _) = browser.presentation {
            expect(id == 7 && state == .inProgress, "download takes live activity priority")
        } else {
            expect(false, "download live activity presentation")
        }

        let earlier = Date(timeIntervalSinceReferenceDate: 100)
        let later = Date(timeIntervalSinceReferenceDate: 200)
        expect(
            AdaptiveMediaArbitrator.resolve(
                browserAvailable: true,
                browserIsPlaying: true,
                browserActivation: later,
                musicIsPlaying: false,
                musicActivation: earlier
            ) == .browser,
            "playing YouTube selects browser media"
        )
        expect(
            AdaptiveMediaArbitrator.resolve(
                browserAvailable: true,
                browserIsPlaying: true,
                browserActivation: earlier,
                musicIsPlaying: true,
                musicActivation: later
            ) == .music,
            "new music playback takes over YouTube"
        )
        expect(
            AdaptiveMediaArbitrator.resolve(
                browserAvailable: true,
                browserIsPlaying: true,
                browserActivation: later,
                musicIsPlaying: true,
                musicActivation: earlier
            ) == .browser,
            "resumed YouTube takes back media presentation"
        )
        expect(
            AdaptiveMediaArbitrator.resolve(
                browserAvailable: true,
                browserIsPlaying: false,
                browserActivation: earlier,
                musicIsPlaying: true,
                musicActivation: earlier
            ) == .music,
            "playing music wins over paused YouTube"
        )
        expect(
            AdaptiveCompactArbitrator.resolve(
                downloadAvailable: false,
                codingGlanceAvailable: true,
                mediaSource: .music
            ) == .codingGlance,
            "coding glance temporarily takes over playing music"
        )
        expect(
            AdaptiveCompactArbitrator.resolve(
                downloadAvailable: false,
                codingGlanceAvailable: false,
                mediaSource: .music
            ) == .music,
            "music returns after coding glance ends"
        )
        expect(
            AdaptiveCompactArbitrator.resolve(
                downloadAvailable: true,
                codingGlanceAvailable: true,
                mediaSource: .music
            ) == .download,
            "download remains the highest compact priority"
        )
        expect(
            AdaptiveCompactArbitrator.resolve(
                downloadAvailable: false,
                codingGlanceAvailable: false,
                mediaSource: nil,
                configuredContent: .timer
            ) == .configured,
            "configured timer shows when no media is playing"
        )
        expect(
            AdaptiveCompactArbitrator.resolve(
                downloadAvailable: false,
                codingGlanceAvailable: false,
                mediaSource: .music,
                configuredContent: .timer,
                isTimerActive: true
            ) == .configured,
            "active timer takes precedence over background music"
        )
        expect(
            DeveloperActivityService.frameworkName(command: "node_modules/.bin/next dev") == "Next.js",
            "Next.js activity detection"
        )
        expect(
            DeveloperActivityService.frameworkName(command: "node server.js", packageJSON: "{\"dependencies\":{\"fastify\":\"5\"}}") == "Fastify",
            "Fastify package detection"
        )
        expect(
            DeveloperActivityService.normalizedGitRemote("git@github.com:octocat/hello-world.git")?.absoluteString == "https://github.com/octocat/hello-world",
            "SSH GitHub remote normalization"
        )
        expect(
            !DeveloperActivityService.isDeveloperServerProcess(command: "/System/Library/CoreServices/ControlCenter.app/Contents/MacOS/ControlCenter"),
            "system listener is not classified as a developer server"
        )
        expect(
            DeveloperActivityService.isDeveloperServerProcess(command: "node ./node_modules/.bin/vite dev"),
            "Vite node process is classified as a developer server"
        )
        expect(
            DeveloperActivityService.preferredServerPort(from: [9229, 56064, 3000]) == 3000,
            "web port wins over inspector and internal ports"
        )
        expect(
            DeveloperActivityService.preferredServerPort(from: [56064, 5173]) == 5173,
            "common Vite port wins over an ephemeral port"
        )
        expect(
            DeveloperActivityService.preferredServerPort(from: [9229]) == nil,
            "inspector-only listener is ignored"
        )
        let glanceServer = DeveloperActivity(
            id: "server-101-5173",
            kind: .localhost,
            title: "Vite",
            subtitle: "localhost:5173",
            state: .running
        )
        let glanceDocker = DeveloperActivity(
            id: "docker-summary",
            kind: .docker,
            title: "Docker",
            subtitle: "1 container running",
            state: .running
        )
        let glanceContainer = DockerContainer(
            id: "container-1",
            name: "renotch-api",
            status: "Up 4 seconds",
            isRunning: true
        )
        let codingGlance = DeveloperActivityGlanceResolver.resolve(
            previousActivities: [],
            activities: [glanceServer, glanceDocker],
            previousRunningContainerIDs: [],
            containers: [glanceContainer],
            completions: [],
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        )
        expect(codingGlance?.title == "Coding active", "combined coding glance title")
        expect(codingGlance?.subtitle.contains("1 server") == true, "coding glance includes server count")
        expect(codingGlance?.subtitle.contains("1 Docker container") == true, "coding glance includes Docker count")
        expect(
            DeveloperActivityGlanceResolver.resolve(
                previousActivities: [glanceServer, glanceDocker],
                activities: [glanceServer, glanceDocker],
                previousRunningContainerIDs: [glanceContainer.id],
                containers: [glanceContainer],
                completions: []
            ) == nil,
            "unchanged coding activity does not repeat a glance"
        )
        let metadata = DeveloperActivityService.parseSiteMetadata(
            html: """
            <html><head>
              <title>8888.gadget — iPhone &amp; iPad</title>
              <link rel="icon" sizes="32x32" href="/favicon-32x32.png">
            </head></html>
            """,
            baseURL: URL(string: "http://localhost:3000")!
        )
        expect(metadata.title == "8888.gadget", "site title metadata parsing")
        expect(
            metadata.faviconURL?.absoluteString == "http://localhost:3000/favicon-32x32.png",
            "relative favicon URL resolution"
        )
        expect(
            !DeveloperActivityService.isDeveloperServerProcess(
                command: "/Applications/Antigravity IDE Helper --utility-sub-type=node.mojom.NodeService",
                processName: "Antigravity IDE Helper (Plugin)"
            ),
            "IDE NodeService listener is not classified as a developer server"
        )
        let largeProcessOutput = ShellCommand.run("/usr/bin/seq", ["1", "20000"])
        expect(
            largeProcessOutput.hasSuffix("20000\n"),
            "large process output drains without deadlocking"
        )

        let shelfDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VirtualNotchShelfTests.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: shelfDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: shelfDirectory) }

        let shelfURLs = try (0..<14).map { index in
            let url = shelfDirectory.appendingPathComponent("Item \(index).txt")
            try Data("Item \(index)".utf8).write(to: url)
            return url
        }
        let shelf = ShelfStore()
        let shelfResult = shelf.add(shelfURLs)
        expect(shelfResult.addedCount == 12, "shelf item cap")
        expect(shelfResult.capacityRejectedCount == 2, "shelf capacity rejection")
        expect(shelf.items.first?.displayName == "Item 0.txt", "shelf display name")
        expect(shelf.add([shelfURLs[0]]).duplicateCount == 1, "shelf duplicate filtering")

        try FileManager.default.removeItem(at: shelfURLs[0])
        expect(shelf.removeMissingFiles() == 1, "missing shelf file detection")
        expect(shelf.items.count == 11, "missing shelf file removal")
        if let firstShelfItem = shelf.items.first {
            shelf.remove(firstShelfItem)
        }
        expect(shelf.items.count == 10, "shelf item removal")
        shelf.clear()
        expect(shelf.items.isEmpty, "clear shelf")

        let suite = "VirtualNotchSmokeTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            throw SmokeTestError("could not create isolated defaults")
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let pasteboard = NSPasteboard(name: .init("VirtualNotchSmokeTests"))
        let clipboard = ClipboardService(pasteboard: pasteboard, defaults: defaults)
        for index in 0..<25 {
            clipboard.ingest("Item \(index)")
        }
        clipboard.ingest("Item 24")
        expect(clipboard.items.count == 20, "clipboard history cap")
        expect(clipboard.items.first?.content == "Item 24", "clipboard newest item")
        expect(clipboard.items.last?.content == "Item 5", "clipboard oldest retained item")

        let todos = TodoStore(defaults: defaults)
        expect(!todos.add("   "), "empty todo rejection")
        expect(todos.add("Ship File Shelf"), "todo creation")
        expect(todos.add("Test Focus mode"), "second todo creation")
        expect(todos.items.count == 2, "todo item count")
        expect(todos.remainingCount == 2, "todo remaining count")
        if let firstTodo = todos.items.first {
            todos.toggle(firstTodo)
        }
        expect(todos.remainingCount == 1, "todo completion")
        expect(TodoStore(defaults: defaults).items.count == 2, "todo persistence")
        todos.clearCompleted()
        expect(todos.items.count == 1, "clear completed todos")
        if let remainingTodo = todos.items.first {
            todos.remove(remainingTodo)
        }
        expect(todos.items.isEmpty, "todo removal")

        let store = SettingsStore(defaults: defaults)
        var persisted = NotchSettings.default
        persisted.compactWidth = 250
        store.save(persisted)
        expect(store.load().compactWidth == 250, "settings persistence")
        persisted.notchAppearance = .liquidGlass
        persisted.glassBlurRadius = 24
        persisted.compactContent = .servers
        persisted.compactCornerRadius = 24
        persisted.compactContentBottomPadding = 6
        persisted.compactContentLeadingPadding = 48
        persisted.expandedContentTopPadding = 20
        store.save(persisted)
        expect(store.load().resolvedAppearance == .liquidGlass, "appearance persistence")
        expect(store.load().resolvedGlassBlurRadius == 24, "glass blur persistence")
        expect(store.load().resolvedCompactContent == .servers, "compact content persistence")
        expect(store.load().resolvedCompactCornerRadius == 24, "compact corner radius persistence")
        expect(store.load().resolvedCompactContentLeadingPadding == 48, "compact content leading padding persistence")
        expect(store.load().resolvedCompactContentBottomPadding == 6, "compact content bottom padding persistence")
        expect(store.load().resolvedExpandedContentTopPadding == 20, "expanded content top padding persistence")

        var legacyJSON = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(NotchSettings.default)
        ) as? [String: Any] ?? [:]
        legacyJSON.removeValue(forKey: "notchAppearance")
        legacyJSON.removeValue(forKey: "glassBlurRadius")
        legacyJSON.removeValue(forKey: "compactContent")
        legacyJSON.removeValue(forKey: "compactCornerRadius")
        legacyJSON.removeValue(forKey: "compactContentLeadingPadding")
        legacyJSON.removeValue(forKey: "compactContentTrailingPadding")
        legacyJSON.removeValue(forKey: "compactContentTopPadding")
        legacyJSON.removeValue(forKey: "compactContentBottomPadding")
        legacyJSON.removeValue(forKey: "expandedContentLeadingPadding")
        legacyJSON.removeValue(forKey: "expandedContentTrailingPadding")
        legacyJSON.removeValue(forKey: "expandedContentTopPadding")
        legacyJSON.removeValue(forKey: "expandedContentBottomPadding")
        let settingsWithoutAppearance = try JSONDecoder().decode(
            NotchSettings.self,
            from: JSONSerialization.data(withJSONObject: legacyJSON)
        )
        expect(settingsWithoutAppearance.resolvedAppearance == .black, "legacy appearance default")
        expect(settingsWithoutAppearance.resolvedGlassBlurRadius == 16, "legacy glass blur default")
        expect(settingsWithoutAppearance.resolvedCompactContent == .music, "legacy compact content default")
        expect(settingsWithoutAppearance.resolvedCompactCornerRadius == 11, "legacy compact corner radius default")
        expect(settingsWithoutAppearance.resolvedCompactContentLeadingPadding == 19, "legacy compact content leading padding default")
        expect(settingsWithoutAppearance.resolvedCompactContentBottomPadding == 4, "legacy compact content bottom padding default")
        expect(settingsWithoutAppearance.resolvedExpandedContentTopPadding == 12, "legacy expanded content top padding default")

        let legacySuite = "VirtualNotchLegacyLayoutTests.\(UUID().uuidString)"
        guard let legacyDefaults = UserDefaults(suiteName: legacySuite) else {
            throw SmokeTestError("could not create legacy defaults")
        }
        defer { legacyDefaults.removePersistentDomain(forName: legacySuite) }
        var legacySettings = NotchSettings.default
        legacySettings.expandedWidth = 432
        legacySettings.expandedHeight = 218
        legacyDefaults.set(
            try JSONEncoder().encode(legacySettings),
            forKey: "virtualNotch.settings.v1"
        )
        let migrated = SettingsStore(defaults: legacyDefaults).load()
        expect(migrated.compactWidth == 335, "legacy compact width migration")
        expect(migrated.compactHeight == 30, "legacy compact height migration")
        expect(migrated.expandedWidth == 460, "legacy expanded width migration")
        expect(migrated.expandedHeight == 220, "legacy expanded height migration")

        if failures.isEmpty {
            print("All Re:notch smoke tests passed.")
        } else {
            failures.forEach { fputs("FAIL: \($0)\n", stderr) }
            exit(1)
        }
    }
}

struct SmokeTestError: Error {
    let message: String
    init(_ message: String) { self.message = message }
}
