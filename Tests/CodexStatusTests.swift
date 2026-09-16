import Foundation

@main
struct CodexStatusTests {
    static func main() throws {
        if CommandLine.arguments.contains("--live") {
            let client = CodexIPCClient { tasks, connected, message in
                let summary: [String: Any] = ["connected": connected, "message": message ?? "", "tasks": tasks.map {
                    ["id": $0.id, "status": $0.status.rawValue, "questions": $0.questions.count] as [String: Any]
                }]
                if let data = try? JSONSerialization.data(withJSONObject: summary, options: .sortedKeys) {
                    print(String(decoding: data, as: UTF8.self))
                }
            }
            client.start()
            RunLoop.main.run(until: Date().addingTimeInterval(8))
            client.stop()
            return
        }
        var checks = 0
        func expect(_ condition: Bool, _ message: String) {
            checks += 1
            if !condition { fputs("FAIL: \(message)\n", stderr); exit(1) }
        }
        let id = "11111111-1111-4111-8111-111111111111"
        let now = Date().timeIntervalSince1970
        func state(id: String = id, items: [Any] = [], runtime: String = "active", flags: [String] = [], status: String = "inProgress") -> [String: Any] {
            ["id": id, "title": "并行任务测试", "cwd": "/tmp/project", "updatedAt": now,
             "threadRuntimeStatus": ["type": runtime, "activeFlags": flags], "requests": [],
             "turnHistory": ["history": ["entitiesByKey": ["turn-one": ["turnId": "turn-1", "turnStartedAtMs": now * 1000,
                    "status": status, "durationMs": 1200, "items": items]]]]]
        }
        func snapshot(_ value: [String: Any], revision: Int = 1) -> [String: Any] {
            ["type": "snapshot", "revision": revision, "conversationState": value]
        }
        let question: [String: Any] = ["type": "agentMessage", "id": "call-q", "questions": [
            ["title": "选择部署环境？", "options": ["测试", "生产"]],
            ["title": "选择验证范围？", "options": ["完整", "接口"]]], "text": "PRIVATE_ASSISTANT_TEXT"]
        var projection = CodexStreamProjection()
        expect(projection.ingest(snapshot(state(items: [question]))), "snapshot accepted")
        expect(projection.task?.status == .waitingAnswer, "async question takes priority over running")
        expect(projection.task?.questions.count == 2, "multiple questions retained")
        expect(projection.task?.continuesInBackground == true, "async question does not imply paused execution")
        let encodedID = "[\"request_user_input_async\",\"call-q\",0]"
        let replyData = try JSONSerialization.data(withJSONObject: [["questionItemId": encodedID, "answer": "测试"]])
        let reply = "<send_user_message_question_reply>\n\(String(decoding: replyData, as: UTF8.self))\n</send_user_message_question_reply>"
        let replyItem: [String: Any] = ["type": "userMessage", "id": "reply", "content": [["type": "text", "text": reply]]]
        let itemPath: [Any] = ["turnHistory", "history", "entitiesByKey", "turn-one", "items"]
        expect(projection.ingest(["type": "patches", "baseRevision": 1, "revision": 2,
                                 "patches": [["op": "add", "path": itemPath + [1], "value": replyItem]]]), "incremental answer accepted")
        expect(projection.task?.questions.count == 1, "answer clears only matching question")
        expect(projection.task?.questions.first?.id == "call-q:1", "unanswered sibling remains")
        var steeringReply: [String: Any] = ["type": "steeringUserMessage", "id": "steering", "input": [["text": reply]], "status": "pending"]
        var steeringProjection = CodexStreamProjection()
        expect(steeringProjection.ingest(snapshot(state(items: [question, steeringReply]))), "steering snapshot accepted")
        expect(steeringProjection.task?.questions.count == 2, "unaccepted steering does not clear questions")
        steeringReply["status"] = "accepted"
        expect(steeringProjection.ingest(snapshot(state(items: [question, steeringReply]))), "accepted steering snapshot")
        expect(steeringProjection.task?.questions.count == 1, "accepted steering clears matching question")
        expect(!projection.ingest(["type": "patches", "baseRevision": 0, "revision": 3, "patches": []]), "revision gap requires snapshot")
        expect(projection.revision == 2, "gap does not mutate state")
        let reply2Data = try JSONSerialization.data(withJSONObject: [["questionItemId": "[\"request_user_input_async\",\"call-q\",1]", "answer": "完整"]])
        let reply2: [String: Any] = ["type": "userMessage", "content": [["text": "<send_user_message_question_reply>\(String(decoding: reply2Data, as: UTF8.self))</send_user_message_question_reply>"]]]
        expect(projection.ingest(snapshot(state(items: [question, replyItem, reply2]), revision: 8)), "resync accepted")
        expect(projection.task?.status == .running && projection.task?.questions.isEmpty == true, "all answers clear attention")
        expect(projection.ingest(snapshot(state(runtime: "active", flags: ["waitingOnApproval"]))), "approval snapshot")
        expect(projection.task?.status == .waitingApproval, "approval distinguished from user question")
        var requestState = state()
        requestState["requests"] = [["id": 123, "method": "item/tool/requestUserInput", "params": ["questions": [["question": "同步提问？", "options": [["label": "继续"]]]]]]]
        expect(projection.ingest(snapshot(requestState)), "sync request snapshot")
        expect(projection.task?.questions.first?.title == "同步提问？", "sync request question parsed")
        expect(projection.ingest(snapshot(state(runtime: "idle", status: "completed"))), "completed snapshot")
        expect(projection.task?.status == .completed, "completion distinguished from active")
        expect(projection.ingest(snapshot(state(runtime: "idle", status: "interrupted"))), "interrupted snapshot")
        expect(projection.task?.status == .interrupted, "interrupted is not successful")
        expect(projection.ingest(snapshot(state(items: [question], runtime: "idle", status: "interrupted"))), "cancelled question snapshot")
        expect(projection.task?.status == .interrupted && projection.task?.questions.isEmpty == true, "cancelled question badge cleared")
        expect(projection.ingest(snapshot(state(runtime: "systemError", status: "failed"))), "error snapshot")
        expect(projection.task?.status == .failed, "system error shown")
        let privateItems: [Any] = [question, ["type": "reasoning", "content": "PRIVATE_REASONING"],
                                  ["type": "commandExecution", "aggregatedOutput": "PRIVATE_TOOL_OUTPUT"],
                                  ["type": "userMessage", "content": [["text": "PRIVATE_USER_PROMPT"]]]]
        expect(projection.ingest(snapshot(state(items: privateItems))), "private fields snapshot")
        let retained = String(decoding: try JSONSerialization.data(withJSONObject: projection.state), as: UTF8.self)
        expect(!retained.contains("PRIVATE_"), "private prose and command output not retained")
        var tasks: [CodexTask] = []
        for index in 0..<40 {
            var p = CodexStreamProjection()
            let nextID = String(format: "22222222-2222-4222-8222-%012d", index)
            expect(p.ingest(snapshot(state(id: nextID, items: index % 7 == 0 ? [question] : []))), "parallel snapshot")
            if let task = p.task { tasks.append(task) }
        }
        let ordered = CodexTask.ordered(tasks.reversed())
        expect(ordered.count == 40, "all parallel tasks kept")
        expect(ordered.prefix(6).allSatisfy { $0.status == .waitingAnswer }, "waiting tasks rank first")
        expect(CodexTask.ordered(tasks) == ordered, "ordering stable across arrival order")
        expect(ordered.first?.destination?.absoluteString.hasPrefix("codex://threads/") == true, "task deep link validated")
        let body = try JSONSerialization.data(withJSONObject: ["type": "broadcast", "sample": "中文"])
        var length = UInt32(body.count).littleEndian
        var frame = Data(bytes: &length, count: 4); frame.append(body)
        var partial = Data(frame.prefix(5))
        expect(try CodexIPCClient.takeFrame(&partial) == nil, "partial frame buffered")
        partial.append(frame.dropFirst(5)); partial.append(frame)
        expect(try CodexIPCClient.takeFrame(&partial)?["sample"] as? String == "中文", "UTF8 frame parsed")
        expect(try CodexIPCClient.takeFrame(&partial) != nil && partial.isEmpty, "coalesced frames parsed")
        print("PASS: \(checks) Codex status checks")
    }
}
