import AppKit
import SwiftUI

@main
struct RenotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
                .environment(\.locale, Locale(identifier: "zh_CN"))
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

    let model: AppModel = {
        #if DEBUG
        if CommandLine.arguments.contains("--codex-ui-preview") || Bundle.main.object(forInfoDictionaryKey: "RenotchUIPreview") as? Bool == true {
            let suite = "com.renotch.codex-ui-preview"
            UserDefaults.standard.removePersistentDomain(forName: suite)
            let defaults = UserDefaults(suiteName: suite)!
            defaults.set(true, forKey: "virtualNotch.didCompleteOnboarding")
            return AppModel(defaults: defaults, connectCodex: false)
        }
        #endif
        return AppModel()
    }()
    let screenManager = ScreenManager()
    private var notchController: NotchWindowController?
    private var settingsController: SettingsWindowController?

    override init() {
        super.init()
        Self.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        #if DEBUG
        if CommandLine.arguments.contains("--codex-ui-preview") || Bundle.main.object(forInfoDictionaryKey: "RenotchUIPreview") as? Bool == true {
            model.codex.showPreview()
            model.expand(section: .codex, pin: true)
            notchController = NotchWindowController(model: model, screenManager: screenManager)
            settingsController = SettingsWindowController(model: model, screenManager: screenManager)
            notchController?.show()
            return
        }
        #endif
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
                model.showMessage("浏览器扩展不可用")
                return
            }
            NSWorkspace.shared.activateFileViewerSelecting([
                extensionURL.appendingPathComponent("manifest.json")
            ])
            model.setVisible(true)
            notchController?.show()
            model.showMessage("请在浏览器中加载 BrowserExtension 扩展目录")
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
        Button("显示刘海") { AppDelegate.shared?.showNotch() }
            .disabled(model.settings.isEnabled)
        Button("隐藏刘海") { AppDelegate.shared?.hideNotch() }
            .disabled(!model.settings.isEnabled)

        Divider()

        Button("Codex 任务 · \(model.codex.activeTasks.count) 执行或待处理") {
            AppDelegate.shared?.showNotch()
            model.expand(section: .codex, pin: true)
        }

        Button(activityMenuTitle) {
            AppDelegate.shared?.showNotch()
            model.expand(section: .activity, pin: true)
        }

        Divider()

        TimerMenuSection(timer: model.timer)

        Button("设置…") { AppDelegate.shared?.openSettings() }
            .keyboardShortcut(",")
        Button("检查更新…") { AppDelegate.shared?.checkForUpdates() }
        Button("配置浏览器活动…") { AppDelegate.shared?.openBrowserIntegration() }
        Button("重新显示刘海") { AppDelegate.shared?.restartNotch() }

        Divider()

        Button("退出 Re:notch") { NSApp.terminate(nil) }
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
            Button(timer.isPaused ? "继续\(timer.currentMode.title)" : "暂停\(timer.currentMode.title)") {
                timer.togglePause()
            }
            Button("切换到\(timer.currentMode == .focus ? "休息" : "专注")") {
                timer.skip()
            }
            Button("取消计时", role: .destructive) { timer.cancel() }
            Divider()
        } else {
            Button("开始番茄钟（专注 \(timer.focusMinutes) 分钟 + 休息 \(timer.breakMinutes) 分钟）") {
                model.startPomodoro()
            }
            Button("开始专注（\(timer.focusMinutes) 分钟）") {
                model.startTimer(minutes: timer.focusMinutes, mode: .focus)
            }
            Button("开始休息（\(timer.breakMinutes) 分钟）") {
                model.startTimer(minutes: timer.breakMinutes, mode: .breakTime)
            }
            Divider()
        }
    }
}
