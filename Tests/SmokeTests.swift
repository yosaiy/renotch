import AppKit
import Foundation

@main
struct SmokeTests {
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
        settings.collapseDelay = 0
        settings.clampValues()
        expect(settings.compactWidth == 180, "compact width lower bound")
        expect(settings.compactHeight == 300, "compact height upper bound")
        expect(settings.expandedWidth == 500, "expanded width upper bound")
        expect(settings.expandedHeight == 260, "expanded height upper bound")
        expect(settings.resolvedCompactCornerRadius == 40, "compact corner radius upper bound")
        expect(settings.collapseDelay == 0.3, "collapse delay lower bound")
        expect(settings.resolvedCompactContent == .music, "music is the default compact content")
        expect(CompactNotchContent.calendar.section == .calendar, "calendar compact destination")

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

        expect(NotchSettings.default.compactWidth == 220, "collapsed width")
        expect(NotchSettings.default.compactHeight == 36, "recommended compact height")
        expect(NotchSettings.default.expandedWidth == 460, "recommended expanded width")
        expect(NotchSettings.default.expandedHeight == 220, "expanded menu height")
        expect(NotchSettings.default.resolvedCompactCornerRadius == 18, "default compact corner radius")
        expect(NotchSettings.dragWidth == 500, "drag width")
        expect(NotchSettings.dragHeight == 120, "drag height")

        expect(TimerService.formatted(65) == "01:05", "minute timer formatting")
        expect(TimerService.formatted(3_661) == "1:01:01", "hour timer formatting")
        expect(TimerService.formatted(-1) == "00:00", "negative timer formatting")
        expect(MusicService.parseAppleScriptNumber("309.389") == 309.389, "music dot-decimal parsing")
        expect(MusicService.parseAppleScriptNumber("309,389") == 309.389, "music comma-decimal parsing")
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
        persisted.notchAppearance = .glassmorphism
        persisted.glassBlurRadius = 24
        persisted.compactContent = .servers
        persisted.compactCornerRadius = 24
        store.save(persisted)
        expect(store.load().resolvedAppearance == .glassmorphism, "appearance persistence")
        expect(store.load().resolvedGlassBlurRadius == 24, "glass blur persistence")
        expect(store.load().resolvedCompactContent == .servers, "compact content persistence")
        expect(store.load().resolvedCompactCornerRadius == 24, "compact corner radius persistence")

        var legacyJSON = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(NotchSettings.default)
        ) as? [String: Any] ?? [:]
        legacyJSON.removeValue(forKey: "notchAppearance")
        legacyJSON.removeValue(forKey: "glassBlurRadius")
        legacyJSON.removeValue(forKey: "compactContent")
        legacyJSON.removeValue(forKey: "compactCornerRadius")
        let settingsWithoutAppearance = try JSONDecoder().decode(
            NotchSettings.self,
            from: JSONSerialization.data(withJSONObject: legacyJSON)
        )
        expect(settingsWithoutAppearance.resolvedAppearance == .black, "legacy appearance default")
        expect(settingsWithoutAppearance.resolvedGlassBlurRadius == 16, "legacy glass blur default")
        expect(settingsWithoutAppearance.resolvedCompactContent == .music, "legacy compact content default")
        expect(settingsWithoutAppearance.resolvedCompactCornerRadius == 18, "legacy compact corner radius default")

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
        expect(migrated.compactWidth == 220, "legacy compact width migration")
        expect(migrated.compactHeight == 36, "legacy compact height migration")
        expect(migrated.expandedWidth == 460, "legacy expanded width migration")
        expect(migrated.expandedHeight == 220, "legacy expanded height migration")

        if failures.isEmpty {
            print("All Virtual Notch smoke tests passed.")
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
