import AppKit
import Foundation

@MainActor
final class CodexActivityService: ObservableObject {
    @Published private(set) var tasks: [CodexTask] = []
    @Published private(set) var isConnected = false
    @Published private(set) var connectionMessage: String?
    private(set) var isPreview = false
    private var client: CodexIPCClient?
    private var allTasks: [CodexTask] = []
    private var retention: TimeInterval = 120
    private var enabled = true
    private var epoch = 0

    init(connect: Bool = true) {
        if connect { start() }
    }

    var activeTasks: [CodexTask] { tasks.filter { $0.status.isActive } }
    var attentionCount: Int { tasks.filter { $0.status.needsAttention }.count }
    var runningCount: Int { tasks.filter { $0.status == .running }.count }
    var answerCount: Int { tasks.filter { $0.status == .waitingAnswer }.count }
    var shouldPresent: Bool { enabled && isConnected && !tasks.isEmpty }

    func configure(enabled: Bool, retention: TimeInterval) {
        self.retention = retention
        if enabled != self.enabled {
            self.enabled = enabled
            enabled ? start() : pause()
        }
        publish()
    }

    func start() {
        guard enabled && client == nil else { return }
        epoch += 1
        let token = epoch
        let client = CodexIPCClient { [weak self] tasks, connected, message in
            Task { @MainActor [weak self] in
                guard let self, self.epoch == token else { return }
                self.allTasks = tasks
                self.isConnected = connected
                self.connectionMessage = message
                self.publish()
            }
        }
        self.client = client
        client.start()
    }

    func pause() {
        epoch += 1
        client?.stop(); client = nil
        allTasks = []; tasks = []; isConnected = false
    }

    func open(_ task: CodexTask) {
        guard let url = task.destination else { return }
        NSWorkspace.shared.open(url)
    }

    private func publish() {
        let now = Date()
        let visible = allTasks.filter {
            $0.status.isActive || ($0.status != .unknown && retention > 0 && now.timeIntervalSince($0.updatedAt) < retention)
        }
        let next = enabled && isConnected ? CodexTask.ordered(visible) : []
        if tasks != next { tasks = next }
    }

    #if DEBUG
    func showPreview() {
        pause()
        isPreview = true
        isConnected = true
        let now = Date()
        allTasks = (0..<14).map { index in
            let status: CodexTaskStatus = index < 2 ? .waitingAnswer : index == 2 ? .waitingApproval : index == 13 ? .completed : .running
            return CodexTask(id: String(format: "00000000-0000-4000-8000-%012d", index),
                title: index == 0 ? "车辆同步服务：修复跨天统计差异并核对多车辆历史数据回补范围，验证超长任务标题的换行效果" : index == 1 ? "质量报告导出：确认统计范围" : "并行开发示例任务 \(index + 1)",
                cwd: index % 2 == 0 ? "/示例/车辆同步服务" : "/示例/质量管理平台", turnID: "preview-\(index)", status: status,
                startedAt: now.addingTimeInterval(Double(index * 30 - 900)), updatedAt: now,
                questions: status == .waitingAnswer ? [CodexQuestion(id: "preview-question-\(index)",
                    title: index == 0 ? "历史数据应按哪个时间范围核对？选择后会用于所有车辆，并保留原始数据与差异明细，以便逐项核查处理结果。" : "报告需要包含哪些业务范围？",
                    options: ["最近三个月，包含全部车辆", "按指定日期范围核对，并导出差异明细"])] : [],
                continuesInBackground: index == 0)
        }
        publish()
    }
    #endif

    deinit { client?.stop() }
}
