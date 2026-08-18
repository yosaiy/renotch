import AppKit
import SwiftUI

@main
struct RenotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
                .environmentObject(appDelegate.model)
        } label: {
            Image(nsImage: Self.trayIcon)
        }
    }

    /// Custom menu bar icon bundled with the package, scaled to menu bar size.
    private static var trayIcon: NSImage {
        if let url = Bundle.main.url(forResource: "TrayIconTemplate", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            return image
        }
        if let bundleURL = Bundle.main.resourceURL?.appendingPathComponent("Renotch_Renotch.bundle"),
           let bundle = Bundle(url: bundleURL),
           let url = bundle.url(forResource: "TrayIconTemplate", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            return image
        }
        let fallback = NSImage(systemSymbolName: "menubar.rectangle", accessibilityDescription: "Re:notch") ?? NSImage()
        fallback.isTemplate = true
        fallback.size = NSSize(width: 18, height: 18)
        return fallback
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?

    let model = AppModel()
    let screenManager = ScreenManager()
    private var notchController: NotchWindowController?
    private var settingsController: SettingsWindowController?

    override init() {
        super.init()
        Self.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NotificationService.shared.requestAuthorization()
        UpdateChecker.check(interactive: false)
        _ = try? BrowserIntegrationInstaller.installBundledHost()
        notchController = NotchWindowController(model: model, screenManager: screenManager)
        settingsController = SettingsWindowController(model: model, screenManager: screenManager)
        if model.settings.isEnabled {
            notchController?.show()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func showNotch() {
        model.setVisible(true)
        notchController?.show()
    }

    func hideNotch() {
        model.setVisible(false)
        notchController?.hide()
    }

    func restartNotch() {
        notchController?.restart()
    }

    func openSettings() {
        settingsController?.present()
    }

    func checkForUpdates() {
        UpdateChecker.check(interactive: true)
    }

    func openBrowserIntegration() {
        do {
            try BrowserIntegrationInstaller.installBundledHost()
            guard let extensionURL = BrowserIntegrationInstaller.bundledExtensionURL,
                  FileManager.default.fileExists(atPath: extensionURL.path) else {
                model.showMessage("Browser extension is unavailable")
                return
            }
            NSWorkspace.shared.activateFileViewerSelecting([
                extensionURL.appendingPathComponent("manifest.json")
            ])
            model.setVisible(true)
            notchController?.show()
            model.showMessage("Load BrowserExtension in your browser")
        } catch {
            model.setVisible(true)
            notchController?.show()
            model.showMessage(error.localizedDescription)
        }
    }
}

private struct MenuBarContent: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Button("Show Notch") { AppDelegate.shared?.showNotch() }
            .disabled(model.settings.isEnabled)
        Button("Hide Notch") { AppDelegate.shared?.hideNotch() }
            .disabled(!model.settings.isEnabled)

        Divider()

        Button(activityMenuTitle) {
            AppDelegate.shared?.showNotch()
            model.expand(section: .activity, pin: true)
        }

        Divider()

        TimerMenuSection(timer: model.timer)

        Button("Settings…") { AppDelegate.shared?.openSettings() }
            .keyboardShortcut(",")
        Button("Check for Updates…") { AppDelegate.shared?.checkForUpdates() }
        Button("Set Up Browser Activity…") { AppDelegate.shared?.openBrowserIntegration() }
        Button("Restart Notch") { AppDelegate.shared?.restartNotch() }

        Divider()

        Button("Quit Re:notch") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private var activityMenuTitle: String {
        let activity = model.activity.primaryActivity
        return "\(activity.title) · \(activity.subtitle)"
    }
}

private struct TimerMenuSection: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var timer: TimerService

    var body: some View {
        if timer.isActive {
            Button("\(timer.currentMode.title) · \(TimerService.formatted(timer.remaining))") {
                AppDelegate.shared?.showNotch()
                model.expand(section: .timer, pin: true)
            }
            Button(timer.isPaused ? "Resume \(timer.currentMode.title)" : "Pause \(timer.currentMode.title)") {
                timer.togglePause()
            }
            Button("Skip to \(timer.currentMode == .focus ? "Break" : "Focus")") {
                timer.skip()
            }
            Button("Cancel Timer", role: .destructive) { timer.cancel() }
            Divider()
        } else {
            Button("Start Pomodoro (\(timer.focusMinutes)m Focus + \(timer.breakMinutes)m Break)") {
                model.startPomodoro()
            }
            Button("Start Focus (\(timer.focusMinutes)m)") {
                model.startTimer(minutes: timer.focusMinutes, mode: .focus)
            }
            Button("Start Break (\(timer.breakMinutes)m)") {
                model.startTimer(minutes: timer.breakMinutes, mode: .breakTime)
            }
            Divider()
        }
    }
}
