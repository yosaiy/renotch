import AppKit
import SwiftUI

private enum NotchDropTypes {
    static let promisedFiles = NSFilePromiseReceiver.readableDraggedTypes.map {
        NSPasteboard.PasteboardType($0)
    }
    static let images: [NSPasteboard.PasteboardType] = [
        .png,
        .tiff,
        NSPasteboard.PasteboardType("public.jpeg"),
        NSPasteboard.PasteboardType("public.heic")
    ]
    static let all = [.fileURL] + promisedFiles + images
}

/// AppKit owns drag routing for non-activating panels. Registering the hosting
/// view directly makes Finder file drags reliable even when SwiftUI's typed
/// drop destination is not activated for the panel.
final class NotchHostingView<Content: View>: NSHostingView<Content> {
    var onFileDragTargetChanged: ((Bool) -> Void)?
    var onFileDrop: (([URL]) -> Bool)?

    private let filePromiseQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "VirtualNotch.FilePromises"
        queue.maxConcurrentOperationCount = 2
        return queue
    }()
    private let materializedDropDirectory: URL

    required init(rootView: Content) {
        materializedDropDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VirtualNotchDrops", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        super.init(rootView: rootView)
        try? FileManager.default.createDirectory(
            at: materializedDropDirectory,
            withIntermediateDirectories: true
        )
        registerForDraggedTypes(NotchDropTypes.all)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard supportsDrop(from: sender.draggingPasteboard) else { return [] }
        activateDropTarget()
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard supportsDrop(from: sender.draggingPasteboard) else { return [] }
        activateDropTarget()
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        // Drag exit is sync — let AppModel debounce with its own timer if needed.
        // This avoids race between host (0.3s) and AppModel (0.15s) timers.
        onFileDragTargetChanged?(false)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let supported = supportsDrop(from: sender.draggingPasteboard)
        if supported { activateDropTarget() }
        return supported
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard

        let urls = fileURLs(from: pasteboard)
        if !urls.isEmpty {
            let accepted = onFileDrop?(urls) ?? false
            onFileDragTargetChanged?(false)
            return accepted
        }

        if receivePromisedFiles(from: pasteboard) {
            onFileDragTargetChanged?(false)
            return true
        }

        if let imageURL = materializeImage(from: pasteboard) {
            let accepted = onFileDrop?([imageURL]) ?? false
            onFileDragTargetChanged?(false)
            return accepted
        }

        onFileDragTargetChanged?(false)
        _ = onFileDrop?([])
        return false
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        onFileDragTargetChanged?(false)
    }

    private func activateDropTarget() {
        onFileDragTargetChanged?(true)
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

    private func supportsDrop(from pasteboard: NSPasteboard) -> Bool {
        if !fileURLs(from: pasteboard).isEmpty { return true }

        let availableTypes = Set(pasteboard.types ?? [])
        return NotchDropTypes.promisedFiles.contains { availableTypes.contains($0) }
            || NotchDropTypes.images.contains { availableTypes.contains($0) }
    }

    private func receivePromisedFiles(from pasteboard: NSPasteboard) -> Bool {
        let receivers = pasteboard.readObjects(
            forClasses: [NSFilePromiseReceiver.self],
            options: nil
        ) as? [NSFilePromiseReceiver] ?? []
        guard !receivers.isEmpty else { return false }

        for receiver in receivers {
            receiver.receivePromisedFiles(
                atDestination: materializedDropDirectory,
                options: [:],
                operationQueue: filePromiseQueue
            ) { [weak self] url, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    guard error == nil else {
                        _ = self.onFileDrop?([])
                        return
                    }
                    _ = self.onFileDrop?([url])
                }
            }
        }
        return true
    }

    private func materializeImage(from pasteboard: NSPasteboard) -> URL? {
        for type in NotchDropTypes.images {
            guard let data = pasteboard.data(forType: type) else { continue }
            let fileExtension: String
            switch type {
            case .png: fileExtension = "png"
            case .tiff: fileExtension = "tiff"
            case NSPasteboard.PasteboardType("public.heic"): fileExtension = "heic"
            default: fileExtension = "jpg"
            }

            let destination = materializedDropDirectory
                .appendingPathComponent("Dropped Image \(UUID().uuidString)")
                .appendingPathExtension(fileExtension)
            guard (try? data.write(to: destination, options: .atomic)) != nil else {
                return nil
            }
            return destination
        }
        return nil
    }
}
