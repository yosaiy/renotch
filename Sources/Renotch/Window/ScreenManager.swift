import AppKit
import CoreGraphics

struct DisplayOption: Identifiable, Hashable {
    let id: UInt32
    let name: String
    let frame: NSRect
}

@MainActor
final class ScreenManager: ObservableObject {
    @Published private(set) var displays: [DisplayOption] = []

    var onScreensChanged: (() -> Void)?
    private var observer: NSObjectProtocol?

    init() {
        refresh()
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
                self?.onScreensChanged?()
            }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func screen(for displayID: UInt32?) -> NSScreen? {
        if let displayID,
           let matching = NSScreen.screens.first(where: { Self.displayID(for: $0) == displayID }) {
            return matching
        }
        return NSScreen.main ?? NSScreen.screens.first
    }

    func refresh() {
        displays = NSScreen.screens.enumerated().compactMap { index, screen in
            guard let id = Self.displayID(for: screen) else { return nil }
            let name = screen.localizedName.isEmpty ? "Display \(index + 1)" : screen.localizedName
            return DisplayOption(id: id, name: name, frame: screen.frame)
        }
    }

    static func displayID(for screen: NSScreen) -> UInt32? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return number.uint32Value
    }
}
