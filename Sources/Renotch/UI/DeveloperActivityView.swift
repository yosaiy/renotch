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
        if let selectedKind {
            return DeveloperActivity(
                id: "developer-\(selectedKind.rawValue)-idle",
                kind: selectedKind,
                title: selectedKind.title,
                subtitle: "暂无进行中的\(selectedKind.title)任务",
                state: .idle,
                detail: selectedKind.emptyDescription
            )
        }
        return service.primaryActivity
    }

    private var serversList: [DeveloperActivity] {
        service.activities.filter { $0.kind == .localhost && $0.state == .running }
    }

    var body: some View {
        VStack(spacing: 10) {
            activityRail

            if selectedKind == .docker, !service.containers.isEmpty {
                dockerDetail
            } else if selectedKind == .git, let git = service.gitSnapshot {
                gitDetail(git)
            } else if (selectedKind == .localhost || selectedKind == nil), serversList.count > 1 {
                serversGrid(serversList)
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
                let isSelected = selectedKind == kind
                Button {
                    selectedKind = isSelected ? nil : kind
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: kind.symbol)
                            .frame(width: 12)
                        if isSelected {
                            Text(kind.title)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .transition(.move(edge: .leading).combined(with: .opacity))
                        }
                        if count > 0 {
                            Text("\(count)")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(kind.tint)
                        }
                    }
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(isSelected ? .white : Color.notchMuted)
                    .padding(.horizontal, isSelected ? 8 : 6)
                    .frame(height: 25)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(isSelected ? kind.tint.opacity(0.17) : Color.white.opacity(0.045))
                    )
                    .overlay(alignment: .bottom) {
                        if isSelected {
                            Capsule()
                                .fill(kind.tint)
                                .frame(width: 16, height: 1.5)
                                .offset(y: 1)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help(kind.title)
                .accessibilityLabel(kind.title)
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
            .help("刷新开发活动")
        }
        .animation(.easeOut(duration: 0.18), value: selectedKind)
    }

    private func activityDetail(_ activity: DeveloperActivity) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(activity.kind.tint.opacity(0.11))
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(activity.kind.tint.opacity(0.14), lineWidth: 1)
                    if activity.kind == .localhost {
                        ServerFaviconImage(
                            faviconData: activity.faviconData,
                            fallbackTint: activity.kind.tint,
                            size: 32
                        )
                    } else {
                        Image(systemName: activity.kind.symbol)
                            .font(.system(size: 21, weight: .medium))
                            .foregroundStyle(activity.kind.tint)
                    }
                }
                .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(activity.title)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .tracking(-0.35)
                            .lineLimit(1)
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

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                ActivityStateDot(state: activity.state)
                Text(activity.state.compactLabel.capitalized)
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(activity.state.tint)

                Spacer(minLength: 8)

                activityActions(activity)
            }
            .frame(minHeight: 28)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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
                ActivityIconButton(title: "打开", icon: "arrow.up.right") { service.open(activity) }
                ActivityIconButton(title: "复制链接", icon: "doc.on.doc") {
                    service.copyPrimaryValue(activity)
                    model.showMessage("URL copied")
                }
            }
            if activity.workingDirectory != nil {
                ActivityIconButton(title: "打开文件夹", icon: "folder") { service.revealFolder(activity) }
                ActivityIconButton(title: "打开终端", icon: "terminal") { service.openLogs(for: activity) }
            }
            if activity.processID != nil {
                ActivityIconButton(title: "停止", icon: "stop.fill", tint: .red) { service.stop(activity) }
            }
        }
    }

    private func serversGrid(_ servers: [DeveloperActivity]) -> some View {
        HStack(spacing: 8) {
            ForEach(servers.prefix(3)) { server in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(server.kind.tint.opacity(0.12))
                            ServerFaviconImage(
                                faviconData: server.faviconData,
                                fallbackTint: server.kind.tint,
                                size: 18
                            )
                        }
                        .frame(width: 26, height: 26)

                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 5) {
                                Text(server.title)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .lineLimit(1)
                                ActivityStateDot(state: server.state)
                            }
                            Text(server.subtitle)
                                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                .foregroundStyle(server.kind.tint)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)
                    }

                    if let detail = server.detail, !detail.isEmpty {
                        Text(detail)
                            .font(.system(size: 8.5))
                            .foregroundStyle(Color.notchMuted)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Spacer(minLength: 0)

                    HStack(spacing: 5) {
                        if server.url != nil {
                            ActivityIconButton(title: "打开", icon: "arrow.up.right") { service.open(server) }
                            ActivityIconButton(title: "复制链接", icon: "doc.on.doc") {
                                service.copyPrimaryValue(server)
                                model.showMessage("URL copied")
                            }
                        }
                        if server.workingDirectory != nil {
                            ActivityIconButton(title: "打开文件夹", icon: "folder") { service.revealFolder(server) }
                            ActivityIconButton(title: "打开终端", icon: "terminal") { service.openLogs(for: server) }
                        }
                        if server.processID != nil {
                            ActivityIconButton(title: "停止", icon: "stop.fill", tint: .red) { service.stop(server) }
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.045))
                )
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
                        ActivityIconButton(title: "日志", icon: "text.alignleft") {
                            service.openContainerLogs(container)
                        }
                        if container.isRunning {
                            ActivityIconButton(title: "停止", icon: "stop.fill", tint: .red) {
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
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(git.repositoryName)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Label(git.branch, systemImage: "arrow.triangle.branch")
                        Text("\(git.changedFiles) 项改动")
                        Text(git.commitSHA)
                    }
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.notchMuted)
                }
                Spacer(minLength: 8)
                ActivityStateDot(state: git.changedFiles == 0 ? .idle : .running)
            }

            HStack(spacing: 6) {
                if git.ahead == 0, git.behind == 0 {
                    Text("已是最新")
                        .foregroundStyle(Color.notchMuted)
                } else {
                    if git.ahead > 0 { Label("\(git.ahead)", systemImage: "arrow.up") }
                    if git.behind > 0 { Label("\(git.behind)", systemImage: "arrow.down") }
                }

                Spacer(minLength: 8)

                ActivityIconButton(title: "拉取", icon: "arrow.down") { service.pullGit() }
                ActivityIconButton(title: "推送", icon: "arrow.up") { service.pushGit() }
                ActivityIconButton(title: "复制提交编号", icon: "number") {
                    service.copyCommitSHA()
                    model.showMessage("提交编号已复制")
                }
                if git.remoteURL != nil {
                    ActivityIconButton(title: "打开远程仓库", icon: "arrow.up.right.square") { service.openGitRemote() }
                }
            }
            .font(.system(size: 8.5, weight: .medium, design: .rounded))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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
        case .localhost: return "启动本地开发服务后，会显示在这里。"
        case .build: return "运行构建命令时，会自动显示在这里。"
        case .docker: return "Docker 启动后，会显示容器状态。"
        case .git: return "显示当前项目目录的 Git 状态。"
        case .deployment: return "执行受支持的部署命令时，会显示在这里。"
        case .terminal: return "安装依赖等长时间运行的任务会显示在这里。"
        }
    }
}
