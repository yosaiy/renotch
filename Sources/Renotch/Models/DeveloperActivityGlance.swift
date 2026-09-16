import Foundation

struct AuthGlance: Equatable, Identifiable, Sendable {
    let id: UUID
    let title: String
    let subtitle: String
    let isSuccess: Bool

    init(id: UUID = UUID(), title: String = "面容认证", subtitle: String = "认证成功", isSuccess: Bool = true) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.isSuccess = isSuccess
    }
}

struct DeveloperActivityGlance: Equatable, Identifiable, Sendable {
    let id: UUID
    let kind: DeveloperActivityKind
    let title: String
    let subtitle: String
    let state: DeveloperActivityState
}

enum AdaptiveCompactPresentation: Equatable, Sendable {
    case faceID(AuthGlance)
    case download
    case codingGlance
    case browserMedia
    case music
    case configured
}

enum AdaptiveCompactArbitrator {
    static func resolve(
        authGlance: AuthGlance? = nil,
        downloadAvailable: Bool,
        codingGlanceAvailable: Bool,
        mediaSource: AdaptiveMediaSource?,
        configuredContent: CompactNotchContent = .music,
        isTimerActive: Bool = false
    ) -> AdaptiveCompactPresentation {
        if let authGlance { return .faceID(authGlance) }
        if downloadAvailable { return .download }
        if codingGlanceAvailable { return .codingGlance }
        if configuredContent != .music {
            return .configured
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
                title: "开发任务进行中",
                subtitle: activeSummary(activities: activities, containers: containers),
                state: .running
            )
        }

        if let container = newlyRunningContainers.first {
            let count = runningContainers.count
            return DeveloperActivityGlance(
                id: id,
                kind: .docker,
                title: "Docker 运行中",
                subtitle: count == 1 ? container.name : "\(container.name) · \(count) 项运行中",
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
        case .localhost: return "服务已启动"
        case .build: return "构建已开始"
        case .docker: return "Docker 运行中"
        case .git: return "检测到 Git 改动"
        case .deployment: return "部署已开始"
        case .terminal: return "任务进行中"
        }
    }

    private static func completionTitle(for kind: DeveloperActivityKind) -> String {
        switch kind {
        case .build: return "构建已完成"
        case .deployment: return "部署已完成"
        case .terminal: return "任务已完成"
        default: return "开发活动更新"
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
        if serverCount > 0 { parts.append("\(serverCount) 个服务") }
        if dockerCount > 0 { parts.append("\(dockerCount) 个 Docker 容器") }
        if buildCount > 0 { parts.append("\(buildCount) 项构建") }
        if deploymentCount > 0 { parts.append("\(deploymentCount) 项部署") }
        if terminalCount > 0 { parts.append("\(terminalCount) 项任务") }
        return parts.prefix(3).joined(separator: " · ")
    }
}
