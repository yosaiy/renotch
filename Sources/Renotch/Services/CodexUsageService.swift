import AppKit
import Foundation

@MainActor
final class CodexUsageService: ObservableObject {
    @Published private(set) var snapshot: CodexUsageSnapshot?
    @Published private(set) var isLoading = false
    @Published private(set) var message: String?
    private let allowsRequests: Bool
    private var enabled = true
    private var timer: Timer?
    private var epoch = 0

    init(connect: Bool = true, enabled: Bool = true) {
        allowsRequests = connect
        self.enabled = enabled
        if connect && enabled { start() }
    }

    var isStale: Bool { message != nil || snapshot.map { Date().timeIntervalSince($0.fetchedAt) > 90 } == true }

    var compactSummary: String? {
        guard enabled, !isStale, let window = snapshot?.main?.windows.first,
              let remaining = window.remainingPercent else { return nil }
        return "\(window.title)剩余 \(Int(remaining.rounded()))%"
    }

    func configure(enabled: Bool) {
        guard self.enabled != enabled else { return }
        self.enabled = enabled
        enabled ? start() : pause()
    }

    func start() {
        guard enabled && allowsRequests && timer == nil else { return }
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        refresh()
    }

    func pause() {
        epoch += 1
        timer?.invalidate(); timer = nil
        isLoading = false
    }

    func refresh() {
        guard enabled && allowsRequests && !isLoading else { return }
        guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.codex"),
              FileManager.default.isExecutableFile(atPath: app.appendingPathComponent("Contents/Resources/codex").path) else {
            message = "未找到 Codex 桌面应用"; return
        }
        isLoading = true
        let executable = app.appendingPathComponent("Contents/Resources/codex")
        let token = epoch
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let result = Result { try CodexUsageClient.read(executable: executable) }
            Task { @MainActor [weak self] in
                guard let self, self.epoch == token else { return }
                self.isLoading = false
                switch result {
                case .success(let snapshot): self.snapshot = snapshot; self.message = nil
                case .failure: self.message = "暂时无法刷新用量，请确认 Codex 已登录"
                }
            }
        }
    }

    deinit { timer?.invalidate() }
}
