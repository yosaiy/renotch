import AppKit
import Foundation

enum QQMusicCommand: String {
    case toggle, previous, next
}

@MainActor
final class QQMusicBridge {
    var onSnapshot: ((MusicSnapshot?) -> Void)?
    var onError: ((String?) -> Void)?
    private var process: Process?
    private var input: FileHandle?
    private var output: FileHandle?
    private var buffer = Data()
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var generation = UUID()
    private var lastReceived = Date.distantPast
    private var retryAfter = Date.distantPast
    private var previousSnapshot: MusicSnapshot?

    func start() {
        guard timer == nil else { return }
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.checkConnection() }
            })
        }
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkConnection() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        checkConnection()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers.removeAll()
        stopProcess()
        previousSnapshot = nil
        onSnapshot?(nil)
    }

    deinit {
        timer?.invalidate()
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        output?.readabilityHandler = nil
        try? input?.close()
        if let process, process.isRunning { process.terminate() }
    }

    func send(_ command: QQMusicCommand) {
        guard process?.isRunning == true, let input else {
            onError?("请先在 QQ 音乐中开始播放")
            return
        }
        do { try input.write(contentsOf: Data((command.rawValue + "\n").utf8)) }
        catch { onError?("QQ 音乐连接已断开，正在重连") }
    }

    private func checkConnection() {
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: MusicSource.qqMusic.bundleIdentifier).isEmpty else {
            stopProcess()
            previousSnapshot = nil
            onSnapshot?(nil)
            onError?(nil)
            return
        }
        if process != nil, Date().timeIntervalSince(lastReceived) > 8 {
            stopProcess()
            previousSnapshot = nil
            onSnapshot?(nil)
            onError?("QQ 音乐连接暂不可用，正在重试")
        }
        guard process == nil, Date() >= retryAfter else { return }
        guard let paths = Self.resourcePaths else {
            onError?("QQ 音乐组件缺失，请重新安装 Re:notch")
            retryAfter = Date().addingTimeInterval(30)
            return
        }
        let child = Process()
        let stdin = Pipe(), stdout = Pipe()
        child.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        child.arguments = [paths.script.path, paths.library.path]
        child.environment = ["PATH": "/usr/bin:/bin", "LANG": "en_US.UTF-8"]
        child.standardInput = stdin
        child.standardOutput = stdout
        child.standardError = FileHandle.nullDevice
        let request = UUID()
        generation = request
        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let bytes = handle.availableData
            Task { @MainActor in
                guard self?.generation == request else { return }
                self?.receive(bytes)
            }
        }
        child.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                guard let self, self.generation == request else { return }
                self.stopProcess()
                self.previousSnapshot = nil
                self.onSnapshot?(nil)
                self.onError?("QQ 音乐连接已断开，正在重连")
                self.retryAfter = Date().addingTimeInterval(5)
            }
        }
        process = child
        input = stdin.fileHandleForWriting
        output = stdout.fileHandleForReading
        buffer.removeAll(keepingCapacity: true)
        lastReceived = Date()
        do { try child.run() }
        catch {
            stopProcess()
            onError?("QQ 音乐组件启动失败，请重新打开 Re:notch")
            retryAfter = Date().addingTimeInterval(15)
        }
    }

    private func stopProcess() {
        generation = UUID()
        output?.readabilityHandler = nil
        try? input?.close()
        try? output?.close()
        input = nil
        output = nil
        let child = process
        process = nil
        if let child, child.isRunning {
            child.terminate()
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1) {
                if child.isRunning { kill(child.processIdentifier, SIGKILL) }
            }
        }
        buffer.removeAll(keepingCapacity: true)
    }

    private func receive(_ bytes: Data) {
        guard !bytes.isEmpty else { return }
        buffer.append(bytes)
        guard buffer.count <= 3_000_000 else { stopProcess(); onSnapshot?(nil); return }
        while let end = buffer.firstIndex(of: 10) {
            let line = buffer.subdata(in: 0..<end)
            buffer.removeSubrange(0...end)
            guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { continue }
            lastReceived = Date()
            switch object["kind"] as? String {
            case "ready": onError?(nil)
            case "error": onError?(String((object["message"] as? String ?? "QQ 音乐暂不可用").prefix(200)))
            case "snapshot":
                let snapshot = Self.merge(Self.parseSnapshot(object), previous: previousSnapshot)
                previousSnapshot = snapshot
                onSnapshot?(snapshot)
                onError?(nil)
            default: break
            }
        }
    }

    nonisolated static func parseSnapshot(_ object: [String: Any]) -> MusicSnapshot? {
        guard object["bundleID"] as? String == MusicSource.qqMusic.bundleIdentifier,
              object["available"] as? Bool == true,
              let title = object["title"] as? String, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        func number(_ key: String) -> Double {
            guard let value = object[key] as? Double, value.isFinite else { return 0 }
            return max(0, value)
        }
        let artist = object["artist"] as? String ?? ""
        let album = object["album"] as? String ?? ""
        let duration = number("duration")
        let id = object["trackID"] as? String ?? [title, artist, album].joined(separator: "\u{001F}")
        var snapshot = MusicSnapshot(
            source: .qqMusic,
            playbackState: (object["playing"] as? Bool == true) ? .playing : .paused,
            track: MusicTrack(id: "qqMusic:\(id)", source: .qqMusic, title: title, artist: artist, album: album, duration: duration),
            position: min(number("position"), duration), volume: 0,
            artworkURL: nil, shuffleEnabled: false, repeatMode: .off
        )
        snapshot.hasPosition = object["positionAvailable"] as? Bool ?? true
        if let encoded = object["artwork"] as? String, encoded.utf8.count <= 2_800_000 {
            snapshot.artworkData = Data(base64Encoded: encoded)
        }
        return snapshot
    }

    nonisolated static func merge(_ current: MusicSnapshot?, previous: MusicSnapshot?) -> MusicSnapshot? {
        guard var current, let previous, current.track?.id == previous.track?.id else { return current }
        if current.artworkData == nil { current.artworkData = previous.artworkData }
        if !current.hasPosition, current.playbackState == .paused, previous.hasPosition {
            current = MusicSnapshot(source: current.source, playbackState: current.playbackState,
                track: current.track, position: previous.position, volume: current.volume,
                artworkURL: current.artworkURL, shuffleEnabled: current.shuffleEnabled,
                repeatMode: current.repeatMode, artworkData: current.artworkData, hasPosition: true)
        }
        return current
    }

    private static var resourcePaths: (script: URL, library: URL)? {
        if let script = Bundle.main.url(forResource: "qq-music-bridge", withExtension: "pl"),
           let library = Bundle.main.privateFrameworksURL?.appendingPathComponent("libQQMusicBridge.dylib"),
           FileManager.default.fileExists(atPath: library.path) { return (script, library) }
        #if DEBUG
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let directory = root.appendingPathComponent(".build/music-bridge")
        let script = directory.appendingPathComponent("qq-music-bridge.pl")
        let library = directory.appendingPathComponent("libQQMusicBridge.dylib")
        if FileManager.default.fileExists(atPath: library.path), FileManager.default.fileExists(atPath: script.path) { return (script, library) }
        #endif
        return nil
    }
}
