import SwiftUI

struct DeveloperActivityView: View {
    @ObservedObject var service: DeveloperActivityService
    @EnvironmentObject private var model: AppModel
    @State private var selectedKind: DeveloperActivityKind?

    private var visibleActivity: DeveloperActivity {
        if let selectedKind,
           let activity = service.activities.first(where: { $0.kind == selectedKind }) {
            return activity
        }
        return service.primaryActivity
    }

    var body: some View {
        VStack(spacing: 10) {
            activityRail

            if selectedKind == .docker, !service.containers.isEmpty {
                dockerDetail
            } else if selectedKind == .git, let git = service.gitSnapshot {
                gitDetail(git)
            } else {
                activityDetail(visibleActivity)
            }
        }
        .padding(.top, 10)
        .animation(.easeOut(duration: 0.18), value: selectedKind)
        .animation(.easeOut(duration: 0.18), value: service.primaryActivity.id)
    }

    private var activityRail: some View {
        HStack(spacing: 6) {
            ForEach(DeveloperActivityKind.allCases) { kind in
                let count = service.activities.filter { $0.kind == kind && $0.state == .running }.count
                Button {
                    selectedKind = selectedKind == kind ? nil : kind
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: kind.symbol)
                        Text(kind.title)
                        if count > 0 {
                            Text("\(count)")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(kind.tint)
                        }
                    }
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(selectedKind == kind ? .white : Color.notchMuted)
                    .padding(.horizontal, 9)
                    .frame(height: 25)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(selectedKind == kind ? kind.tint.opacity(0.17) : Color.white.opacity(0.045))
                    )
                    .overlay(alignment: .bottom) {
                        if selectedKind == kind {
                            Capsule()
                                .fill(kind.tint)
                                .frame(width: 16, height: 1.5)
                                .offset(y: 1)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            Button { service.refresh() } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.notchMuted)
                    .frame(width: 25, height: 25)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.045)))
            }
            .buttonStyle(.plain)
            .disabled(service.isRefreshing)
            .help("Refresh developer activity")
        }
    }

    private func activityDetail(_ activity: DeveloperActivity) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(activity.kind.tint.opacity(0.11))
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(activity.kind.tint.opacity(0.14), lineWidth: 1)
                if activity.kind == .localhost {
                    ServerFaviconImage(
                        faviconData: activity.faviconData,
                        fallbackTint: activity.kind.tint,
                        size: 38
                    )
                } else {
                    Image(systemName: activity.kind.symbol)
                        .font(.system(size: 25, weight: .medium))
                        .foregroundStyle(activity.kind.tint)
                }
            }
            .frame(width: 68, height: 68)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(activity.title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .tracking(-0.35)
                    ActivityStateDot(state: activity.state)
                }

                Text(activity.subtitle)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(activity.kind.tint)
                    .lineLimit(1)

                Text(activity.detail ?? activity.kind.emptyDescription)
                    .font(.system(size: 9.5, weight: .regular))
                    .foregroundStyle(Color.notchMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            activityActions(activity)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
    }

    @ViewBuilder
    private func activityActions(_ activity: DeveloperActivity) -> some View {
        HStack(spacing: 6) {
            if activity.url != nil {
                ActivityIconButton(title: "Open", icon: "arrow.up.right") { service.open(activity) }
                ActivityIconButton(title: "Copy URL", icon: "doc.on.doc") {
                    service.copyPrimaryValue(activity)
                    model.showMessage("URL copied")
                }
            }
            if activity.workingDirectory != nil {
                ActivityIconButton(title: "Open folder", icon: "folder") { service.revealFolder(activity) }
                ActivityIconButton(title: "Open terminal", icon: "terminal") { service.openLogs(for: activity) }
            }
            if activity.processID != nil {
                ActivityIconButton(title: "Stop", icon: "stop.fill", tint: .red) { service.stop(activity) }
            }
        }
    }

    private var dockerDetail: some View {
        HStack(spacing: 8) {
            ForEach(service.containers.prefix(3)) { container in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        ActivityStateDot(state: container.isRunning ? .running : .idle)
                        Text(container.name)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .lineLimit(1)
                    }
                    Text(container.status)
                        .font(.system(size: 9))
                        .foregroundStyle(Color.notchMuted)
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        ActivityIconButton(title: "Logs", icon: "text.alignleft") {
                            service.openContainerLogs(container)
                        }
                        if container.isRunning {
                            ActivityIconButton(title: "Stop", icon: "stop.fill", tint: .red) {
                                service.stopContainer(container)
                            }
                        }
                    }
                }
                .padding(11)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(RoundedRectangle(cornerRadius: 13).fill(Color.white.opacity(0.045)))
            }
        }
    }

    private func gitDetail(_ git: GitActivitySnapshot) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(git.repositoryName)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                HStack(spacing: 8) {
                    Label(git.branch, systemImage: "arrow.triangle.branch")
                    Text("\(git.changedFiles) changed")
                    Text(git.commitSHA)
                }
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.notchMuted)
            }
            Spacer()
            HStack(spacing: 6) {
                ActivityIconButton(title: "Pull", icon: "arrow.down") { service.pullGit() }
                ActivityIconButton(title: "Push", icon: "arrow.up") { service.pushGit() }
                ActivityIconButton(title: "Copy SHA", icon: "number") {
                    service.copyCommitSHA()
                    model.showMessage("Commit SHA copied")
                }
                if git.remoteURL != nil {
                    ActivityIconButton(title: "Open remote", icon: "arrow.up.right.square") { service.openGitRemote() }
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 15).fill(Color.white.opacity(0.045)))
    }
}

private struct ActivityIconButton: View {
    let title: String
    let icon: String
    var tint: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.075)))
                .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .help(title)
    }
}

private extension DeveloperActivityKind {
    var emptyDescription: String {
        switch self {
        case .localhost: return "Start a development server to see it here."
        case .build: return "Build commands appear automatically while they run."
        case .docker: return "Docker containers appear when the daemon is running."
        case .git: return "Git status follows the active project directory."
        case .deployment: return "Supported deployment CLIs appear while publishing."
        case .terminal: return "Long-running package tasks appear here."
        }
    }
}
