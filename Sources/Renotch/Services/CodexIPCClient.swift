import Darwin
import Foundation
import SQLite3

/// A read-only subscriber to the desktop app's local status stream. Outbound
/// messages are restricted to registration, following and declining discovery.
/// This client cannot submit answers, approve tools or start/interrupt turns.
final class CodexIPCClient: @unchecked Sendable {
    typealias Update = ([CodexTask], Bool, String?) -> Void
    private let home: URL
    private let update: Update
    private let queue = DispatchQueue(label: "renotch.codex-status", qos: .utility)
    private let lock = NSLock()
    private var stopped = true
    private var generation = 0

    init(home: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex"), update: @escaping Update) {
        self.home = home
        self.update = update
    }

    func start() {
        lock.lock()
        guard stopped else { lock.unlock(); return }
        stopped = false
        generation += 1
        let token = generation
        lock.unlock()
        queue.async { [self] in run(token: token) }
    }

    func stop() {
        lock.lock(); stopped = true; generation += 1; lock.unlock()
    }

    private func isRunning(_ token: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return !stopped && generation == token
    }

    private func run(token: Int) {
        while isRunning(token) {
            autoreleasepool {
                do { try connectedLoop(token: token) }
                catch ConnectionError.incompatible { update([], false, "Codex 状态接口已变化，需要更新接入模块") }
                catch { update([], false, "暂时无法连接 Codex，正在自动重连") }
            }
            for _ in 0..<10 where isRunning(token) { Thread.sleep(forTimeInterval: 0.2) }
        }
    }

    private func connectedLoop(token: Int) throws {
        let path = home.appendingPathComponent("ipc/ipc.sock").path
        var info = stat()
        guard lstat(path, &info) == 0, info.st_uid == getuid(),
              (info.st_mode & S_IFMT) == S_IFSOCK, (info.st_mode & 0o077) == 0 else {
            throw ConnectionError.unavailable
        }
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw ConnectionError.unavailable }
        defer { Darwin.close(fd) }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let encoded = Array(path.utf8CString)
        guard encoded.count <= MemoryLayout.size(ofValue: address.sun_path) else { throw ConnectionError.unavailable }
        withUnsafeMutableBytes(of: &address.sun_path) { dest in
            encoded.withUnsafeBytes { src in dest.copyBytes(from: src) }
        }
        var noSignal: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout.size(ofValue: noSignal)))
        var timeout = timeval(tv_sec: 2, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0 else { throw ConnectionError.unavailable }
        try send(fd, ["type": "request", "requestId": UUID().uuidString, "method": "initialize", "version": 0,
                      "params": ["clientType": "renotch-status"]])
        var buffer = Data()
        var clientID: String?
        var followed = Set<String>()
        var projections: [String: CodexStreamProjection] = [:]
        var lastDiscovery = Date.distantPast
        var lastPublish = Date.distantPast
        var changed = false
        let connectedAt = Date()
        while isRunning(token) {
            if let clientID, Date().timeIntervalSince(lastDiscovery) >= 4 {
                let candidates = Set(try candidateThreadIDs())
                for id in followed.subtracting(candidates) {
                    try follow(fd, clientID: clientID, threadID: id, value: false)
                    projections.removeValue(forKey: id)
                }
                for id in candidates.subtracting(followed) {
                    try follow(fd, clientID: clientID, threadID: id, value: true)
                }
                followed = candidates
                lastDiscovery = Date()
                changed = true
            }
            var descriptor = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            let available = poll(&descriptor, 1, 200)
            guard available >= 0 || errno == EINTR else { throw ConnectionError.unavailable }
            if available > 0 {
                guard (descriptor.revents & Int16(POLLERR | POLLHUP | POLLNVAL)) == 0 else { throw ConnectionError.unavailable }
                var bytes = [UInt8](repeating: 0, count: 65536)
                let count = Darwin.read(fd, &bytes, bytes.count)
                guard count > 0 else { throw ConnectionError.unavailable }
                buffer.append(contentsOf: bytes.prefix(count))
                while let message = try Self.takeFrame(&buffer) {
                    if message["type"] as? String == "client-discovery-request", let requestID = message["requestId"] {
                        try send(fd, ["type": "client-discovery-response", "requestId": requestID, "response": ["canHandle": false]])
                        continue
                    }
                    if message["type"] as? String == "response", message["method"] as? String == "initialize",
                       let response = message["result"] as? [String: Any], let id = response["clientId"] as? String {
                        clientID = id; changed = true; continue
                    }
                    guard message["method"] as? String == "thread-stream-state-changed",
                          let params = message["params"] as? [String: Any], params["hostId"] as? String == "local",
                          let id = params["conversationId"] as? String, followed.contains(id),
                          let change = params["change"] as? [String: Any], let clientID else { continue }
                    guard message["version"] as? Int == 11 else {
                        throw ConnectionError.incompatible
                    }
                    var projection = projections[id] ?? CodexStreamProjection()
                    if projection.ingest(change) { projections[id] = projection; changed = true }
                    else {
                        // A missing revision must never leave an old approval or
                        // question badge on screen. Ask the owner for a new snapshot.
                        projections.removeValue(forKey: id)
                        changed = true
                        try follow(fd, clientID: clientID, threadID: id, value: false)
                        try follow(fd, clientID: clientID, threadID: id, value: true)
                    }
                }
            }
            if clientID == nil && Date().timeIntervalSince(connectedAt) > 5 { throw ConnectionError.unavailable }
            if changed && Date().timeIntervalSince(lastPublish) >= 0.2 {
                update(CodexTask.ordered(projections.values.compactMap(\.task)), clientID != nil, nil)
                lastPublish = Date(); changed = false
            }
        }
    }

    private func candidateThreadIDs() throws -> [String] {
        var running = Set<String>()
        let history = home.appendingPathComponent("thread_history_1.sqlite")
        if FileManager.default.fileExists(atPath: history.path) {
            running.formUnion(try query(history, """
                SELECT t.thread_id FROM thread_turns t WHERE t.status='inProgress'
                AND NOT EXISTS (SELECT 1 FROM thread_turns n WHERE n.thread_id=t.thread_id AND n.rollout_ordinal>t.rollout_ordinal)
                """))
        }
        let database = home.appendingPathComponent("state_5.sqlite")
        let recent = Set(try query(database, "SELECT id FROM threads WHERE archived=0 AND updated_at>\(Int(Date().timeIntervalSince1970)-86400)"))
        let roots = Set(try query(database, "SELECT id FROM threads WHERE archived=0 AND (agent_path IS NULL OR agent_path='/root')"))
        return Array(running.union(recent).intersection(roots)).sorted()
    }

    private func query(_ url: URL, _ sql: String) throws -> [String] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else {
            if let db { sqlite3_close(db) }; throw ConnectionError.unavailable
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 100)
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { throw ConnectionError.incompatible }
        defer { sqlite3_finalize(statement) }
        var rows: [String] = []
        var result = sqlite3_step(statement)
        while result == SQLITE_ROW {
            if let text = sqlite3_column_text(statement, 0) { rows.append(String(cString: text)) }
            result = sqlite3_step(statement)
        }
        guard result == SQLITE_DONE else { throw ConnectionError.unavailable }
        return rows
    }

    private func follow(_ fd: Int32, clientID: String, threadID: String, value: Bool) throws {
        try send(fd, ["type": "broadcast", "method": "thread-stream-following-changed", "version": 1,
                      "sourceClientId": clientID, "params": ["conversationId": threadID, "hostId": "local", "following": value]])
    }

    private func send(_ fd: Int32, _ message: [String: Any]) throws {
        let body = try JSONSerialization.data(withJSONObject: message)
        var length = UInt32(body.count).littleEndian
        var data = Data(bytes: &length, count: 4); data.append(body)
        try data.withUnsafeBytes { bytes in
            var offset = 0
            while offset < bytes.count {
                let written = Darwin.write(fd, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
                guard written > 0 else { throw ConnectionError.unavailable }
                offset += written
            }
        }
    }

    static func takeFrame(_ buffer: inout Data) throws -> [String: Any]? {
        guard buffer.count >= 4 else { return nil }
        let bytes = Array(buffer.prefix(4))
        let count = Int(UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24)
        guard count > 0 && count <= 64 * 1024 * 1024 else { throw ConnectionError.incompatible }
        guard buffer.count >= count + 4 else { return nil }
        let data = buffer.dropFirst(4).prefix(count)
        let message = try JSONSerialization.jsonObject(with: Data(data)) as? [String: Any]
        buffer.removeFirst(count + 4)
        return message
    }

    enum ConnectionError: Error { case unavailable, incompatible }
}
