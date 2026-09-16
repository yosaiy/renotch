import Foundation

enum CodexTaskStatus: String, Codable, Sendable {
    case running, waitingAnswer, waitingApproval, completed, failed, interrupted, unknown

    var title: String {
        switch self {
        case .running: return "执行中"
        case .waitingAnswer: return "待你回答"
        case .waitingApproval: return "待你批准"
        case .completed: return "已完成"
        case .failed: return "执行失败"
        case .interrupted: return "已中断"
        case .unknown: return "状态未知"
        }
    }
    var needsAttention: Bool { self == .waitingAnswer || self == .waitingApproval }
    var isActive: Bool { needsAttention || self == .running }
    var priority: Int {
        switch self {
        case .waitingAnswer: return 0
        case .waitingApproval: return 1
        case .running: return 2
        default: return 3
        }
    }
}

struct CodexQuestion: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let options: [String]
}

struct CodexTask: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let cwd: String
    let turnID: String
    let status: CodexTaskStatus
    let startedAt: Date
    let updatedAt: Date
    let questions: [CodexQuestion]
    let continuesInBackground: Bool

    var projectName: String {
        cwd.isEmpty ? "独立任务" : URL(fileURLWithPath: cwd).lastPathComponent
    }
    var destination: URL? {
        guard UUID(uuidString: id) != nil else { return nil }
        return URL(string: "codex://threads/\(id)")
    }

    static func ordered(_ tasks: [CodexTask]) -> [CodexTask] {
        tasks.sorted {
            if $0.status.priority != $1.status.priority { return $0.status.priority < $1.status.priority }
            if $0.status.isActive && $0.startedAt != $1.startedAt { return $0.startedAt < $1.startedAt }
            if !$0.status.isActive && $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            return $0.id < $1.id
        }
    }
}
