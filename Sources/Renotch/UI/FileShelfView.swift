import AppKit
import QuickLookThumbnailing
import SwiftUI

struct FileShelfView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var shelf: ShelfStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isClearHovered = false

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.bottom, 6)

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            if shelf.items.isEmpty {
                emptyShelf
                    .padding(.top, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(shelf.items) { item in
                            ShelfItemCard(item: item) {
                                model.removeShelfItem(item)
                            }
                            .transition(reduceMotion ? .opacity : .scale(scale: 0.92).combined(with: .opacity))
                        }
                    }
                    .padding(.vertical, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
        .padding(.top, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.84), value: shelf.items)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Text("File Shelf")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)

            Text(model.transientMessage ?? "\(shelf.items.count) of \(shelf.maxItems)")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(model.transientMessage == nil ? Color.notchMuted : Color.notchAccent)
                .lineLimit(1)

            Spacer(minLength: 4)

            Button {
                model.clearShelf()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: 9, weight: .semibold))
                    Text("Clear")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(
                    shelf.items.isEmpty
                        ? Color.white.opacity(0.28)
                        : (isClearHovered ? Color.notchDanger : Color.notchMuted)
                )
                .padding(.horizontal, 7)
                .frame(height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            !shelf.items.isEmpty && isClearHovered
                                ? Color.notchDanger.opacity(0.14)
                                : Color.white.opacity(shelf.items.isEmpty ? 0.03 : 0.06)
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(NotchPressButtonStyle())
            .onHover { isClearHovered = $0 }
            .disabled(shelf.items.isEmpty)
            .help("Remove all pinned files")
            .accessibilityLabel("Clear file shelf")
        }
    }

    // MARK: - Asymmetric Empty Drop Zone

    private var emptyShelf: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.notchAccent.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.notchAccent.opacity(0.26), lineWidth: 0.8)
                    )
                Image(systemName: "tray.and.arrow.down")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.notchAccent)
            }
            .frame(width: 44, height: 44)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("Drop files onto the notch")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(.white)

                Text("Files are pinned by reference for quick drag-out and are never duplicated.")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(Color.notchMuted)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    Color.white.opacity(0.12),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                )
        )
    }
}

// MARK: - Shelf Item Tile

private struct ShelfItemCard: View {
    let item: ShelfItem
    let remove: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 9) {
            ZStack(alignment: .topTrailing) {
                ShelfThumbnailView(item: item)
                    .frame(width: 34, height: 34)
                    .opacity(item.isAvailable ? 1 : 0.38)

                if !item.isAvailable {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.orange)
                        .background(Circle().fill(.black))
                        .offset(x: 4, y: -3)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(item.isAvailable ? .white : Color.notchMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if isHovering {
                    HStack(spacing: 4) {
                        if item.isAvailable {
                            ShelfInlineAction(icon: "arrow.up.right", label: "Open \(item.displayName)") {
                                NSWorkspace.shared.open(item.url)
                            }
                            ShelfInlineAction(icon: "folder", label: "Reveal \(item.displayName) in Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([item.url])
                            }
                        }
                        ShelfInlineAction(icon: "xmark", label: "Remove \(item.displayName)", tint: Color.notchDanger) {
                            remove()
                        }
                    }
                } else {
                    Text(fileSubtitle)
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundStyle(Color.notchMuted)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .frame(width: 156, height: 56)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(isHovering ? 0.085 : 0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.white.opacity(isHovering ? 0.14 : 0.07), lineWidth: 0.7)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.14), value: isHovering)
        .onDrag {
            guard item.isAvailable else { return NSItemProvider() }
            return NSItemProvider(contentsOf: item.url) ?? NSItemProvider()
        }
        .contextMenu {
            Button("Open") { NSWorkspace.shared.open(item.url) }
                .disabled(!item.isAvailable)

            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            }
            .disabled(!item.isAvailable)

            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.url.path, forType: .string)
            }

            Divider()

            Button("Remove", role: .destructive, action: remove)
        }
        .help(item.isAvailable ? item.url.path : "File is no longer available")
        .accessibilityElement(children: .contain)
        .accessibilityLabel(item.displayName)
        .accessibilityValue(item.isAvailable ? "Available" : "File is no longer available")
    }

    private var fileSubtitle: String {
        guard item.isAvailable else { return "Missing" }
        let ext = item.url.pathExtension.uppercased()
        return ext.isEmpty ? "File" : ext
    }
}

private struct ShelfInlineAction: View {
    let icon: String
    let label: String
    var tint: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 18, height: 18)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.white.opacity(0.09))
                )
                .contentShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .buttonStyle(NotchPressButtonStyle())
        .help(label)
        .accessibilityLabel(label)
    }
}

private struct ShelfThumbnailView: View {
    let item: ShelfItem
    @State private var thumbnail: NSImage?

    private var fallbackIcon: NSImage {
        NSWorkspace.shared.icon(forFile: item.url.path)
    }

    var body: some View {
        Image(nsImage: thumbnail ?? fallbackIcon)
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .task(id: item.url) {
                thumbnail = await loadThumbnail()
            }
    }

    private func loadThumbnail() async -> NSImage? {
        guard item.isAvailable else { return nil }
        let request = QLThumbnailGenerator.Request(
            fileAt: item.url,
            size: CGSize(width: 72, height: 72),
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: .thumbnail
        )

        return await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
                continuation.resume(returning: representation?.nsImage)
            }
        }
    }
}
