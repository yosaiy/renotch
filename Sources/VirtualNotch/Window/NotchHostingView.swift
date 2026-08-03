import AppKit
import SwiftUI

/// AppKit owns drag routing for non-activating panels. Registering the hosting
/// view directly makes Finder file drags reliable even when SwiftUI's typed
/// drop destination is not activated for the panel.
final class NotchHostingView<Content: View>: NSHostingView<Content> {
    var onFileDragTargetChanged: ((Bool) -> Void)?
    var onFileDrop: (([URL]) -> Bool)?

    required init(rootView: Content) {
        super.init(rootView: rootView)
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard !fileURLs(from: sender.draggingPasteboard).isEmpty else { return [] }
        onFileDragTargetChanged?(true)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard !fileURLs(from: sender.draggingPasteboard).isEmpty else { return [] }
        onFileDragTargetChanged?(true)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onFileDragTargetChanged?(false)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        !fileURLs(from: sender.draggingPasteboard).isEmpty
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = fileURLs(from: sender.draggingPasteboard)
        guard !urls.isEmpty else {
            onFileDragTargetChanged?(false)
            return false
        }

        let accepted = onFileDrop?(urls) ?? false
        onFileDragTargetChanged?(false)
        return accepted
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        onFileDragTargetChanged?(false)
    }

    private func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
        let objects = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) ?? []

        return objects.compactMap { object in
            guard let url = object as? NSURL else { return nil }
            return url as URL
        }
    }
}
