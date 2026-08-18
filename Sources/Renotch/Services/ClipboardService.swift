import AppKit
import Foundation

final class ClipboardService: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []

    private let pasteboard: NSPasteboard
    private let defaults: UserDefaults
    private let persistenceKey = "virtualNotch.clipboard.v1"
    private var lastChangeCount: Int
    private var monitor: Timer?
    private var isEnabled = true

    init(pasteboard: NSPasteboard = .general, defaults: UserDefaults = .standard) {
        self.pasteboard = pasteboard
        self.defaults = defaults
        lastChangeCount = pasteboard.changeCount
        restore()
    }

    deinit {
        monitor?.invalidate()
    }

    func start(enabled: Bool) {
        isEnabled = enabled
        if enabled {
            guard monitor == nil else { return }
            monitor = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.inspectPasteboard()
            }
            monitor?.tolerance = 0.3
        } else {
            monitor?.invalidate()
            monitor = nil
        }
    }

    func pause() {
        monitor?.invalidate()
        monitor = nil
    }

    func resume() {
        if isEnabled {
            start(enabled: true)
        }
    }

    func setEnabled(_ enabled: Bool) {
        start(enabled: enabled)
    }

    func copy(_ item: ClipboardItem) {
        pasteboard.clearContents()
        pasteboard.setString(item.content, forType: .string)
        lastChangeCount = pasteboard.changeCount
    }

    func delete(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        persist()
    }

    func clear() {
        items.removeAll()
        persist()
    }

    func ingest(_ content: String, at date: Date = Date()) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, items.first?.content != content else { return }
        items.insert(ClipboardItem(content: content, createdAt: date), at: 0)
        if items.count > 20 {
            items.removeLast(items.count - 20)
        }
        persist()
    }

    private func inspectPasteboard() {
        guard isEnabled, pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        let typeNames = pasteboard.types?.map(\.rawValue) ?? []
        let looksSensitive = typeNames.contains {
            let lowered = $0.lowercased()
            return lowered.contains("concealed") || lowered.contains("password") || lowered.contains("transient")
        }
        guard !looksSensitive, let content = pasteboard.string(forType: .string) else { return }
        ingest(content)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: persistenceKey)
    }

    private func restore() {
        guard let data = defaults.data(forKey: persistenceKey),
              let saved = try? JSONDecoder().decode([ClipboardItem].self, from: data) else { return }
        items = Array(saved.prefix(20))
    }
}
