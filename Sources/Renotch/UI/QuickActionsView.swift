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
            ActionTile(title: "Face ID", icon: "faceid", tint: .notchAccent) {
                withAnimation(DynamicNotchSprings.fluidCollapse) {
                    model.collapse(force: true)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    model.triggerFaceIDGlance()
                }
            }
            ActionTile(title: "Focus 25m", icon: "timer", tint: .notchAccent) {
                model.startTimer(minutes: 25, mode: .focus)
            }
            ActionTile(title: "Finder", icon: "face.smiling") {
                NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory()))
            }
            ActionTile(title: "Downloads", icon: "arrow.down.circle") {
                openDirectory(.downloadsDirectory)
            }
            ActionTile(title: "Screenshots", icon: "camera.viewfinder") {
                openScreenshots()
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
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.white.opacity(isHovering ? 0.11 : 0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(Color.white.opacity(isHovering ? 0.14 : 0.055), lineWidth: 1)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(NotchPressButtonStyle())
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.14), value: isHovering)
        .accessibilityLabel(title)
    }
}
