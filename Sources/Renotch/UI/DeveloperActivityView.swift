import AppKit
import SwiftUI

struct DeveloperActivityView: View {
    @ObservedObject var service: DeveloperActivityService
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedKind: DeveloperActivityKind?
    @State private var isRefreshHovered = false

    private var activeKind: DeveloperActivityKind {
        selectedKind ?? service.primaryActivity.kind
    }

    private var serversList: [DeveloperActivity] {
        service.activities.filter { $0.kind == .localhost && $0.state == .running }
    }

    private var visibleActivity: DeveloperActivity {
        if let selectedKind,
           let match = service.activities.first(where: { $0.kind == selectedKind }) {
            return match
        }
        if let selectedKind {
            return DeveloperActivity(
                id: "developer-\(selectedKind.rawValue)-idle",
                kind: selectedKind,
                title: "No active \(selectedKind.title.lowercased())",
                subtitle: selectedKind.idleHeadline,
                state: .idle,
                detail: selectedKind.emptyDescription
            )
        }
        return service.primaryActivity
    }

    var body: some View {
        HStack(spacing: 12) {
            // Left Vertical Channel Rail (All 6 dev monitors labeled + live counts)
            channelRail
                .frame(width: 112)

            // Structural Hairline Divider
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)
                .padding(.vertical, 2)

            // Right Full-Height Live Inspector Stage
            VStack(spacing: 0) {
                stageHeader
                    .padding(.bottom, 6)

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)

                stageBody
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.top, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: selectedKind)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: service.primaryActivity.id)
    }

    // MARK: - Left Vertical Channel Rail

    private var channelRail: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 2) {
                ForEach(DeveloperActivityKind.allCases) { kind in
                    ChannelRailItem(
                        kind: kind,
                        badgeCount: liveCount(for: kind),
                        hasSignal: hasSignal(for: kind),
                        isSelected: selectedKind == kind || (selectedKind == nil && activeKind == kind)
                    ) {
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                        selectedKind = (selectedKind == kind) ? nil : kind
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func liveCount(for kind: DeveloperActivityKind) -> Int {
        switch kind {
        case .docker:
            let runningContainers = service.containers.filter(\.isRunning).count
            if runningContainers > 0 { return runningContainers }
            return service.activities.filter { $0.kind == .docker && $0.state == .running }.count
        case .git:
            return service.gitSnapshot?.changedFiles ?? 0
        default:
            return service.activities.filter { $0.kind == kind && $0.state == .running }.count
        }
    }

    private func hasSignal(for kind: DeveloperActivityKind) -> Bool {
        if liveCount(for: kind) > 0 { return true }
        if kind == .git, service.gitSnapshot != nil { return true }
        return false
    }

    // MARK: - Right Stage Header

    private var stageHeader: some View {
        HStack(spacing: 6) {
            ActivityStateDot(state: headerState)

            Text(activeKind.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)

            Text("· \(headerStatusSummary)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.notchMuted)
                .lineLimit(1)

            Spacer(minLength: 6)

            Button {
                service.refresh()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 8.5, weight: .semibold))
                    Text(service.isRefreshing ? "Syncing" : "Refresh")
                        .font(.system(size: 9.5, weight: .medium))
                }
                .foregroundStyle(
                    service.isRefreshing
                        ? Color.white.opacity(0.38)
                        : (isRefreshHovered ? .white : Color.notchMuted)
                )
                .padding(.horizontal, 7)
                .frame(height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.white.opacity(isRefreshHovered ? 0.1 : 0.045))
                )
                .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            .buttonStyle(NotchPressButtonStyle())
            .onHover { isRefreshHovered = $0 }
            .disabled(service.isRefreshing)
            .help("Refresh developer activity")
            .accessibilityLabel("Refresh developer activity")
        }
    }

    private var headerState: DeveloperActivityState {
        if activeKind == .docker, !service.containers.isEmpty {
            return service.containers.contains(where: \.isRunning) ? .running : .idle
        }
        if activeKind == .git, let git = service.gitSnapshot {
            return git.changedFiles > 0 ? .running : .idle
        }
        if activeKind == .localhost, !serversList.isEmpty {
            return .running
        }
        return visibleActivity.state
    }

    private var headerStatusSummary: String {
        if activeKind == .docker, !service.containers.isEmpty {
            let running = service.containers.filter(\.isRunning).count
            return "\(running) of \(service.containers.count) running"
        }
        if activeKind == .git, let git = service.gitSnapshot {
            return git.branch
        }
        if activeKind == .localhost, serversList.count > 1 {
            return "\(serversList.count) servers running"
        }
        return visibleActivity.state.compactLabel.capitalized
    }

    // MARK: - Right Stage Body

    @ViewBuilder
    private var stageBody: some View {
        if activeKind == .docker, !service.containers.isEmpty {
            dockerInspector
        } else if activeKind == .git, let git = service.gitSnapshot {
            gitInspector(git)
        } else if activeKind == .localhost, serversList.count > 1 {
            serversInspector(serversList)
        } else if visibleActivity.state == .idle && visibleActivity.url == nil && visibleActivity.workingDirectory == nil && visibleActivity.processID == nil {
            idleInspector(for: activeKind)
        } else {
            singleActivityInspector(visibleActivity)
        }
    }

    // MARK: - Single Activity Inspector

    private func singleActivityInspector(_ activity: DeveloperActivity) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(activity.kind.tint.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(activity.kind.tint.opacity(0.22), lineWidth: 0.7)
                        )
                    if activity.kind == .localhost {
                        ServerFaviconImage(
                            faviconData: activity.faviconData,
                            fallbackTint: activity.kind.tint,
                            size: 20
                        )
                    } else {
                        Image(systemName: activity.kind.symbol)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(activity.kind.tint)
                    }
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(activity.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .tracking(-0.25)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(activity.subtitle)
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(activity.kind.tint)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)
            }

            if let detail = activity.detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(Color.notchMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.top, 6)
            }

            Spacer(minLength: 8)

            // Labeled Action Strip
            HStack(spacing: 6) {
                if activity.url != nil {
                    InspectorActionButton(title: "Open", icon: "arrow.up.right", emphasized: true) {
                        service.open(activity)
                    }
                    InspectorActionButton(title: "Copy", icon: "doc.on.doc") {
                        service.copyPrimaryValue(activity)
                        model.showMessage("URL copied")
                    }
                    .help("Copy URL")
                    .accessibilityLabel("Copy URL")
                }
                if activity.workingDirectory != nil {
                    InspectorActionButton(title: "Folder", icon: "folder") {
                        service.revealFolder(activity)
                    }
                    InspectorActionButton(title: "Logs", icon: "terminal") {
                        service.openLogs(for: activity)
                    }
                }
                Spacer(minLength: 4)
                if activity.processID != nil {
                    InspectorActionButton(title: "Stop", icon: "stop.fill", destructive: true) {
                        service.stop(activity)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Multi-Server Inspector

    private func serversInspector(_ servers: [DeveloperActivity]) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(Array(servers.enumerated()), id: \.element.id) { index, server in
                    if index > 0 {
                        Rectangle()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 1)
                    }

                    HStack(spacing: 8) {
                        ServerFaviconImage(
                            faviconData: server.faviconData,
                            fallbackTint: server.kind.tint,
                            size: 15
                        )
                        .frame(width: 22, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(server.kind.tint.opacity(0.12))
                        )

                        VStack(alignment: .leading, spacing: 1) {
                            Text(server.title)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(server.subtitle)
                                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                .foregroundStyle(server.kind.tint)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 4)

                        HStack(spacing: 4) {
                            if server.url != nil {
                                InspectorCompactIconButton(title: "Open \(server.title)", icon: "arrow.up.right") {
                                    service.open(server)
                                }
                                InspectorCompactIconButton(title: "Copy URL", icon: "doc.on.doc") {
                                    service.copyPrimaryValue(server)
                                    model.showMessage("URL copied")
                                }
                            }
                            if server.processID != nil {
                                InspectorCompactIconButton(title: "Stop \(server.title)", icon: "stop.fill", destructive: true) {
                                    service.stop(server)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 5)
                }
            }
        }
    }

    // MARK: - Docker Inspector

    private var dockerInspector: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(Array(service.containers.enumerated()), id: \.element.id) { index, container in
                    if index > 0 {
                        Rectangle()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 1)
                    }

                    HStack(spacing: 8) {
                        ActivityStateDot(state: container.isRunning ? .running : .idle)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(container.name)
                                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(container.status)
                                .font(.system(size: 9.5))
                                .foregroundStyle(Color.notchMuted)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 4)

                        HStack(spacing: 4) {
                            InspectorCompactIconButton(title: "View logs for \(container.name)", icon: "text.alignleft") {
                                service.openContainerLogs(container)
                            }
                            if container.isRunning {
                                InspectorCompactIconButton(title: "Stop \(container.name)", icon: "stop.fill", destructive: true) {
                                    service.stopContainer(container)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 5)
                }
            }
        }
    }

    // MARK: - Git Inspector

    private func gitInspector(_ git: GitActivitySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(git.repositoryName)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(git.commitSHA)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.notchMuted)
            }

            HStack(spacing: 8) {
                Label(git.branch, systemImage: "arrow.triangle.branch")
                    .foregroundStyle(DeveloperActivityKind.git.tint)

                Text("·")
                    .foregroundStyle(Color.white.opacity(0.25))

                Text(git.changedFiles == 0 ? "Clean tree" : "\(git.changedFiles) changed")
                    .foregroundStyle(git.changedFiles == 0 ? Color.notchMuted : .white.opacity(0.86))

                if git.ahead > 0 {
                    Label("\(git.ahead)", systemImage: "arrow.up")
                        .foregroundStyle(Color.notchAccent)
                }
                if git.behind > 0 {
                    Label("\(git.behind)", systemImage: "arrow.down")
                        .foregroundStyle(Color.notchBreak)
                }
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .lineLimit(1)
            .padding(.top, 4)

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                InspectorActionButton(title: "Pull", icon: "arrow.down") { service.pullGit() }
                InspectorActionButton(title: "Push", icon: "arrow.up") { service.pushGit() }
                InspectorActionButton(title: "SHA", icon: "doc.on.doc") {
                    service.copyCommitSHA()
                    model.showMessage("Commit SHA copied")
                }
                if git.remoteURL != nil {
                    InspectorActionButton(title: "Remote", icon: "arrow.up.right") { service.openGitRemote() }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Idle / Empty Inspector

    private func idleInspector(for kind: DeveloperActivityKind) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Spacer(minLength: 2)

            Text(kind.idleHeadline)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))

            Text(kind.emptyDescription)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(Color.notchMuted)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 6)

            InspectorActionButton(title: service.isRefreshing ? "Scanning…" : "Scan now", icon: "arrow.clockwise") {
                service.refresh()
            }
            .disabled(service.isRefreshing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Subcomponents

private struct ChannelRailItem: View {
    let kind: DeveloperActivityKind
    let badgeCount: Int
    let hasSignal: Bool
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: kind.symbol)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(isSelected || hasSignal ? kind.tint : Color.notchMuted)
                    .frame(width: 13)

                Text(kind.title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? .white : (isHovering ? .white.opacity(0.88) : Color.notchMuted))
                    .lineLimit(1)

                Spacer(minLength: 2)

                if badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(kind.tint)
                } else if hasSignal {
                    Circle()
                        .fill(kind.tint)
                        .frame(width: 4.5, height: 4.5)
                        .accessibilityHidden(true)
                }
            }
            .padding(.leading, 8)
            .padding(.trailing, 7)
            .frame(height: 20)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.09) : Color.white.opacity(isHovering ? 0.05 : 0.0))
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(kind.tint)
                        .frame(width: 2, height: 11)
                        .padding(.leading, 1.5)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .help(kind.title)
        .accessibilityLabel(badgeCount > 0 ? "\(kind.title), \(badgeCount) active" : kind.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct InspectorActionButton: View {
    let title: String
    let icon: String
    var emphasized: Bool = false
    var destructive: Bool = false
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4.5) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, 9)
            .frame(height: 25)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(background)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(NotchPressButtonStyle())
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .accessibilityLabel(title)
    }

    private var foreground: Color {
        if emphasized { return .black }
        if destructive { return isHovering ? Color.notchDanger : Color.notchMuted }
        return isHovering ? .white : .white.opacity(0.86)
    }

    private var background: Color {
        if emphasized { return Color.notchAccent.opacity(isHovering ? 1.0 : 0.92) }
        if destructive { return isHovering ? Color.notchDanger.opacity(0.16) : Color.white.opacity(0.06) }
        return Color.white.opacity(isHovering ? 0.13 : 0.07)
    }
}

private struct InspectorCompactIconButton: View {
    let title: String
    let icon: String
    var destructive: Bool = false
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(destructive ? (isHovering ? Color.notchDanger : Color.notchMuted) : (isHovering ? .white : .white.opacity(0.84)))
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(
                            destructive && isHovering
                                ? Color.notchDanger.opacity(0.16)
                                : Color.white.opacity(isHovering ? 0.13 : 0.065)
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(NotchPressButtonStyle())
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .help(title)
        .accessibilityLabel(title)
    }
}

private extension DeveloperActivityKind {
    var idleHeadline: String {
        switch self {
        case .localhost: return "No dev servers running"
        case .build: return "No active builds"
        case .docker: return "No containers detected"
        case .git: return "No active repository"
        case .deployment: return "No deployments running"
        case .terminal: return "No long-running tasks"
        }
    }

    var emptyDescription: String {
        switch self {
        case .localhost: return "Start a local server (Vite, Next.js, Swift, etc.) to monitor and open it here."
        case .build: return "Active Xcode, Swift, or Node build processes appear here while running."
        case .docker: return "Running Docker containers appear here when the daemon is active."
        case .git: return "Git branch, changes, and commit tools follow your active project directory."
        case .deployment: return "Supported deployment CLIs appear automatically while publishing."
        case .terminal: return "Long-running package scripts and watch tasks appear here."
        }
    }
}
