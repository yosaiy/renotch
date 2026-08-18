import Foundation

struct DeveloperActivityGlance: Equatable, Identifiable {
    let id: UUID
    let kind: DeveloperActivityKind
    let title: String
    let subtitle: String
    let state: DeveloperActivityState
}

enum AdaptiveCompactPresentation: Equatable {
    case download
    case codingGlance
    case browserMedia
    case music
    case configured
}

enum AdaptiveCompactArbitrator {
    static func resolve(
        downloadAvailable: Bool,
        codingGlanceAvailable: Bool,
        mediaSource: AdaptiveMediaSource?,
        configuredContent: CompactNotchContent = .music,
        isTimerActive: Bool = false
    ) -> AdaptiveCompactPresentation {
        if downloadAvailable { return .download }
        if codingGlanceAvailable { return .codingGlance }
        if configuredContent != .music {
            if isTimerActive || mediaSource == nil {
                return .configured
            }
        }
        switch mediaSource {
        case .browser: return .browserMedia
        case .music: return .music
        case nil: return .configured
        }
    }
}

enum DeveloperActivityGlanceResolver {
    static func resolve(
        previousActivities: [DeveloperActivity],
        activities: [DeveloperActivity],
        previousRunningContainerIDs: Set<String>,
        containers: [DockerContainer],
        completions: [DeveloperActivity],
        id: UUID = UUID()
    ) -> DeveloperActivityGlance? {
        if let completion = completions.first {
            return DeveloperActivityGlance(
                id: id,
                kind: completion.kind,
                title: completionTitle(for: completion.kind),
                subtitle: completion.title,
                state: completion.state
            )
        }

        let previousRunningActivityIDs = Set(
            previousActivities
                .filter { $0.state == .running }
                .map(\.id)
        )
        let newlyRunningActivities = activities.filter {
            $0.state == .running && !previousRunningActivityIDs.contains($0.id)
        }
        let runningContainers = containers.filter(\.isRunning)
        let newlyRunningContainers = runningContainers.filter {
            !previousRunningContainerIDs.contains($0.id)
        }

        var triggerKinds = Set(newlyRunningActivities.map(\.kind))
        if !newlyRunningContainers.isEmpty {
            triggerKinds.insert(.docker)
        }
        guard !triggerKinds.isEmpty else { return nil }

        if triggerKinds.count > 1 {
            return DeveloperActivityGlance(
                id: id,
                kind: preferredKind(in: triggerKinds),
                title: "Coding active",
                subtitle: activeSummary(activities: activities, containers: containers),
                state: .running
            )
        }

        if let container = newlyRunningContainers.first {
            let count = runningContainers.count
            return DeveloperActivityGlance(
                id: id,
                kind: .docker,
                title: "Docker active",
                subtitle: count == 1 ? container.name : "\(container.name) · \(count) running",
                state: .running
            )
        }

        guard let activity = newlyRunningActivities.sorted(by: activityPriority).first else {
            return nil
        }
        return DeveloperActivityGlance(
            id: id,
            kind: activity.kind,
            title: startTitle(for: activity.kind),
            subtitle: activitySubtitle(activity),
            state: activity.state
        )
    }

    private static func preferredKind(in kinds: Set<DeveloperActivityKind>) -> DeveloperActivityKind {
        let priority: [DeveloperActivityKind] = [
            .deployment, .build, .docker, .localhost, .terminal, .git
        ]
        return priority.first(where: kinds.contains) ?? .localhost
    }

    private static func activityPriority(_ lhs: DeveloperActivity, _ rhs: DeveloperActivity) -> Bool {
        let priority: [DeveloperActivityKind: Int] = [
            .deployment: 0, .build: 1, .docker: 2,
            .localhost: 3, .terminal: 4, .git: 5
        ]
        return (priority[lhs.kind] ?? 9) < (priority[rhs.kind] ?? 9)
    }

    private static func startTitle(for kind: DeveloperActivityKind) -> String {
        switch kind {
        case .localhost: return "Server online"
        case .build: return "Build started"
        case .docker: return "Docker active"
        case .git: return "Git changes detected"
        case .deployment: return "Deploy started"
        case .terminal: return "Task running"
        }
    }

    private static func completionTitle(for kind: DeveloperActivityKind) -> String {
        switch kind {
        case .build: return "Build complete"
        case .deployment: return "Deploy complete"
        case .terminal: return "Task complete"
        default: return "Coding update"
        }
    }

    private static func activitySubtitle(_ activity: DeveloperActivity) -> String {
        if activity.kind == .localhost {
            return "\(activity.title) · \(activity.subtitle)"
        }
        if let directory = activity.workingDirectory?.lastPathComponent, !directory.isEmpty {
            return "\(activity.subtitle) · \(directory)"
        }
        return activity.subtitle
    }

    private static func activeSummary(
        activities: [DeveloperActivity],
        containers: [DockerContainer]
    ) -> String {
        let serverCount = activities.filter { $0.kind == .localhost && $0.state == .running }.count
        let buildCount = activities.filter { $0.kind == .build && $0.state == .running }.count
        let deploymentCount = activities.filter { $0.kind == .deployment && $0.state == .running }.count
        let terminalCount = activities.filter { $0.kind == .terminal && $0.state == .running }.count
        let dockerCount = containers.filter(\.isRunning).count
        var parts: [String] = []
        if serverCount > 0 { parts.append("\(serverCount) server\(serverCount == 1 ? "" : "s")") }
        if dockerCount > 0 { parts.append("\(dockerCount) Docker container\(dockerCount == 1 ? "" : "s")") }
        if buildCount > 0 { parts.append("\(buildCount) build\(buildCount == 1 ? "" : "s")") }
        if deploymentCount > 0 { parts.append("\(deploymentCount) deploy\(deploymentCount == 1 ? "" : "s")") }
        if terminalCount > 0 { parts.append("\(terminalCount) task\(terminalCount == 1 ? "" : "s")") }
        return parts.prefix(3).joined(separator: " · ")
    }
}
