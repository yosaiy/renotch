import Darwin
import Foundation

/// Uses the installed Codex app's own CLI and login. The only account operation
/// sent is account/rateLimits/read. No credentials are read by Re:notch.
enum CodexUsageClient {
    enum ReadError: Error { case unavailable, timedOut, invalidResponse }

    static func read(executable: URL, timeout: TimeInterval = 12) throws -> CodexUsageSnapshot {
        let process = Process()
        let input = Pipe(), output = Pipe()
        process.executableURL = executable
        process.arguments = ["app-server", "--stdio", "-c", "analytics.enabled=false"]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.qualityOfService = .utility
        try process.run()
        defer {
            try? input.fileHandleForWriting.close()
            if process.isRunning { process.terminate() }
            let deadline = Date().addingTimeInterval(0.5)
            while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.02) }
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            try? output.fileHandleForReading.close()
        }
        func send(_ message: [String: Any]) throws {
            var data = try JSONSerialization.data(withJSONObject: message)
            data.append(10)
            try input.fileHandleForWriting.write(contentsOf: data)
        }
        try send(["id": 1, "method": "initialize", "params": [
            "clientInfo": ["name": "renotch_usage", "version": "1.0.0"],
            "capabilities": ["experimentalApi": true]
        ]])
        let deadline = Date().addingTimeInterval(timeout)
        let fd = output.fileHandleForReading.fileDescriptor
        var buffer = Data()
        while Date() < deadline {
            var descriptor = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            let ready = poll(&descriptor, 1, 200)
            guard ready >= 0 || errno == EINTR else { throw ReadError.unavailable }
            if ready <= 0 { continue }
            var bytes = [UInt8](repeating: 0, count: 16384)
            let count = Darwin.read(fd, &bytes, bytes.count)
            guard count > 0 else { throw ReadError.unavailable }
            buffer.append(contentsOf: bytes.prefix(count))
            guard buffer.count < 1_048_576 else { throw ReadError.invalidResponse }
            while let end = buffer.firstIndex(of: 10) {
                let line = Data(buffer[..<end])
                buffer.removeSubrange(...end)
                guard let message = try JSONSerialization.jsonObject(with: line) as? [String: Any],
                      let id = message["id"] as? Int else { continue }
                guard message["error"] == nil else { throw ReadError.unavailable }
                if id == 1 {
                    try send(["method": "initialized"])
                    try send(["id": 2, "method": "account/rateLimits/read", "params": [:]])
                } else if id == 2 {
                    guard let result = message["result"] as? [String: Any],
                          let snapshot = CodexUsageSnapshot.parse(result) else { throw ReadError.invalidResponse }
                    return snapshot
                }
            }
        }
        throw ReadError.timedOut
    }
}
