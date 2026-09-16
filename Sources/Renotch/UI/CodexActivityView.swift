import SwiftUI

extension CodexTaskStatus {
    var tint: Color {
        switch self {
        case .waitingAnswer: return .orange
        case .waitingApproval: return .yellow
        case .running: return .cyan
        case .completed: return .green
        case .failed: return .red
        case .interrupted, .unknown: return .gray
        }
    }
    var symbol: String {
        switch self {
        case .waitingAnswer: return "bubble.left.and.bubble.right.fill"
        case .waitingApproval: return "hand.raised.fill"
        case .running: return "circle.dotted"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle.fill"
        case .interrupted, .unknown: return "pause.circle"
        }
    }
}

struct CodexActivityView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var service: CodexActivityService
    @State private var filter = 0
    @State private var showsFinished = false

    private var waiting: [CodexTask] { service.tasks.filter { $0.status.needsAttention } }
    private var running: [CodexTask] { service.tasks.filter { $0.status == .running } }
    private var finished: [CodexTask] { service.tasks.filter { !$0.status.isActive } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(service.isPreview ? "Codex 任务 · 示例预览" : "Codex 任务").font(.system(size: 18, weight: .bold))
                    Label(service.isConnected ? "全部本机任务 · 实时更新" : "等待 Codex 连接",
                          systemImage: service.isConnected ? "circle.fill" : "circle.dashed")
                        .font(.system(size: 10)).foregroundStyle(service.isConnected ? Color.green : .secondary)
                }
                Spacer()
                metric("执行中", count: running.count, color: .cyan)
                metric("待你处理", count: waiting.count, color: .orange)
            }
            if model.settings.codexEnabled != false && model.settings.codexShowUsage != false {
                CodexUsageView(service: model.codexUsage)
            }
            HStack(spacing: 6) {
                filterButton("全部", value: 0, count: service.activeTasks.count)
                filterButton("待你处理", value: 1, count: waiting.count)
                filterButton("执行中", value: 2, count: running.count)
                Spacer()
                if !finished.isEmpty {
                    Button(showsFinished ? "收起已结束" : "已结束 \(finished.count)") { showsFinished.toggle() }
                        .buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            if !service.isConnected {
                emptyState("尚未连接", detail: model.settings.codexEnabled == false ? "请在设置中开启 Codex 任务状态。" : service.connectionMessage ?? "打开 Codex 后，任务状态会自动显示。")
            } else if service.activeTasks.isEmpty && (!showsFinished || finished.isEmpty) {
                emptyState("目前没有执行中的任务", detail: "开始一个 Codex 任务后会自动出现在这里。需要你回答的问题会置顶显示。")
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: 9) {
                        if filter != 2 { taskGroup("待你处理", tasks: waiting, color: .orange) }
                        if filter != 1 { taskGroup("执行中", tasks: running, color: .cyan) }
                        if showsFinished { taskGroup("最近结束", tasks: finished, color: .secondary) }
                        if (filter == 1 && waiting.isEmpty) || (filter == 2 && running.isEmpty) {
                            Text(filter == 1 ? "没有待回答或待批准的任务" : "没有执行中的任务")
                                .font(.system(size: 12)).foregroundStyle(.secondary).padding(.vertical, 24)
                        }
                    }.padding(.trailing, 5)
                }
                .id(filter)
            }
        }
        .padding(.horizontal, 5).padding(.top, 12).padding(.bottom, 5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func metric(_ title: String, count: Int, color: Color) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("\(count)").font(.system(size: 23, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(color)
            Text(title).font(.system(size: 9)).foregroundStyle(.secondary)
        }.frame(minWidth: 56)
    }

    private func filterButton(_ title: String, value: Int, count: Int) -> some View {
        Button { filter = value } label: {
            Text("\(title) \(count)").font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(filter == value ? Color.white.opacity(0.16) : Color.white.opacity(0.04)))
        }.buttonStyle(.plain)
    }

    @ViewBuilder
    private func taskGroup(_ title: String, tasks: [CodexTask], color: Color) -> some View {
        if !tasks.isEmpty {
            Text("\(title) · \(tasks.count)").font(.system(size: 10, weight: .semibold)).foregroundStyle(color).padding(.top, 4)
            ForEach(tasks) { task in
                CodexTaskRow(task: task, showsQuestions: model.settings.codexShowQuestions != false) { service.open(task) }
            }
        }
    }

    private func emptyState(_ title: String, detail: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.text.bubble.right").font(.system(size: 28)).foregroundStyle(.secondary)
            Text(title).font(.system(size: 14, weight: .semibold))
            Text(detail).font(.system(size: 11)).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 340)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CodexTaskRow: View {
    let task: CodexTask
    let showsQuestions: Bool
    let open: () -> Void
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: task.status.symbol).font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(task.status.tint).frame(width: 20).padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title).font(.system(size: 12, weight: .semibold)).lineLimit(expanded ? nil : 2)
                    HStack(spacing: 6) {
                        Text(task.status.title).foregroundStyle(task.status.tint)
                        Text("·").foregroundStyle(.secondary)
                        Text(task.projectName).lineLimit(1).truncationMode(.middle).foregroundStyle(.secondary).help(task.cwd)
                        if task.continuesInBackground { Text("· 后台仍在执行").foregroundStyle(.secondary) }
                    }.font(.system(size: 9.5))
                }
                Spacer(minLength: 4)
                Button(task.status == .waitingAnswer ? "去回答" : task.status == .waitingApproval ? "去确认" : "打开任务", action: open)
                    .buttonStyle(.plain).font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 7).fill(task.status.tint.opacity(0.16)))
                    .foregroundStyle(task.status.tint)
                    .accessibilityLabel("\(task.status == .waitingAnswer ? "去回答" : task.status == .waitingApproval ? "去确认" : "打开任务")：\(task.title)")
                    .accessibilityIdentifier("codex-open-\(task.id)")
            }
            if showsQuestions && !task.questions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(task.questions) { question in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(question.title).font(.system(size: 11)).lineLimit(expanded ? nil : 3).fixedSize(horizontal: false, vertical: true)
                            if expanded {
                                ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                                    Text("\(index + 1). \(option)").font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    Button(expanded ? "收起问题" : "查看完整问题与选项") { expanded.toggle() }
                        .buttonStyle(.plain).font(.system(size: 9.5)).foregroundStyle(.orange)
                        .accessibilityIdentifier("codex-question-\(task.id)")
                }
                .padding(9).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.07)))
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 11).fill(Color.white.opacity(0.045)))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(task.status.needsAttention ? task.status.tint.opacity(0.25) : .white.opacity(0.07), lineWidth: 0.7))
    }
}

struct CompactCodexView: View {
    @ObservedObject var service: CodexActivityService
    @ObservedObject var usage: CodexUsageService

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "terminal.fill").font(.system(size: 15)).foregroundStyle(.cyan)
            VStack(alignment: .leading, spacing: 2) {
                Text("Codex").font(.system(size: 11, weight: .bold))
                Text("\(service.activeTasks.count) 项任务").font(.system(size: 9)).foregroundStyle(.secondary).monospacedDigit()
            }
            Spacer(minLength: 170)
            VStack(alignment: .trailing, spacing: 2) {
                if service.attentionCount > 0 {
                    Label("\(service.attentionCount) 待处理", systemImage: "bubble.left.fill")
                        .foregroundStyle(.orange).font(.system(size: 10, weight: .semibold))
                    Text(service.answerCount > 0 ? "\(service.answerCount) 项待你回答" : "等待你批准")
                        .font(.system(size: 9)).foregroundStyle(.secondary)
                } else {
                    Text(service.runningCount > 0 ? "\(service.runningCount) 执行中" : "任务已结束")
                        .font(.system(size: 10, weight: .semibold)).foregroundStyle(service.runningCount > 0 ? .cyan : .green)
                    Text(usage.compactSummary ?? "展开查看").font(.system(size: 9)).foregroundStyle(.secondary)
                }
            }.fixedSize()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Codex，\(service.runningCount) 项执行中，\(service.attentionCount) 项待你处理")
    }
}
