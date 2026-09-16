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
    private var activationObserver: NSObjectProtocol?
    private var followTimer: Timer?
    private var followsForeground = false
    private var followedDisplayID: UInt32?
    private var foregroundPID: pid_t?

    init() {
        refresh()
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
                self?.updateForegroundScreen(notify: false)
                self?.onScreensChanged?()
            }
        }
        rememberForegroundApplication()
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.rememberForegroundApplication()
                self?.updateForegroundScreen()
            }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
        followTimer?.invalidate()
    }

    func screen(for displayID: UInt32?) -> NSScreen? {
        let target = followsForeground ? followedDisplayID : displayID
        if let target,
           let matching = NSScreen.screens.first(where: { Self.displayID(for: $0) == target }) {
            return matching
        }
        // NSScreen.main follows the focused window. Live task updates must not
        // move the notch between displays when another task gains focus.
        return NSScreen.screens.first ?? NSScreen.main
    }

    func configure(followsForeground: Bool) {
        guard self.followsForeground != followsForeground else { return }
        self.followsForeground = followsForeground
        followTimer?.invalidate()
        followTimer = nil
        guard followsForeground else { return }
        updateForegroundScreen(notify: false)
        // App activation covers task switches; polling also catches a foreground
        // window being moved to another display without changing the active app.
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateForegroundScreen() }
        }
        followTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func rememberForegroundApplication() {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        foregroundPID = app.processIdentifier
    }

    private func updateForegroundScreen(notify: Bool = true) {
        guard followsForeground else { return }
        rememberForegroundApplication()
        guard let pid = foregroundPID,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]],
              let primaryTop = NSScreen.screens.first?.frame.maxY else { return }
        // Only window geometry is read. No window title, image, accessibility
        // permission or screen recording permission is needed.
        let bounds = windows.compactMap { window -> CGRect? in
            guard (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid,
                  (window[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  let value = window[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: value as CFDictionary),
                  bounds.width > 80, bounds.height > 60 else { return nil }
            return bounds
        }.first
        guard let bounds,
              let next = Self.displayID(forWindowBounds: bounds, displays: displays, primaryTop: primaryTop),
              next != followedDisplayID else { return }
        followedDisplayID = next
        if notify { onScreensChanged?() }
    }

    nonisolated static func displayID(forWindowBounds bounds: CGRect, displays: [DisplayOption], primaryTop: CGFloat) -> UInt32? {
        let windowFrame = CGRect(x: bounds.minX, y: primaryTop - bounds.maxY, width: bounds.width, height: bounds.height)
        var bestID: UInt32?
        var bestArea: CGFloat = 0
        for display in displays {
            let overlap = display.frame.intersection(windowFrame)
            let area = overlap.isNull ? 0 : overlap.width * overlap.height
            if area > bestArea {
                bestID = display.id
                bestArea = area
            }
        }
        return bestID
    }

    func refresh() {
        displays = NSScreen.screens.enumerated().compactMap { index, screen in
            guard let id = Self.displayID(for: screen) else { return nil }
            let name = screen.localizedName.isEmpty ? "显示器 \(index + 1)" : screen.localizedName
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
