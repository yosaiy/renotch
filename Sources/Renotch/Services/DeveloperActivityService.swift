import AppKit
import Darwin
import Foundation

struct LocalSiteMetadata: Equatable {
    let title: String?
    let faviconURL: URL?
}

@MainActor
final class DeveloperActivityService: ObservableObject {
    @Published private(set) var activities: [DeveloperActivity] = []
    @Published private(set) var containers: [DockerContainer] = []
    @Published private(set) var gitSnapshot: GitActivitySnapshot?
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefresh = Date.distantPast
    @Published private(set) var glance: DeveloperActivityGlance?

    private var refreshTimer: Timer?
    private var priorRunningActivities: [String: DeveloperActivity] = [:]
    private var priorRunningContainerIDs = Set<String>()
    private var recentCompletions: [DeveloperActivity] = []
    private var glanceWorkItem: DispatchWorkItem?

    var primaryActivity: DeveloperActivity {
        // Let a freshly completed task briefly take over the compact notch so
        // completion feedback is visible even while a server keeps running.
        recentCompletions.first ?? activities.first ?? DeveloperActivity(
            id: "developer-activity-idle",
            kind: .localhost,
            title: "Developer activity",
            subtitle: "No active tasks",
            state: .idle,
            detail: "Start a local server, build, or deployment to see it here."
        )
    }

    var primaryServerActivity: DeveloperActivity {
        activities.first(where: { $0.kind == .localhost && $0.state == .running }) ?? DeveloperActivity(
            id: "developer-server-idle",
            kind: .localhost,
            title: "Servers",
            subtitle: "No active servers",
            state: .idle,
            detail: "Start a local development server to see it here."
        )
    }

    var runningCount: Int {
        activities.filter { $0.state == .running }.count
    }

    init() {
        start()
    }

    deinit {
        refreshTimer?.invalidate()
        glanceWorkItem?.cancel()
    }

    func start() {
        guard refreshTimer == nil else { return }
        refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task {
            let snapshot = await Task.detached(priority: .utility) {
                Self.collectSnapshot()
            }.value
            apply(snapshot)
        }
    }

    func stop(_ activity: DeveloperActivity) {
        guard let pid = activity.processID, pid > 1 else { return }
        if Darwin.kill(pid, SIGTERM) == 0 {
            NSSound.beep()
            refreshSoon()
        }
    }

    func open(_ activity: DeveloperActivity) {
        if let url = activity.url {
            NSWorkspace.shared.open(url)
        } else if let directory = activity.workingDirectory {
            NSWorkspace.shared.open(directory)
        }
    }

    func copyPrimaryValue(_ activity: DeveloperActivity) {
        let value = activity.url?.absoluteString ?? activity.detail ?? activity.subtitle
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    func revealFolder(_ activity: DeveloperActivity) {
        guard let directory = activity.workingDirectory else { return }
        NSWorkspace.shared.activateFileViewerSelecting([directory])
    }

    func stopContainer(_ container: DockerContainer) {
        guard let docker = Self.dockerExecutable() else { return }
        Task.detached(priority: .utility) {
            _ = ShellCommand.run(docker, ["stop", container.id])
        }
        refreshSoon()
    }

    func openContainerLogs(_ container: DockerContainer) {
        guard let docker = Self.dockerExecutable() else { return }
        let command = "\(Self.shellQuote(docker)) logs --tail 120 -f \(Self.shellQuote(container.id))"
        Self.openTerminal(command: command, directory: nil)
    }

    func openLogs(for activity: DeveloperActivity) {
        guard let directory = activity.workingDirectory else { return }
        Self.openTerminal(command: nil, directory: directory)
    }

    func pushGit() {
        runGitAction("push")
    }

    func pullGit() {
        runGitAction("pull", arguments: ["--ff-only"])
    }

    func copyCommitSHA() {
        guard let sha = gitSnapshot?.commitSHA else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(sha, forType: .string)
    }

    func openGitRemote() {
        guard let url = gitSnapshot?.remoteURL else { return }
        NSWorkspace.shared.open(url)
    }

    private func runGitAction(_ action: String, arguments: [String] = []) {
        guard let root = gitSnapshot?.root else { return }
        let command = "git \(action) \(arguments.joined(separator: " "))"
        Self.openTerminal(command: command, directory: root)
    }

    private func refreshSoon() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            refresh()
        }
    }

    private func apply(_ snapshot: ActivityCollectionSnapshot) {
        let previousActivities = Array(priorRunningActivities.values)
        let newRunning = Dictionary(uniqueKeysWithValues: snapshot.activities.map { ($0.id, $0) })
        let completed = priorRunningActivities.values.compactMap { previous -> DeveloperActivity? in
            guard newRunning[previous.id] == nil,
                  previous.kind == .build || previous.kind == .deployment || previous.kind == .terminal else {
                return nil
            }
            return DeveloperActivity(
                id: "completed-\(previous.id)-\(Int(Date().timeIntervalSince1970))",
                kind: previous.kind,
                title: previous.title,
                subtitle: "Completed",
                state: .success,
                workingDirectory: previous.workingDirectory,
                detail: previous.detail
            )
        }

        recentCompletions = (completed + recentCompletions)
            .filter { activity in
                guard let timestamp = Int(activity.id.split(separator: "-").last ?? "0") else { return false }
                return Date().timeIntervalSince1970 - Double(timestamp) < 12
            }
        if let nextGlance = DeveloperActivityGlanceResolver.resolve(
            previousActivities: previousActivities,
            activities: snapshot.activities,
            previousRunningContainerIDs: priorRunningContainerIDs,
            containers: snapshot.containers,
            completions: completed
        ) {
            present(nextGlance)
        }
        priorRunningActivities = newRunning
        priorRunningContainerIDs = Set(snapshot.containers.filter(\.isRunning).map(\.id))
        activities = Self.sortActivities(snapshot.activities + recentCompletions)
        containers = snapshot.containers
        gitSnapshot = snapshot.gitSnapshot
        lastRefresh = Date()
        isRefreshing = false
    }

    private func present(_ nextGlance: DeveloperActivityGlance) {
        glanceWorkItem?.cancel()
        glance = nextGlance
        let glanceID = nextGlance.id
        let work = DispatchWorkItem { [weak self] in
            guard self?.glance?.id == glanceID else { return }
            self?.glance = nil
        }
        glanceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
    }

    private static func sortActivities(_ activities: [DeveloperActivity]) -> [DeveloperActivity] {
        let kindPriority: [DeveloperActivityKind: Int] = [
            .deployment: 0, .build: 1, .localhost: 2,
            .docker: 3, .git: 4, .terminal: 5
        ]
        let statePriority: [DeveloperActivityState: Int] = [
            .failed: 0, .running: 1, .success: 2, .idle: 3
        ]
        return activities.sorted {
            let lhs = (statePriority[$0.state] ?? 9, kindPriority[$0.kind] ?? 9, $0.title)
            let rhs = (statePriority[$1.state] ?? 9, kindPriority[$1.kind] ?? 9, $1.title)
            return lhs < rhs
        }
    }

    nonisolated private static func collectSnapshot() -> ActivityCollectionSnapshot {
        let processes = ProcessScanner.runningProcesses()
        let servers = LocalhostMonitor.scan(processes: processes)
        let tasks = TerminalActivityMonitor.scan(processes: processes)
        let containers = DockerActivityMonitor.scan()
        let candidateDirectories = (servers + tasks).compactMap(\.workingDirectory)
        let git = GitActivityMonitor.scan(candidateDirectories: candidateDirectories)

        var activities = servers + tasks
        if !containers.isEmpty {
            let running = containers.filter(\.isRunning).count
            activities.append(DeveloperActivity(
                id: "docker-summary",
                kind: .docker,
                title: "Docker",
                subtitle: "\(running) container\(running == 1 ? "" : "s") running",
                state: running > 0 ? .running : .idle,
                detail: "\(containers.count) total container\(containers.count == 1 ? "" : "s")"
            ))
        }
        if let git {
            activities.append(DeveloperActivity(
                id: "git-\(git.root.path)",
                kind: .git,
                title: git.repositoryName,
                subtitle: git.changedFiles == 0 ? "\(git.branch) · clean" : "\(git.changedFiles) changed · \(git.branch)",
                state: git.changedFiles == 0 ? .idle : .running,
                workingDirectory: git.root,
                detail: git.commitSHA
            ))
        }
        return ActivityCollectionSnapshot(
            activities: activities,
            containers: containers,
            gitSnapshot: git
        )
    }

    nonisolated static func frameworkName(command: String, packageJSON: String? = nil) -> String {
        let value = (command + " " + (packageJSON ?? "")).lowercased()
        if value.contains("next") { return "Next.js" }
        if value.contains("vite") { return "Vite" }
        if value.contains("astro") { return "Astro" }
        if value.contains("nuxt") { return "Nuxt" }
        if value.contains("react-scripts") || value.contains("\"react\"") { return "React" }
        if value.contains("fastify") { return "Fastify" }
        if value.contains("express") { return "Express" }
        if value.contains("bun") { return "Bun" }
        if value.contains("deno") { return "Deno" }
        if value.contains("python") { return "Python" }
        if value.contains("node") { return "Node.js" }
        return "Local server"
    }

    nonisolated static func normalizedGitRemote(_ value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("git@github.com:") {
            let path = trimmed.replacingOccurrences(of: "git@github.com:", with: "")
                .replacingOccurrences(of: ".git", with: "")
            return URL(string: "https://github.com/\(path)")
        }
        return URL(string: trimmed.replacingOccurrences(of: ".git", with: ""))
    }

    nonisolated static func isDeveloperServerProcess(
        command: String,
        processName: String? = nil
    ) -> Bool {
        let value = command.lowercased()
        let name = (processName ?? command.split(separator: " ").first.map(String.init) ?? "")
            .lowercased()
        let ignoredCommandMarkers = [
            "node.mojom.nodeservice", "--type=utility", "language_server",
            "antigravity ide helper", "figma_agent", "controlcenter.app"
        ]
        guard !ignoredCommandMarkers.contains(where: value.contains) else { return false }

        let runtimeNames = ["node", "bun", "deno", "ruby", "php", "java", "swift", "uvicorn"]
        let isRuntime = runtimeNames.contains(name)
            || name.hasPrefix("python")
            || name == "go"
        let frameworks = [
            "next", "vite", "astro", "nuxt", "express", "fastify",
            "react-scripts", "flask run", "rails server", "dotnet watch",
            "cargo run", "air -c"
        ]
        return isRuntime || frameworks.contains(where: value.contains)
    }

    nonisolated static func preferredServerPort(from ports: [Int]) -> Int? {
        let inspectorPorts: Set<Int> = [5858, 9222, 9229, 9230]
        let commonDevelopmentPorts = [
            3000, 3001, 4173, 4200, 4321, 5000, 5173, 5174,
            8000, 8001, 8080, 8081, 8787
        ]
        let commonPriority = Dictionary(
            uniqueKeysWithValues: commonDevelopmentPorts.enumerated().map { ($0.element, $0.offset) }
        )

        return Set(ports)
            .filter { $0 >= 1024 && !inspectorPorts.contains($0) }
            .min { lhs, rhs in
                let lhsScore = commonPriority[lhs].map { $0 } ?? (lhs < 10_000 ? 100 + lhs : 100_000 + lhs)
                let rhsScore = commonPriority[rhs].map { $0 } ?? (rhs < 10_000 ? 100 + rhs : 100_000 + rhs)
                return lhsScore < rhsScore
            }
    }

    nonisolated static func parseSiteMetadata(html: String, baseURL: URL) -> LocalSiteMetadata {
        let metaTags = matches(pattern: #"<meta\b[^>]*>"#, in: html)
        let siteName = metaTags.lazy.compactMap { tag -> String? in
            let key = attribute("property", in: tag) ?? attribute("name", in: tag)
            guard let key,
                  ["og:site_name", "application-name"].contains(key.lowercased()),
                  let content = attribute("content", in: tag) else { return nil }
            return cleanSiteTitle(content)
        }.first

        let pageTitle = firstCapture(
            pattern: #"<title\b[^>]*>(.*?)</title>"#,
            in: html,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ).flatMap(cleanSiteTitle)

        let linkTags = matches(pattern: #"<link\b[^>]*>"#, in: html)
        var appleTouchIcon: URL?
        var standardIcon: URL?
        for tag in linkTags {
            guard let relation = attribute("rel", in: tag)?.lowercased(),
                  let href = attribute("href", in: tag),
                  let resolvedURL = URL(string: href, relativeTo: baseURL)?.absoluteURL else { continue }
            let relations = Set(relation.split(whereSeparator: \Character.isWhitespace).map(String.init))
            if relations.contains("icon") && !relations.contains("apple-touch-icon") {
                standardIcon = standardIcon ?? resolvedURL
            } else if relations.contains("apple-touch-icon") {
                appleTouchIcon = appleTouchIcon ?? resolvedURL
            }
        }

        return LocalSiteMetadata(
            title: siteName ?? pageTitle,
            faviconURL: standardIcon ?? appleTouchIcon ?? URL(string: "/favicon.ico", relativeTo: baseURL)?.absoluteURL
        )
    }

    nonisolated private static func matches(pattern: String, in value: String) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let range = NSRange(value.startIndex..., in: value)
        return expression.matches(in: value, range: range).compactMap { match in
            Range(match.range, in: value).map { String(value[$0]) }
        }
    }

    nonisolated private static func firstCapture(
        pattern: String,
        in value: String,
        options: NSRegularExpression.Options = []
    ) -> String? {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: options),
              let match = expression.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: value) else { return nil }
        return String(value[range])
    }

    nonisolated private static func attribute(_ name: String, in tag: String) -> String? {
        firstCapture(
            pattern: #"\b"# + NSRegularExpression.escapedPattern(for: name) + #"\s*=\s*[\"']([^\"']*)[\"']"#,
            in: tag,
            options: [.caseInsensitive]
        )
    }

    nonisolated private static func cleanSiteTitle(_ rawValue: String) -> String? {
        var value = rawValue
            .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        for separator in [" — ", " – ", " | ", " · ", " - "] {
            if let range = value.range(of: separator), range.lowerBound != value.startIndex {
                value = String(value[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        return value.isEmpty ? nil : value
    }

    nonisolated private static func dockerExecutable() -> String? {
        ["/opt/homebrew/bin/docker", "/usr/local/bin/docker", "/usr/bin/docker"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    nonisolated private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    nonisolated private static func openTerminal(command: String?, directory: URL?) {
        let path = directory?.path ?? NSHomeDirectory()
        var script = "tell application \"Terminal\" to do script \"cd \(shellQuote(path))"
        if let command { script += "; \(command.replacingOccurrences(of: "\"", with: "\\\""))" }
        script += "\""
        _ = ShellCommand.run("/usr/bin/osascript", ["-e", script])
    }
}

private struct ActivityCollectionSnapshot {
    let activities: [DeveloperActivity]
    let containers: [DockerContainer]
    let gitSnapshot: GitActivitySnapshot?
}

private struct RunningProcess {
    let pid: Int32
    let command: String
    let elapsed: String
}

private final class LocalSiteMetadataCache: @unchecked Sendable {
    private struct LoadedMetadata {
        let title: String?
        let faviconData: Data?
    }

    private struct Entry {
        let metadata: LoadedMetadata?
        let fetchedAt: Date
    }

    private let lock = NSLock()
    private var entries: [URL: Entry] = [:]

    func metadata(for url: URL) -> (title: String?, faviconData: Data?)? {
        lock.lock()
        if let entry = entries[url] {
            let lifetime: TimeInterval = entry.metadata == nil ? 6 : 30
            if Date().timeIntervalSince(entry.fetchedAt) < lifetime {
                lock.unlock()
                return entry.metadata.map { ($0.title, $0.faviconData) }
            }
        }
        lock.unlock()

        let html = ShellCommand.run("/usr/bin/curl", [
            "-g", "-sS", "--connect-timeout", "0.5", "--max-time", "1.5",
            "--max-filesize", "524288", url.absoluteString
        ])
        let parsed = html.isEmpty
            ? nil
            : DeveloperActivityService.parseSiteMetadata(html: html, baseURL: url)
        let faviconData = parsed?.faviconURL.flatMap { faviconURL -> Data? in
            let data = ShellCommand.runData("/usr/bin/curl", [
                "-g", "-sS", "--connect-timeout", "0.5", "--max-time", "1.5",
                "--max-filesize", "524288", faviconURL.absoluteString
            ])
            return data.isEmpty ? nil : data
        }
        let metadata = parsed.map { LoadedMetadata(title: $0.title, faviconData: faviconData) }

        lock.lock()
        entries[url] = Entry(metadata: metadata, fetchedAt: Date())
        lock.unlock()
        return metadata.map { ($0.title, $0.faviconData) }
    }
}

private enum ProcessScanner {
    static func runningProcesses() -> [RunningProcess] {
        let output = ShellCommand.run("/bin/ps", ["-axo", "pid=,etime=,command="])
        return output.split(separator: "\n").compactMap { line in
            let parts = line.split(maxSplits: 2, whereSeparator: \Character.isWhitespace)
            guard parts.count == 3, let pid = Int32(parts[0]) else { return nil }
            return RunningProcess(pid: pid, command: String(parts[2]), elapsed: String(parts[1]))
        }
    }

    static func workingDirectory(pid: Int32) -> URL? {
        let output = ShellCommand.run("/usr/sbin/lsof", ["-a", "-p", String(pid), "-d", "cwd", "-Fn"])
        guard let pathLine = output.split(separator: "\n").first(where: { $0.first == "n" }) else { return nil }
        return URL(fileURLWithPath: String(pathLine.dropFirst()), isDirectory: true)
    }
}

private enum LocalhostMonitor {
    private static let metadataCache = LocalSiteMetadataCache()

    static func scan(processes: [RunningProcess]) -> [DeveloperActivity] {
        let processMap = Dictionary(uniqueKeysWithValues: processes.map { ($0.pid, $0) })
        let output = ShellCommand.run("/usr/sbin/lsof", ["-nP", "-iTCP", "-sTCP:LISTEN", "-Fpcn"])
        var pid: Int32?
        var processNames: [Int32: String] = [:]
        var portsByProcess: [Int32: Set<Int>] = [:]
        var results: [DeveloperActivity] = []
        var seenPorts = Set<Int>()

        for line in output.split(separator: "\n").map(String.init) {
            guard let prefix = line.first else { continue }
            let value = String(line.dropFirst())
            switch prefix {
            case "p": pid = Int32(value)
            case "c":
                if let pid { processNames[pid] = value }
            case "n":
                guard let pid,
                      let port = parsePort(value),
                      port >= 1024 else { continue }
                portsByProcess[pid, default: []].insert(port)
            default: break
            }
        }

        let candidates = portsByProcess.compactMap { pid, ports -> (Int32, Int)? in
            guard let port = DeveloperActivityService.preferredServerPort(from: Array(ports)) else {
                return nil
            }
            return (pid, port)
        }
        .sorted { lhs, rhs in
            let preferred = DeveloperActivityService.preferredServerPort(from: [lhs.1, rhs.1])
            if lhs.1 != rhs.1, let preferred { return lhs.1 == preferred }
            return lhs.0 > rhs.0
        }

        for (pid, port) in candidates {
            guard !seenPorts.contains(port) else { continue }
            let processName = processNames[pid] ?? ""
            let fullCommand = processMap[pid]?.command ?? processName
            guard DeveloperActivityService.isDeveloperServerProcess(
                command: fullCommand,
                processName: processName
            ) else { continue }
            seenPorts.insert(port)
            let directory = ProcessScanner.workingDirectory(pid: pid)
            let packageJSON = directory.flatMap {
                try? String(contentsOf: $0.appendingPathComponent("package.json"), encoding: .utf8)
            }
            let framework = DeveloperActivityService.frameworkName(
                command: fullCommand,
                packageJSON: packageJSON
            )
            let serverURL = URL(string: "http://localhost:\(port)")
            let siteMetadata = serverURL.flatMap { metadataCache.metadata(for: $0) }
            results.append(DeveloperActivity(
                id: "server-\(pid)-\(port)",
                kind: .localhost,
                title: siteMetadata?.title ?? framework,
                subtitle: "localhost:\(port)",
                state: .running,
                processID: pid,
                url: serverURL,
                faviconData: siteMetadata?.faviconData,
                workingDirectory: directory,
                detail: directory?.path ?? "Detected from a local listening port"
            ))
        }
        return Array(results.prefix(12))
    }

    static func parsePort(_ endpoint: String) -> Int? {
        let value = endpoint.split(separator: " ").first.map(String.init) ?? endpoint
        guard let colon = value.lastIndex(of: ":") else { return nil }
        let portText = value[value.index(after: colon)...].prefix { $0.isNumber }
        return Int(portText)
    }

}

private enum TerminalActivityMonitor {
    static func scan(processes: [RunningProcess]) -> [DeveloperActivity] {
        processes.compactMap { process in
            let value = process.command.lowercased()
            let kind: DeveloperActivityKind
            let title: String

            if matches(value, ["vercel deploy", "netlify deploy", "fly deploy", "wrangler deploy", "firebase deploy", "railway up"]) {
                kind = .deployment
                title = "Deployment"
            } else if matches(value, ["swift build", "xcodebuild", "npm run build", "pnpm build", "yarn build", "vite build", "next build", "docker build"]) {
                kind = .build
                title = "Build"
            } else if matches(value, ["npm install", "npm i ", "pnpm install", "yarn install", "bun install", "pod install", "bundle install"]) {
                kind = .terminal
                title = commandTitle(process.command)
            } else {
                return nil
            }

            let directory = ProcessScanner.workingDirectory(pid: process.pid)
            return DeveloperActivity(
                id: "task-\(process.pid)",
                kind: kind,
                title: title,
                subtitle: "Running · \(process.elapsed)",
                state: .running,
                processID: process.pid,
                workingDirectory: directory,
                detail: directory?.path ?? "Detected from a running local process"
            )
        }
    }

    private static func matches(_ value: String, _ needles: [String]) -> Bool {
        needles.contains(where: value.contains)
    }

    private static func commandTitle(_ command: String) -> String {
        command.split(separator: " ").suffix(3).joined(separator: " ")
    }
}

private enum DockerActivityMonitor {
    static func scan() -> [DockerContainer] {
        guard let docker = ["/opt/homebrew/bin/docker", "/usr/local/bin/docker", "/usr/bin/docker"]
            .first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else { return [] }
        let output = ShellCommand.run(docker, ["ps", "-a", "--format", "{{.ID}}\t{{.Names}}\t{{.Status}}\t{{.State}}"])
        return output.split(separator: "\n").compactMap { line in
            let values = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard values.count >= 4 else { return nil }
            return DockerContainer(
                id: values[0],
                name: values[1],
                status: values[2],
                isRunning: values[3].lowercased() == "running"
            )
        }
    }
}

private enum GitActivityMonitor {
    static func scan(candidateDirectories: [URL]) -> GitActivitySnapshot? {
        let candidates = candidateDirectories + [URL(fileURLWithPath: FileManager.default.currentDirectoryPath)]
        for directory in candidates {
            let rootValue = ShellCommand.run("/usr/bin/git", ["-C", directory.path, "rev-parse", "--show-toplevel"])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rootValue.isEmpty else { continue }
            let root = URL(fileURLWithPath: rootValue, isDirectory: true)
            let status = ShellCommand.run("/usr/bin/git", ["-C", root.path, "status", "--porcelain"])
            let branch = ShellCommand.run("/usr/bin/git", ["-C", root.path, "branch", "--show-current"])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let sha = ShellCommand.run("/usr/bin/git", ["-C", root.path, "rev-parse", "--short", "HEAD"])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let tracking = ShellCommand.run("/usr/bin/git", ["-C", root.path, "rev-list", "--left-right", "--count", "HEAD...@{upstream}"])
                .split(whereSeparator: \Character.isWhitespace).compactMap { Int($0) }
            let remote = ShellCommand.run("/usr/bin/git", ["-C", root.path, "remote", "get-url", "origin"])
            return GitActivitySnapshot(
                repositoryName: root.lastPathComponent,
                branch: branch.isEmpty ? "detached" : branch,
                changedFiles: status.split(separator: "\n").count,
                commitSHA: sha,
                ahead: tracking.first ?? 0,
                behind: tracking.dropFirst().first ?? 0,
                root: root,
                remoteURL: DeveloperActivityService.normalizedGitRemote(remote)
            )
        }
        return nil
    }
}

enum ShellCommand {
    static func run(_ executable: String, _ arguments: [String]) -> String {
        String(data: runData(executable, arguments), encoding: .utf8) ?? ""
    }

    static func runData(_ executable: String, _ arguments: [String]) -> Data {
        guard FileManager.default.isExecutableFile(atPath: executable) else { return Data() }
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            // Drain stdout while the child is running. Waiting first can deadlock
            // when commands such as `ps` produce more than the pipe buffer holds.
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return data
        } catch {
            return Data()
        }
    }
}
