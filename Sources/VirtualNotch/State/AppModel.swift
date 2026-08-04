import AppKit
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var settings: NotchSettings {
        didSet {
            settingsStore.save(settings)
            clipboard.setEnabled(settings.clipboardHistoryEnabled)
            applyLaunchAtLoginIfNeeded(oldValue: oldValue.launchAtLogin)
            onPanelConfigurationChanged?()
        }
    }
    @Published private(set) var mode: NotchMode
    @Published private(set) var isDraggingFileOver = false
    @Published var selectedSection: NotchSection
    @Published private(set) var isPinned: Bool
    @Published var customTimerMinutes = 30
    @Published var transientMessage: String?
    @Published var settingsError: String?
    @Published private(set) var expandedSectionOverride: NotchSection?

    let timer: TimerService
    let clipboard: ClipboardService
    let music: MusicService
    let browser: BrowserActivityService
    let calendar: AppleCalendarService
    let shelf: ShelfStore
    let todos: TodoStore
    let activity: DeveloperActivityService

    var onPanelConfigurationChanged: (() -> Void)?
    var onVisibilityChanged: ((Bool) -> Void)?

    private let settingsStore: SettingsStore
    private let defaults: UserDefaults
    private var collapseWorkItem: DispatchWorkItem?
    private var dropExitWorkItem: DispatchWorkItem?
    private var successWorkItem: DispatchWorkItem?
    private var messageWorkItem: DispatchWorkItem?
    private var browserActivityCancellable: AnyCancellable?
    private var musicActivityCancellable: AnyCancellable?
    private var activityGlanceCancellable: AnyCancellable?
    private var modeBeforeFileDrop: NotchMode = .compact
    private var isApplyingLoginSetting = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        settingsStore = SettingsStore(defaults: defaults)
        let loadedSettings = settingsStore.load()
        settings = loadedSettings
        timer = TimerService(defaults: defaults)
        clipboard = ClipboardService(defaults: defaults)
        music = MusicService()
        browser = BrowserActivityService()
        calendar = AppleCalendarService()
        shelf = ShelfStore()
        todos = TodoStore(defaults: defaults)
        activity = DeveloperActivityService()

        let didOnboard = defaults.bool(forKey: "virtualNotch.didCompleteOnboarding")
        mode = didOnboard ? .compact : .expanded
        selectedSection = didOnboard ? loadedSettings.resolvedCompactContent.section : .welcome
        expandedSectionOverride = nil
        isPinned = !didOnboard

        clipboard.start(enabled: settings.clipboardHistoryEnabled)
        timer.onCompletion = { [weak self] in
            Task { @MainActor in
                self?.handleTimerCompletion()
            }
        }
        browserActivityCancellable = browser.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        musicActivityCancellable = music.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        activityGlanceCancellable = activity.$glance
            .dropFirst()
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.objectWillChange.send()
                    self?.onPanelConfigurationChanged?()
                }
            }
    }

    var isExpanded: Bool {
        switch mode {
        case .expanded, .fileDrop, .success:
            return true
        case .compact:
            return false
        }
    }

    private var compactDestination: NotchSection {
        activity.glance == nil ? settings.resolvedCompactContent.section : .activity
    }

    var activeMediaSource: AdaptiveMediaSource? {
        AdaptiveMediaArbitrator.resolve(
            browserAvailable: browser.media != nil,
            browserIsPlaying: browser.media?.isPlaying == true,
            browserActivation: browser.playbackActivationDate,
            musicIsPlaying: music.isPlaying,
            musicActivation: music.playbackActivationDate
        )
    }

    var currentSize: NSSize {
        switch mode {
        case .compact:
            if browser.activeDownload != nil {
                return NSSize(
                    width: max(settings.compactWidth, 340),
                    height: max(settings.compactHeight, 64)
                )
            }
            if activity.glance != nil {
                return NSSize(
                    width: max(settings.compactWidth, 310),
                    height: max(settings.compactHeight, 48)
                )
            }
            return NSSize(width: settings.compactWidth, height: settings.compactHeight)
        case .expanded:
            if isShowingCodingSection {
                return NSSize(
                    width: max(settings.expandedWidth, NotchSettings.codingExpandedWidth),
                    height: max(settings.expandedHeight, NotchSettings.codingExpandedHeight)
                )
            }
            return NSSize(width: settings.expandedWidth, height: settings.expandedHeight)
        case .fileDrop, .success:
            return NSSize(width: NotchSettings.dragWidth, height: NotchSettings.dragHeight)
        }
    }

    func hoverChanged(_ hovering: Bool) {
        collapseWorkItem?.cancel()
        guard !isDraggingFileOver else { return }
        guard mode != .fileDrop, mode != .success else { return }
        guard settings.expandOnHover else { return }
        if hovering {
            if mode == .compact {
                expand(
                    section: compactDestination,
                    preferSelectedSection: activity.glance != nil
                )
            }
        } else if !isPinned {
            scheduleCollapse()
        }
    }

    func notchClicked() {
        guard settings.expandOnClick else { return }
        collapseWorkItem?.cancel()
        switch mode {
        case .expanded:
            isPinned.toggle()
            if !isPinned { scheduleCollapse() }
        case .compact:
            expand(
                section: compactDestination,
                pin: true,
                preferSelectedSection: activity.glance != nil
            )
        case .fileDrop, .success:
            break
        }
    }

    func expand(
        section: NotchSection? = nil,
        pin: Bool = false,
        preferSelectedSection: Bool = false
    ) {
        collapseWorkItem?.cancel()
        if preferSelectedSection {
            expandedSectionOverride = section
        } else if mode != .expanded {
            expandedSectionOverride = nil
        }
        if let section { selectedSection = section }
        if pin { isPinned = true }
        guard mode != .expanded else { return }
        mode = .expanded
        onPanelConfigurationChanged?()
    }

    func collapse(force: Bool = false) {
        collapseWorkItem?.cancel()
        guard force || !isDraggingFileOver else { return }
        guard force || !isPinned else { return }
        isPinned = false
        expandedSectionOverride = nil
        guard mode != .compact else { return }
        mode = .compact
        onPanelConfigurationChanged?()
    }

    func closeFromOutsideClick() {
        guard mode != .compact, mode != .fileDrop, mode != .success, isPinned else { return }
        collapse(force: true)
    }

    func showShelf(pin: Bool = false) {
        let removedCount = shelf.removeMissingFiles()
        if removedCount > 0 {
            showMessage(removedCount == 1 ? "Removed 1 missing file" : "Removed \(removedCount) missing files")
        }
        guard !shelf.items.isEmpty else {
            collapse(force: true)
            return
        }
        collapseWorkItem?.cancel()
        if pin { isPinned = true }
        selectedSection = .shelf
        expandedSectionOverride = .shelf
        guard mode != .expanded else { return }
        mode = .expanded
        onPanelConfigurationChanged?()
    }

    func fileDropTargetChanged(_ isTargeted: Bool) {
        guard isDraggingFileOver != isTargeted else { return }
        dropExitWorkItem?.cancel()
        isDraggingFileOver = isTargeted

        if isTargeted {
            collapseWorkItem?.cancel()
            successWorkItem?.cancel()
            guard mode != .fileDrop else { return }
            if mode != .success {
                modeBeforeFileDrop = mode
            }
            mode = .fileDrop
            onPanelConfigurationChanged?()
            return
        }

        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.isDraggingFileOver, self.mode == .fileDrop else { return }
            self.restoreModeAfterFileDrop()
        }
        dropExitWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    @discardableResult
    func handleFileDrop(_ urls: [URL]) -> Bool {
        dropExitWorkItem?.cancel()
        isDraggingFileOver = false

        let result = shelf.add(urls)
        guard result.addedCount > 0 else {
            if result.capacityRejectedCount > 0 || shelf.items.count == shelf.maxItems {
                showMessage("Shelf is full")
            } else {
                showMessage("This item cannot be added")
            }
            restoreModeAfterFileDrop()
            return false
        }

        successWorkItem?.cancel()
        successWorkItem = nil
        isPinned = true
        selectedSection = .shelf
        expandedSectionOverride = .shelf
        mode = .expanded
        onPanelConfigurationChanged?()
        if result.capacityRejectedCount > 0 {
            showMessage("Shelf is full")
        } else {
            showMessage(result.addedCount == 1 ? "Added to shelf" : "Added \(result.addedCount) files")
        }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        return true
    }

    func removeShelfItem(_ item: ShelfItem) {
        shelf.remove(item)
        shelfDidChange()
    }

    func clearShelf() {
        shelf.clear()
        shelfDidChange()
    }

    func removeMissingShelfFiles() {
        let removedCount = shelf.removeMissingFiles()
        guard removedCount > 0 else { return }
        showMessage(removedCount == 1 ? "Removed 1 missing file" : "Removed \(removedCount) missing files")
        shelfDidChange()
    }

    func completeOnboarding() {
        defaults.set(true, forKey: "virtualNotch.didCompleteOnboarding")
        isPinned = false
        selectedSection = compactDestination
        collapse(force: true)
    }

    func startTimer(minutes: Int) {
        timer.start(minutes: minutes)
        isPinned = false
        showMessage("Timer started · \(minutes) min")
        collapse(force: true)
    }

    func startCustomTimer() {
        startTimer(minutes: customTimerMinutes)
    }

    func copyClipboardItem(_ item: ClipboardItem) {
        clipboard.copy(item)
        showMessage("Copied")
        isPinned = false
        collapse(force: true)
    }

    func showMessage(_ message: String) {
        messageWorkItem?.cancel()
        transientMessage = message
        let work = DispatchWorkItem { [weak self] in self?.transientMessage = nil }
        messageWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: work)
    }

    func setVisible(_ visible: Bool) {
        settings.isEnabled = visible
        onVisibilityChanged?(visible)
    }

    func resetSettings() {
        settings = .default
        settingsError = nil
    }

    private func scheduleCollapse() {
        let work = DispatchWorkItem { [weak self] in self?.collapse() }
        collapseWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + settings.collapseDelay, execute: work)
    }

    private var isShowingCodingSection: Bool {
        if expandedSectionOverride != nil {
            return expandedSectionOverride == .activity
        }
        return activeMediaSource == nil && selectedSection == .activity
    }

    private func restoreModeAfterFileDrop() {
        mode = modeBeforeFileDrop == .expanded && isPinned ? .expanded : .compact
        if mode == .compact { isPinned = false }
        onPanelConfigurationChanged?()
    }

    private func shelfDidChange() {
        onPanelConfigurationChanged?()
    }

    private func handleTimerCompletion() {
        if settings.timerNotificationsEnabled {
            NotificationService.shared.timerFinished()
        }
        transientMessage = "Timer complete"
        expand(section: .timer, pin: true, preferSelectedSection: true)
    }

    private func applyLaunchAtLoginIfNeeded(oldValue: Bool) {
        guard settings.launchAtLogin != oldValue, !isApplyingLoginSetting else { return }
        do {
            try LaunchAtLoginService.setEnabled(settings.launchAtLogin)
            settingsError = nil
        } catch {
            isApplyingLoginSetting = true
            settings.launchAtLogin = oldValue
            isApplyingLoginSetting = false
            settingsError = "Launch at login could not be changed: \(error.localizedDescription)"
        }
    }
}
