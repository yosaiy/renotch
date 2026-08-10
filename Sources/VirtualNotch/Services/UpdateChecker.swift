import AppKit
import Foundation

/// Zero-dependency update check against the GitHub Releases API. Compares the
/// latest release tag with the running version and offers to open the release
/// page; the user downloads and installs the new build manually.
@MainActor
enum UpdateChecker {
    private static let apiURL = URL(
        string: "https://api.github.com/repos/yosaiy/renotch/releases/latest"
    )!
    private static let fallbackPage = URL(
        string: "https://github.com/yosaiy/renotch/releases/latest"
    )!

    /// - Parameter interactive: `true` for the menu action (also reports
    ///   "up to date" and errors), `false` for the silent launch check.
    static func check(interactive: Bool) {
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: apiURL)
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let tag = json?["tag_name"] as? String else {
                    if interactive { showError() }
                    return
                }
                let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
                let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
                guard isNewer(latest, than: current) else {
                    if interactive {
                        showAlert(
                            title: "You're up to date",
                            body: "Re:notch \(current) is the latest version."
                        )
                    }
                    return
                }
                let page = (json?["html_url"] as? String).flatMap(URL.init) ?? fallbackPage
                NSApp.activate(ignoringOtherApps: true)
                let alert = NSAlert()
                alert.messageText = "Update available"
                alert.informativeText = "Re:notch \(latest) is available (you have \(current)). Download it?"
                alert.addButton(withTitle: "Download")
                alert.addButton(withTitle: "Not Now")
                if alert.runModal() == .alertFirstButtonReturn {
                    NSWorkspace.shared.open(page)
                }
            } catch {
                if interactive { showError() }
            }
        }
    }

    /// Component-wise numeric comparison, e.g. 1.10.0 > 1.9.2.
    private static func isNewer(_ candidate: String, than current: String) -> Bool {
        let lhs = candidate.split(separator: ".").compactMap { Int($0) }
        let rhs = current.split(separator: ".").compactMap { Int($0) }
        for index in 0..<max(lhs.count, rhs.count) {
            let next = index < lhs.count ? lhs[index] : 0
            let installed = index < rhs.count ? rhs[index] : 0
            if next != installed { return next > installed }
        }
        return false
    }

    private static func showError() {
        NSApp.activate(ignoringOtherApps: true)
        showAlert(
            title: "Update check failed",
            body: "Could not reach GitHub. Check your connection and try again."
        )
    }

    private static func showAlert(title: String, body: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.runModal()
    }
}
