import AppKit
import SwiftUI

struct QuickActionsView: View {
    @EnvironmentObject private var model: AppModel

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 6),
        count: 6
    )

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ActionTile(title: "Finder", icon: "face.smiling") {
                NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory()))
            }
            ActionTile(title: "Downloads", icon: "arrow.down.circle") {
                openDirectory(.downloadsDirectory)
            }
            ActionTile(title: "Screenshots", icon: "camera.viewfinder") {
                openScreenshots()
            }
            ActionTile(title: "Focus 25m", icon: "timer", tint: .notchAccent) {
                model.startTimer(minutes: 25)
            }
            ActionTile(title: "Clear", icon: "trash") {
                model.clipboard.clear()
                model.showMessage("Clipboard cleared")
            }
            ActionTile(title: "Settings", icon: "gearshape") {
                AppDelegate.shared?.openSettings()
            }
        }
        .padding(.vertical, 8)
    }

    private func openDirectory(_ directory: FileManager.SearchPathDirectory) {
        if let url = FileManager.default.urls(for: directory, in: .userDomainMask).first {
            NSWorkspace.shared.open(url)
        }
    }

    private func openScreenshots() {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        if let desktop { NSWorkspace.shared.open(desktop) }
    }
}

private struct ActionTile: View {
    let title: String
    let icon: String
    var tint: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 9, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(Color.white.opacity(0.055), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
