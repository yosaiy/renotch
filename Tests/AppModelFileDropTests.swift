import AppKit
import Foundation

/// Covers AppModel file drop state transitions:
/// success entry, timed dismissal to compact, cancellation by a new drag,
/// and previous-mode restoration for rejected drops.
@main
struct AppModelFileDropTests {
    @MainActor
    static func main() {
        var failures: [String] = []

        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            if !condition() { failures.append(message) }
        }

        /// Pumps the main run loop until the condition holds or the timeout
        /// elapses, so DispatchWorkItems scheduled on the main queue can fire.
        func waitUntil(
            timeout: TimeInterval = 2.0,
            _ condition: () -> Bool
        ) -> Bool {
            let deadline = Date().addingTimeInterval(timeout)
            while !condition() {
                if Date() >= deadline { return false }
                RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01))
            }
            return true
        }

        let defaultsSuiteName = "com.virtualnotch.tests.appmodel-filedrop"
        var tempFiles: [URL] = []
        defer {
            tempFiles.forEach { try? FileManager.default.removeItem(at: $0) }
            UserDefaults.standard.removePersistentDomain(forName: defaultsSuiteName)
        }

        func makeDefaults() -> UserDefaults {
            UserDefaults.standard.removePersistentDomain(forName: defaultsSuiteName)
            let defaults = UserDefaults(suiteName: defaultsSuiteName)!
            defaults.set(true, forKey: "virtualNotch.didCompleteOnboarding")
            return defaults
        }

        func makeModel() -> AppModel {
            let model = AppModel(defaults: makeDefaults())
            model.successDismissalDelay = 0.05
            return model
        }

        func makeTempFile() -> URL {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("virtualnotch-tests-\(UUID().uuidString)")
            let created = FileManager.default.createFile(atPath: url.path, contents: Data("shelf".utf8))
            expect(created, "test fixture file creation")
            tempFiles.append(url)
            return url
        }

        // MARK: - Successful drop enters .success mode

        do {
            let model = makeModel()
            expect(model.mode == .compact, "onboarded model starts compact")

            model.fileDropTargetChanged(true)
            expect(model.mode == .fileDrop, "drag targeting enters file drop mode")

            let accepted = model.handleFileDrop([makeTempFile()])
            expect(accepted, "successful drop is accepted")
            expect(model.mode == .success, "successful drop enters success mode")
            expect(!model.isPinned, "successful drop does not pin the notch")
            expect(model.selectedSection == .shelf, "successful drop selects the shelf section")
            expect(model.expandedSectionOverride == .shelf, "successful drop sets the shelf override")
            expect(model.shelf.items.count == 1, "dropped file lands on the shelf")
        }

        // MARK: - Success mode collapses to .compact after the dismissal delay

        do {
            let model = makeModel()
            model.fileDropTargetChanged(true)
            _ = model.handleFileDrop([makeTempFile()])
            expect(model.mode == .success, "success mode before dismissal")

            let collapsed = waitUntil { model.mode == .compact }
            expect(collapsed, "success state collapses after the dismissal delay")
            expect(!model.isPinned, "notch stays unpinned after dismissal")
            expect(model.expandedSectionOverride == nil, "section override clears on dismissal")
            expect(!model.isDraggingFileOver, "drag state clears after dismissal")
        }

        // MARK: - A new drag during .success cancels the pending collapse

        do {
            let model = makeModel()
            model.fileDropTargetChanged(true)
            _ = model.handleFileDrop([makeTempFile()])
            expect(model.mode == .success, "success mode before second drag")

            model.fileDropTargetChanged(true)
            expect(model.mode == .fileDrop, "second drag re-enters file drop mode")

            // Pump well past the dismissal delay; the cancelled work item must not fire.
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.2))
            expect(model.mode == .fileDrop, "cancelled dismissal does not collapse during a new drag")
            expect(model.isDraggingFileOver, "drag targeting stays active")
        }

        // MARK: - Drag exit after a successful drop does not stick in .fileDrop

        do {
            let model = makeModel()
            model.fileDropTargetChanged(true)
            _ = model.handleFileDrop([makeTempFile()])
            model.fileDropTargetChanged(true)
            expect(model.mode == .fileDrop, "second drag enters file drop mode")

            model.fileDropTargetChanged(false)
            let restored = waitUntil { model.mode == .compact }
            expect(restored, "drag exit after a successful drop restores compact mode")
        }

        // MARK: - Rejected drop (empty URLs) restores the previous mode

        do {
            let model = makeModel()
            model.fileDropTargetChanged(true)
            expect(model.mode == .fileDrop, "file drop mode before rejected drop")

            let accepted = model.handleFileDrop([])
            expect(!accepted, "empty drop is rejected")
            expect(model.mode == .compact, "rejected drop restores compact mode")
            expect(!model.isPinned, "rejected drop leaves the notch unpinned")
            expect(model.shelf.items.isEmpty, "rejected drop leaves the shelf empty")
            expect(model.transientMessage == "This item cannot be added", "rejected drop shows the invalid item message")
        }

        do {
            let model = makeModel()
            model.expand(section: .music, pin: true)
            expect(model.mode == .expanded, "pinned expanded mode before rejected drop")
            expect(model.isPinned, "notch pinned before rejected drop")

            model.fileDropTargetChanged(true)
            let accepted = model.handleFileDrop([])
            expect(!accepted, "empty drop is rejected from expanded state")
            expect(model.mode == .expanded, "rejected drop restores pinned expanded mode")
            expect(model.isPinned, "rejected drop keeps the notch pinned")
        }

        // MARK: - Rejected drop (full shelf) restores the previous mode

        do {
            let model = makeModel()
            let filler = (0..<model.shelf.maxItems).map { _ in makeTempFile() }
            model.shelf.add(filler)
            expect(model.shelf.items.count == model.shelf.maxItems, "shelf filled to capacity")

            model.fileDropTargetChanged(true)
            expect(model.mode == .fileDrop, "file drop mode before capacity rejection")

            let accepted = model.handleFileDrop([makeTempFile()])
            expect(!accepted, "drop into a full shelf is rejected")
            expect(model.mode == .compact, "capacity rejection restores compact mode")
            expect(!model.isPinned, "capacity rejection leaves the notch unpinned")
            expect(model.shelf.items.count == model.shelf.maxItems, "shelf stays at capacity")
            expect(model.transientMessage == "Shelf is full", "capacity rejection shows the full message")
        }

        // MARK: - Default compact view expands to configured section on hover and click

        do {
            let model = makeModel()
            var settings = model.settings
            settings.compactContent = .shelf
            model.settings = settings
            expect(model.selectedSection == .shelf, "setting compactContent to shelf updates selectedSection in compact mode")

            model.hoverChanged(true)
            expect(model.mode == .expanded, "hover expands compact notch")
            expect(model.selectedSection == .shelf, "hover expands to configured shelf section")

            model.collapse(force: true)
            expect(model.mode == .compact, "collapse restores compact mode")

            model.notchClicked()
            expect(model.mode == .expanded, "click expands compact notch")
            expect(model.selectedSection == .shelf, "click expands to configured shelf section")
        }

        if failures.isEmpty {
            print("All AppModel tests passed.")
        } else {
            failures.forEach { fputs("FAIL: \($0)\n", stderr) }
            exit(1)
        }
    }
}
