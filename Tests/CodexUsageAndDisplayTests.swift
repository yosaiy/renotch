import AppKit
import Foundation

@main
struct CodexUsageAndDisplayTests {
    @MainActor
    static func main() throws {
        if CommandLine.arguments.contains("--live") {
            guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.codex") else { fatalError("Codex app not found") }
            let snapshot = try CodexUsageClient.read(executable: app.appendingPathComponent("Contents/Resources/codex"))
            for bucket in snapshot.buckets {
                print("\(bucket.title)：\(bucket.windows.map { "\($0.title)剩余 \($0.remainingText)" }.joined(separator: "，"))")
            }
            return
        }
        var checks = 0
        func expect(_ condition: Bool, _ message: String) {
            checks += 1
            if !condition { fputs("FAIL: \(message)\n", stderr); exit(1) }
        }
        func window(_ used: Any, _ minutes: Int = 10080) -> [String: Any] {
            ["usedPercent": used, "windowDurationMins": minutes, "resetsAt": 2_000_000_000.0]
        }
        let values: [String: Any] = [
            "rateLimits": ["limitId": "codex", "primary": window(70.0)],
            "rateLimitsByLimitId": [
                "codex": ["primary": window(20.0), "secondary": NSNull()],
                "spark": ["limitName": "Spark", "primary": window(0.0, 300), "secondary": window(100.0)]
            ]
        ]
        let snapshot = CodexUsageSnapshot.parse(values)!
        expect(snapshot.main?.windows.first?.remainingPercent == 80, "remaining is 100 minus used, per-limit map preferred")
        expect(snapshot.main?.windows.first?.title == "每周", "primary can be weekly, not necessarily five hours")
        expect(snapshot.main?.windows.count == 1, "missing secondary is not invented")
        expect(snapshot.buckets.first?.id == "codex", "main account quota precedes model-specific limits")
        expect(snapshot.buckets.last?.windows.first?.remainingPercent == 100, "zero used means all remaining")
        expect(snapshot.buckets.last?.windows.last?.remainingPercent == 0, "fully used means zero remaining")
        expect(snapshot.buckets.last?.windows.first?.title == "5 小时", "short window duration label")
        expect(snapshot.main?.windows.first?.resetsAt?.timeIntervalSince1970 == 2_000_000_000, "reset is Unix seconds")
        let unknown = CodexUsageSnapshot.parse(["rateLimits": ["primary": window(NSNull())]])!
        expect(unknown.main?.windows.first?.remainingPercent == nil, "missing data remains unknown")
        expect(unknown.main?.windows.first?.remainingText == "暂不可用", "unknown never displays zero")
        expect(CodexUsageSnapshot.parse([:]) == nil, "empty response rejected")
        for (used, expected) in [(-2.0, 100.0), (150.0, 0.0), (12.5, 87.5)] {
            let result = CodexUsageSnapshot.parse(["rateLimits": ["primary": window(used)]])!
            expect(result.main?.windows.first?.remainingPercent == expected, "remaining percentage clamped")
        }
        let displays = [
            DisplayOption(id: 1, name: "主屏", frame: CGRect(x: 0, y: 0, width: 1440, height: 900)),
            DisplayOption(id: 2, name: "右屏", frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080)),
            DisplayOption(id: 3, name: "左屏", frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080)),
            DisplayOption(id: 4, name: "上屏", frame: CGRect(x: 0, y: 900, width: 1440, height: 900)),
            DisplayOption(id: 5, name: "下屏", frame: CGRect(x: 0, y: -900, width: 1440, height: 900))
        ]
        let positions: [(CGRect, UInt32?)] = [
            (CGRect(x: 50, y: 80, width: 800, height: 600), 1),
            (CGRect(x: 1700, y: 80, width: 800, height: 600), 2),
            (CGRect(x: -1800, y: 80, width: 800, height: 600), 3),
            (CGRect(x: 50, y: -800, width: 800, height: 600), 4),
            (CGRect(x: 50, y: 1000, width: 800, height: 600), 5),
            (CGRect(x: 1400, y: 80, width: 800, height: 600), 2),
            (CGRect(x: -100, y: 80, width: 800, height: 600), 1),
            (CGRect(x: 8000, y: 80, width: 800, height: 600), nil)
        ]
        for (bounds, expected) in positions {
            expect(ScreenManager.displayID(forWindowBounds: bounds, displays: displays, primaryTop: 900) == expected, "window geometry maps to largest display intersection")
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("renotch-usage-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let mock = directory.appendingPathComponent("mock.py")
        try """
        #!/usr/bin/python3
        import json,sys,time,pathlib
        for line in sys.stdin:
            request=json.loads(line)
            method=request['method']
            with pathlib.Path(__file__).with_suffix('.calls').open('a') as f: f.write(method+'\\n')
            if method=='initialize': print(json.dumps({'id':1,'result':{}}),flush=True)
            elif method=='account/rateLimits/read':
                result={'id':2,'result':{'rateLimits':{'primary':{'usedPercent':25,'windowDurationMins':10080}}}}
                text=json.dumps(result)+'\\n'
                sys.stdout.write(text[:13]);sys.stdout.flush();time.sleep(0.02)
                sys.stdout.write(text[13:]);sys.stdout.flush()
                break
        """.write(to: mock, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: mock.path)
        let liveMock = try CodexUsageClient.read(executable: mock)
        expect(liveMock.main?.windows.first?.remainingPercent == 75, "fragmented app-server response decoded")
        let calls = try String(contentsOf: mock.deletingPathExtension().appendingPathExtension("calls"), encoding: .utf8)
        expect(calls.split(separator: "\n").map(String.init) == ["initialize", "initialized", "account/rateLimits/read"], "only read-only quota methods sent")
        try "#!/usr/bin/python3\nimport time\ntime.sleep(5)\n".write(to: mock, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: mock.path)
        let started = Date()
        do { _ = try CodexUsageClient.read(executable: mock, timeout: 0.1); expect(false, "timeout expected") }
        catch CodexUsageClient.ReadError.timedOut { expect(Date().timeIntervalSince(started) < 2, "hung helper is terminated promptly") }
        print("PASS: \(checks) usage and display checks")
    }
}
