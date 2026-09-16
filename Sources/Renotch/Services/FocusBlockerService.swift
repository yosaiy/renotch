import AppKit
import ApplicationServices
import Combine
import Foundation

@MainActor
final class FocusBlockerService: ObservableObject {
    @Published private(set) var isAccessibilityGranted: Bool = false
    @Published private(set) var isBlockingActive: Bool = false
    @Published private(set) var detectedSite: String?
    @Published private(set) var detectedAppName: String?
    @Published private(set) var bypassUntil: Date?

    private var pollTimer: Timer?
    private var workspaceObserver: NSObjectProtocol?
    private weak var appModel: AppModel?
    private var isEvaluating = false

    /// List of supported browser bundle identifiers & process names
    static let supportedBrowsers: [String: String] = [
        "com.google.Chrome": "Google Chrome",
        "com.apple.Safari": "Safari",
        "com.brave.Browser": "Brave Browser",
        "company.thebrowser.Browser": "Arc",
        "com.microsoft.edgemac": "Microsoft Edge",
        "org.mozilla.firefox": "Firefox",
        "com.operasoftware.Opera": "Opera",
        "com.vivaldi.Vivaldi": "Vivaldi"
    ]

    static let defaultRules: [String] = [
        "threads.net",
        "instagram.com",
        "twitter.com",
        "x.com",
        "youtube.com",
        "tiktok.com",
        "reddit.com",
        "facebook.com",
        "netflix.com"
    ]

    init() {
        checkAccessibilityStatus()
    }

    func start(appModel: AppModel) {
        self.appModel = appModel
        checkAccessibilityStatus()

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.evaluateActiveWindow()
            }
        }

        startPolling()
    }

    deinit {
        pollTimer?.invalidate()
        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
        }
    }

    var isBypassed: Bool {
        guard let bypassUntil else { return false }
        if Date() >= bypassUntil {
            self.bypassUntil = nil
            return false
        }
        return true
    }

    @discardableResult
    func checkAccessibilityStatus() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        let granted = AXIsProcessTrustedWithOptions(options)
        isAccessibilityGranted = granted
        return granted
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        isAccessibilityGranted = AXIsProcessTrustedWithOptions(options)
    }

    func bypass(minutes: Int = 5) {
        bypassUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
        isBlockingActive = false
        appModel?.dismissFocusTakeover()
    }

    func clearBypass() {
        bypassUntil = nil
    }

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.evaluateActiveWindow()
            }
        }
    }

    func evaluateActiveWindow() {
        guard !isEvaluating else { return }
        isEvaluating = true
        defer { isEvaluating = false }

        guard let model = appModel, model.settings.resolvedFocusBlockerEnabled else {
            if isBlockingActive {
                isBlockingActive = false
                appModel?.dismissFocusTakeover()
            }
            return
        }

        // Check strict pomodoro mode
        if model.settings.resolvedFocusBlockerStrictPomodoroOnly {
            let isFocusRunning = model.timer.isActive && !model.timer.isPaused && model.timer.currentMode == .focus
            if !isFocusRunning {
                if isBlockingActive {
                    isBlockingActive = false
                    appModel?.dismissFocusTakeover()
                }
                return
            }
        }

        // Check bypass cooldown
        if isBypassed {
            if isBlockingActive {
                isBlockingActive = false
                appModel?.dismissFocusTakeover()
            }
            return
        }

        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }
        let bundleID = frontApp.bundleIdentifier ?? ""
        let appName = frontApp.localizedName ?? "浏览器"

        let isOurApp = frontApp.processIdentifier == ProcessInfo.processInfo.processIdentifier
            || frontApp == NSRunningApplication.current
            || (!bundleID.isEmpty && bundleID == Bundle.main.bundleIdentifier)

        // If frontmost app is our own app (e.g. Re:notch takeover or settings window), don't dismiss!
        if isOurApp {
            return
        }

        let rules = effectiveRules(for: model)

        // If takeover is currently active and frontmost app is still the blocked app, maintain takeover
        if model.mode == .focusTakeover,
           let targetPID = model.focusTakeoverTargetApp?.processIdentifier,
           frontApp.processIdentifier == targetPID {
            let windowInfo = getFrontmostWindowInfo(for: frontApp)
            if !windowInfo.title.isEmpty || !windowInfo.url.isEmpty {
                let activeTitle = windowInfo.title.lowercased()
                let activeURL = windowInfo.url.lowercased()
                let isStillBlocked = isMatched(title: activeTitle, url: activeURL, rules: rules)
                if !isStillBlocked {
                    isBlockingActive = false
                    appModel?.dismissFocusTakeover()
                }
            }
            return
        }

        // Extract window title & URL
        let windowInfo = getFrontmostWindowInfo(for: frontApp)
        let activeTitle = windowInfo.title.lowercased()
        let activeURL = windowInfo.url.lowercased()

        if let match = matchRule(title: activeTitle, url: activeURL, rules: rules) {
            detectedSite = match
            detectedAppName = appName
            isBlockingActive = true

            // Trigger Fullscreen Notch Takeover in native SwiftUI
            appModel?.triggerFocusTakeover(
                site: match,
                appName: appName,
                targetApp: frontApp
            )
        } else {
            if isBlockingActive {
                isBlockingActive = false
                appModel?.dismissFocusTakeover()
            }
        }
    }

    private func effectiveRules(for model: AppModel) -> [String] {
        let custom = model.settings.resolvedFocusBlockerCustomRules
        return custom.isEmpty ? Self.defaultRules : custom
    }

    private func matchRule(title: String, url: String, rules: [String]) -> String? {
        guard !title.isEmpty || !url.isEmpty else { return nil }
        for rule in rules {
            let cleanRule = rule.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased()
            guard !cleanRule.isEmpty else { continue }
            let domainKeyword = cleanRule
                .replacingOccurrences(of: "https://", with: "")
                .replacingOccurrences(of: "http://", with: "")
                .replacingOccurrences(of: "www.", with: "")
                .split(separator: "/").first.map(String.init) ?? cleanRule

            if (!title.isEmpty && title.contains(domainKeyword)) || (!url.isEmpty && url.contains(domainKeyword)) {
                return domainKeyword
            }

            // Keyword check (e.g. "youtube", "instagram", "threads", "twitter", "reddit")
            let baseName = domainKeyword.split(separator: ".").first.map(String.init) ?? domainKeyword
            if baseName.count >= 4 && !title.isEmpty && title.contains(baseName) {
                return domainKeyword
            }
        }
        return nil
    }

    private func isMatched(title: String, url: String, rules: [String]) -> Bool {
        matchRule(title: title, url: url, rules: rules) != nil
    }

    private func getFrontmostWindowInfo(for app: NSRunningApplication) -> (title: String, url: String) {
        var title = ""
        var url = ""

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var frontWindowValue: AnyObject?
        var result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &frontWindowValue)

        // Fallback to windows list if focused window is not immediately available
        if result != .success || frontWindowValue == nil {
            var windowsValue: AnyObject?
            if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
               let windowList = windowsValue as? [AXUIElement],
               let firstWindow = windowList.first {
                frontWindowValue = firstWindow
                result = .success
            }
        }

        if result == .success, let frontWindow = frontWindowValue {
            if CFGetTypeID(frontWindow as CFTypeRef) == AXUIElementGetTypeID() {
                let windowElement = frontWindow as! AXUIElement

                // Window title
                var titleValue: AnyObject?
                if AXUIElementCopyAttributeValue(windowElement, kAXTitleAttribute as CFString, &titleValue) == .success,
                   let winTitle = titleValue as? String {
                    title = winTitle
                }

                // Document / URL
                var docValue: AnyObject?
                if AXUIElementCopyAttributeValue(windowElement, kAXDocumentAttribute as CFString, &docValue) == .success,
                   let winDoc = docValue as? String {
                    url = winDoc
                }
            }
        }

        return (title, url)
    }

    func closeTabAndResume(for targetApp: NSRunningApplication?) {
        guard let targetApp else {
            appModel?.dismissFocusTakeover()
            return
        }

        let appName = targetApp.localizedName ?? "Google Chrome"
        let bundleID = targetApp.bundleIdentifier ?? ""

        // Execute browser-specific AppleScript
        let scriptSource: String
        if bundleID == "com.apple.Safari" {
            scriptSource = """
            tell application "Safari"
                if (count of windows) > 0 then
                    tell front window
                        close current tab
                    end tell
                end if
            end tell
            """
        } else if bundleID == "com.google.Chrome" || bundleID == "com.brave.Browser" || bundleID == "com.microsoft.edgemac" || bundleID == "company.thebrowser.Browser" {
            scriptSource = """
            tell application "\(appName)"
                if (count of windows) > 0 then
                    tell front window
                        close active tab
                    end tell
                end if
            end tell
            """
        } else {
            // Fallback via System Events keystroke
            scriptSource = """
            tell application "System Events"
                keystroke "w" using command down
            end tell
            """
        }

        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: scriptSource) {
                appleScript.executeAndReturnError(&error)
            }
            if error != nil {
                // Secondary fallback
                let fallbackScript = NSAppleScript(source: "tell application \"System Events\" to keystroke \"w\" using command down")
                fallbackScript?.executeAndReturnError(nil)
            }
        }

        isBlockingActive = false
        appModel?.dismissFocusTakeover()
    }
}
