import AppKit
import SwiftUI

@MainActor
final class NotchWindowController: NSWindowController {
    private let model: AppModel
    private let screenManager: ScreenManager
    private var outsideClickMonitor: Any?

    init(model: AppModel, screenManager: ScreenManager) {
        self.model = model
        self.screenManager = screenManager

        let size = Self.panelSize(for: model.settings)
        let panel = NotchPanel(contentRect: NSRect(origin: .zero, size: size))
        super.init(window: panel)

        let hostingView = NotchHostingView(
            rootView: NotchView()
                .environment(\.locale, Locale(identifier: "zh_CN"))
                .environmentObject(model)
        )
        hostingView.sizingOptions = []
        hostingView.onFileDragTargetChanged = { [weak model] isTargeted in
            model?.fileDropTargetChanged(isTargeted)
        }
        hostingView.onFileDrop = { [weak model] urls in
            model?.handleFileDrop(urls) ?? false
        }
        panel.contentView = hostingView

        model.onPanelConfigurationChanged = { [weak self] in
            self?.applyConfiguration(animated: true)
        }
        model.onVisibilityChanged = { [weak self] visible in
            visible ? self?.show() : self?.hide()
        }
        screenManager.onScreensChanged = { [weak self] in
            self?.applyConfiguration(animated: false)
        }

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            Task { @MainActor in self?.handleGlobalClick(event) }
        }
        applyConfiguration(animated: false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
    }

    func show() {
        guard model.settings.isEnabled else { return }
        applyConfiguration(animated: false)
        window?.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }

    func restart() {
        hide()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in self?.show() }
    }

    func applyConfiguration(animated: Bool) {
        screenManager.configure(followsForeground: model.settings.followForegroundWindow == true)
        guard let panel = window as? NotchPanel,
              let screen = screenManager.screen(for: model.settings.targetDisplayID) else { return }

        if model.mode == .focusTakeover {
            panel.level = .screenSaver
            let behavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
            panel.collectionBehavior = behavior
            let frame = screen.frame

            panel.orderFrontRegardless()
            panel.makeKey()

            if panel.frame != frame {
                panel.setFrame(frame, display: true)
            }
            return
        }

        panel.level = model.settings.alwaysOnTop ? .statusBar : .floating
        var behavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces, .stationary]
        if model.settings.showOnFullscreen { behavior.insert(.fullScreenAuxiliary) }
        panel.collectionBehavior = behavior

        let size = Self.panelSize(for: model.settings)
        let frame = NSRect(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - size.height - model.settings.verticalOffset,
            width: size.width,
            height: size.height
        )

        // Keep the transparent host panel stable while the visible SwiftUI
        // notch animates inside it. Resizing the destination window during an
        // active Finder drag can emit a false draggingExited event.
        guard panel.frame != frame else { return }

        // If transitioning from a fullscreen/takeover frame, snap directly without shrink animation
        if panel.frame.width > size.width * 1.2 || panel.frame.height > size.height * 1.2 {
            panel.setFrame(frame, display: true)
            return
        }

        guard animated,
              panel.isVisible,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            panel.setFrame(frame, display: true)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.32
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1)
            panel.animator().setFrame(frame, display: true)
        }
    }

    private func handleGlobalClick(_ event: NSEvent) {
        #if DEBUG
        if model.codex.isPreview { return }
        #endif
        guard let panel = window, panel.isVisible, model.isPinned, model.mode != .focusTakeover else { return }
        let notchSize = model.currentSize
        let visibleNotchFrame = NSRect(
            x: panel.frame.midX - notchSize.width / 2,
            y: panel.frame.maxY - notchSize.height,
            width: notchSize.width,
            height: notchSize.height
        )
        if !visibleNotchFrame.contains(NSEvent.mouseLocation) {
            model.closeFromOutsideClick()
        }
    }

    private static func panelSize(for settings: NotchSettings) -> NSSize {
        let notchHeightOffset: CGFloat = settings.isHardwareNotchSafeActive ? 26 : 0
        return NSSize(
            width: max(max(settings.compactWidth, settings.expandedWidth), NotchSettings.codexExpandedWidth)
                + NotchLayout.shadowHorizontalPadding * 2,
            height: max(
                max(settings.compactHeight, settings.expandedHeight + notchHeightOffset),
                max(NotchSettings.dragHeight, NotchSettings.codexExpandedHeight)
            )
                + NotchLayout.shadowBottomPadding
        )
    }
}
