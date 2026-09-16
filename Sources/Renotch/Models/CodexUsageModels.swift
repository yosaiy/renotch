import Foundation

struct CodexUsageWindow: Equatable, Identifiable {
    let id: String
    let remainingPercent: Double?
    let minutes: Int?
    let resetsAt: Date?

    var title: String {
        guard let minutes else { return id == "primary" ? "周期一" : "周期二" }
        if minutes == 10080 { return "每周" }
        if minutes % 60 == 0 { return "\(minutes / 60) 小时" }
        return "\(minutes) 分钟"
    }
    var remainingText: String {
        guard let remainingPercent else { return "暂不可用" }
        return "\(Int(remainingPercent.rounded()))%"
    }
}

struct CodexUsageBucket: Equatable, Identifiable {
    let id: String
    let title: String
    let windows: [CodexUsageWindow]
}

struct CodexUsageSnapshot: Equatable {
    let buckets: [CodexUsageBucket]
    let fetchedAt: Date
    var main: CodexUsageBucket? { buckets.first { $0.id == "codex" } }

    static func parse(_ result: [String: Any], now: Date = Date()) -> CodexUsageSnapshot? {
        var values = result["rateLimitsByLimitId"] as? [String: [String: Any]] ?? [:]
        if let legacy = result["rateLimits"] as? [String: Any] {
            let id = legacy["limitId"] as? String ?? "codex"
            if values[id] == nil { values[id] = legacy }
        }
        guard !values.isEmpty else { return nil }
        let buckets = values.map { id, value in
            CodexUsageBucket(id: id, title: id == "codex" ? "Codex 通用额度" : value["limitName"] as? String ?? "其他模型额度",
                windows: ["primary", "secondary"].compactMap { key in
                    guard let window = value[key] as? [String: Any] else { return nil }
                    let used = window["usedPercent"] as? Double
                    let remaining = used.flatMap { $0.isFinite ? min(100, max(0, 100 - $0)) : nil }
                    let minutes = window["windowDurationMins"] as? Int
                    let reset = window["resetsAt"] as? Double
                    return CodexUsageWindow(id: key, remainingPercent: remaining,
                        minutes: minutes.flatMap { $0 > 0 ? $0 : nil },
                        resetsAt: reset.flatMap { $0.isFinite && $0 > 0 ? Date(timeIntervalSince1970: $0) : nil })
                })
        }.sorted { lhs, rhs in
            if lhs.id == "codex" { return rhs.id != "codex" }
            if rhs.id == "codex" { return false }
            return lhs.id < rhs.id
        }
        return CodexUsageSnapshot(buckets: buckets, fetchedAt: now)
    }
}
