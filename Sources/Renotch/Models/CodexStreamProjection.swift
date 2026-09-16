import Foundation

/// Retains only status, questions and their answer references. Reasoning, tool
/// output, prompts and assistant prose are discarded before storing a snapshot.
struct CodexStreamProjection {
    private(set) var state: [String: Any] = [:]
    private(set) var revision: Int?

    mutating func ingest(_ change: [String: Any]) -> Bool {
        guard let next = change["revision"] as? Int else { return false }
        if change["type"] as? String == "snapshot", let value = change["conversationState"] as? [String: Any] {
            state = Self.sanitize(value)
            revision = next
            return true
        }
        guard change["type"] as? String == "patches", let base = change["baseRevision"] as? Int,
              base == revision, let patches = change["patches"] as? [[String: Any]] else { return false }
        var value: Any = state
        for patch in patches {
            guard let path = patch["path"] as? [Any], let op = patch["op"] as? String,
                  ["add", "replace", "remove"].contains(op) else { return false }
            if !Self.relevant(path) { continue }
            guard let result = Self.applying(value, path: path[...], op: op, replacement: patch["value"] ?? NSNull()) else { return false }
            value = result
        }
        state = Self.sanitize(value as? [String: Any] ?? [:])
        revision = next
        return true
    }

    var task: CodexTask? {
        guard let id = state["id"] as? String, UUID(uuidString: id) != nil,
              let runtime = state["threadRuntimeStatus"] as? [String: Any],
              let runtimeType = runtime["type"] as? String else { return nil }
        var turns = state["turns"] as? [[String: Any]] ?? []
        let history = (state["turnHistory"] as? [String: Any])?["history"] as? [String: Any]
        turns += Array((history?["entitiesByKey"] as? [String: [String: Any]] ?? [:]).values)
        turns.sort { Self.timestamp($0["turnStartedAtMs"]) < Self.timestamp($1["turnStartedAtMs"]) }
        let latest = turns.last ?? [:]
        let flags = runtime["activeFlags"] as? [String] ?? []
        let requests = state["requests"] as? [[String: Any]] ?? []
        var answered = Set<String>()
        for turn in turns {
            for item in turn["items"] as? [Any] ?? [] {
                guard let item = item as? [String: Any], let type = item["type"] as? String,
                      type == "userMessage" || (type == "steeringUserMessage" && item["status"] as? String == "accepted") else { continue }
                for content in item[type == "userMessage" ? "content" : "input"] as? [[String: Any]] ?? [] {
                    answered.formUnion(Self.answerReferences(content["text"] as? String ?? ""))
                }
            }
        }
        var questions: [CodexQuestion] = []
        for item in latest["items"] as? [Any] ?? [] {
            guard let item = item as? [String: Any], let callID = item["id"] as? String else { continue }
            for (index, question) in (item["questions"] as? [[String: Any]] ?? []).enumerated() {
                let key = "\(callID):\(index)"
                guard !answered.contains(key), let title = question["title"] as? String, !title.isEmpty else { continue }
                questions.append(CodexQuestion(id: key, title: title, options: question["options"] as? [String] ?? []))
            }
        }
        for request in requests where (request["method"] as? String ?? "").lowercased().contains("requestuserinput") {
            let params = request["params"] as? [String: Any] ?? [:]
            for (index, question) in (params["questions"] as? [[String: Any]] ?? []).enumerated() {
                if let title = question["question"] as? String ?? question["title"] as? String {
                    questions.append(CodexQuestion(id: "request:\(request["id"] ?? ""): \(index)", title: title,
                        options: (question["options"] as? [[String: Any]] ?? []).compactMap { $0["label"] as? String }))
                }
            }
        }
        let approval = flags.contains("waitingOnApproval") || requests.contains {
            let method = ($0["method"] as? String ?? "").lowercased()
            return method.contains("approval") || method.contains("elicitation")
        }
        // Cancelled and failed turns must not leave stale question badges.
        if ["interrupted", "failed"].contains(latest["status"] as? String ?? "") || runtimeType == "systemError" {
            questions = []
        }
        let status: CodexTaskStatus
        if !questions.isEmpty || flags.contains("waitingOnUserInput") { status = .waitingAnswer }
        else if approval { status = .waitingApproval }
        else if runtimeType == "active" { status = .running }
        else if runtimeType == "systemError" || latest["status"] as? String == "failed" { status = .failed }
        else if latest["status"] as? String == "interrupted" { status = .interrupted }
        else if runtimeType == "idle" && latest["status"] as? String == "completed" { status = .completed }
        else { status = .unknown }
        let started = Self.timestamp(latest["turnStartedAtMs"])
        let duration = (latest["durationMs"] as? Double ?? 0) / 1000
        let updated = max(Self.timestamp(state["updatedAt"]), started + duration)
        return CodexTask(id: id, title: state["title"] as? String ?? "Codex 任务", cwd: state["cwd"] as? String ?? "",
            turnID: latest["turnId"] as? String ?? "", status: status,
            startedAt: Date(timeIntervalSince1970: started), updatedAt: Date(timeIntervalSince1970: updated),
            questions: questions, continuesInBackground: runtimeType == "active" && flags.isEmpty && !questions.isEmpty)
    }

    private static func timestamp(_ value: Any?) -> Double {
        let number = value as? Double ?? 0
        return number > 100_000_000_000 ? number / 1000 : number
    }

    static func answerReferences(_ text: String) -> Set<String> {
        guard let start = text.range(of: "<send_user_message_question_reply>"),
              let end = text.range(of: "</send_user_message_question_reply>", range: start.upperBound..<text.endIndex),
              let data = String(text[start.upperBound..<end.lowerBound]).data(using: .utf8),
              let value = try? JSONSerialization.jsonObject(with: data) else { return [] }
        let replies = value as? [[String: Any]] ?? (value as? [String: Any]).map { [$0] } ?? []
        return Set(replies.compactMap {
            guard let encoded = $0["questionItemId"] as? String, let data = encoded.data(using: .utf8),
                  let parts = try? JSONSerialization.jsonObject(with: data) as? [Any], parts.count >= 3,
                  let call = parts[1] as? String, let index = parts[2] as? Int else { return nil }
            return "\(call):\(index)"
        })
    }

    private static func sanitize(_ value: [String: Any]) -> [String: Any] {
        var result = value.filter { ["id", "title", "cwd", "updatedAt", "threadRuntimeStatus"].contains($0.key) }
        result["requests"] = (value["requests"] as? [[String: Any]] ?? []).map { request in
            var r = request.filter { ["id", "method"].contains($0.key) }
            r["params"] = (request["params"] as? [String: Any] ?? [:]).filter { $0.key == "questions" }
            return r
        }
        result["turns"] = (value["turns"] as? [[String: Any]] ?? []).map(sanitizeTurn)
        let history = (value["turnHistory"] as? [String: Any])?["history"] as? [String: Any] ?? [:]
        let entities = history["entitiesByKey"] as? [String: [String: Any]] ?? [:]
        result["turnHistory"] = ["history": ["entitiesByKey": entities.mapValues(sanitizeTurn)]]
        return result
    }

    private static func sanitizeTurn(_ turn: [String: Any]) -> [String: Any] {
        var result = turn.filter { ["turnId", "status", "turnStartedAtMs", "durationMs"].contains($0.key) }
        let items: [Any] = turn["items"] as? [Any] ?? []
        result["items"] = items.map { (value: Any) -> Any in
            guard let item = value as? [String: Any], let type = item["type"] as? String else { return NSNull() }
            if type == "agentMessage" { return item.filter { ["id", "type", "questions"].contains($0.key) } }
            if type == "userMessage" || type == "steeringUserMessage" {
                let field = type == "userMessage" ? "content" : "input"
                let content = (item[field] as? [[String: Any]] ?? []).map { part -> [String: Any] in
                    let text = part["text"] as? String ?? ""
                    return ["text": text.contains("<send_user_message_question_reply>") ? text : ""]
                }
                return ["id": item["id"] ?? "", "type": type, "status": item["status"] ?? "", field: content]
            }
            return NSNull()
        }
        return result
    }

    private static func relevant(_ path: [Any]) -> Bool {
        guard let root = path.first as? String else { return path.isEmpty }
        if ["id", "title", "cwd", "updatedAt", "threadRuntimeStatus", "requests"].contains(root) { return true }
        guard root == "turns" || root == "turnHistory" else { return false }
        let keys = path.compactMap { $0 as? String }
        if keys.contains("items"), let i = keys.firstIndex(of: "items"), keys.count > i + 1 {
            return ["id", "type", "status", "questions", "content", "input"].contains(keys[i + 1])
        }
        if let last = keys.last, ["params", "hookRuns", "error", "diff", "localMetadata"].contains(last) { return false }
        return true
    }

    private static func applying(_ original: Any, path: ArraySlice<Any>, op: String, replacement: Any) -> Any? {
        guard let head = path.first else { return op == "remove" ? NSNull() : replacement }
        let rest = path.dropFirst()
        if let key = head as? String {
            var dict = original as? [String: Any] ?? [:]
            if rest.isEmpty && op == "remove" { dict.removeValue(forKey: key) }
            else {
                guard let child = applying(dict[key] ?? NSNull(), path: rest, op: op, replacement: replacement) else { return nil }
                dict[key] = child
            }
            return dict
        }
        if let index = head as? Int {
            var array = original as? [Any] ?? []
            guard index >= 0 && index <= array.count else { return nil }
            if rest.isEmpty {
                if op == "add" { array.insert(replacement, at: index) }
                else if index < array.count {
                    if op == "remove" { array.remove(at: index) } else { array[index] = replacement }
                } else { return nil }
            } else {
                guard index < array.count, let child = applying(array[index], path: rest, op: op, replacement: replacement) else { return nil }
                array[index] = child
            }
            return array
        }
        return nil
    }
}
