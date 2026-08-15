import AppKit
import QuickLookThumbnailing
import SwiftUI

struct FileShelfView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var shelf: ShelfStore

    var body: some View {
        VStack(spacing: 4) {
            header

            if shelf.items.isEmpty {
                emptyShelf
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(shelf.items) { item in
                            ShelfItemView(item: item) {
                                model.removeShelfItem(item)
                            }
                            .transition(.scale(scale: 0.84).combined(with: .opacity))
                        }
                    }
                }
            }
        }
        .padding(.top, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.3, dampingFraction: 0.82), value: shelf.items)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "tray.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.notchAccent)

            Text("File Shelf")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)

            Text(model.transientMessage ?? "\(shelf.items.count) / \(shelf.maxItems)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(model.transientMessage == nil ? Color.notchMuted : Color.notchAccent)
                .lineLimit(1)

            Spacer(minLength: 4)

            shelfButton(title: "Clear", icon: "trash") {
                model.clearShelf()
            }
            .disabled(shelf.items.isEmpty)
        }
        .padding(.bottom, 2)
    }

    private var emptyShelf: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.notchAccent.opacity(0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.notchAccent.opacity(0.35), lineWidth: 1)
                    )
                    .frame(width: 48, height: 48)

                Image(systemName: "tray")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color.notchAccent)
            }

            VStack(spacing: 4) {
                Text("Shelf is empty")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)

                Text("Drag files onto the notch to add them")
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(Color.notchMuted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(Color.white.opacity(0.12))
        )
    }

    private func shelfButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .labelStyle(.iconOnly)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.white.opacity(0.07)))
        }
        .buttonStyle(.plain)
        .help(title)
    }
}

private struct ShelfItemView: View {
    let item: ShelfItem
    let remove: () -> Void

    var body: some View {
        VStack(spacing: 3) {
            ZStack(alignment: .topTrailing) {
                ShelfThumbnailView(item: item)
                    .frame(width: 32, height: 32)
                    .opacity(item.isAvailable ? 1 : 0.38)

                if !item.isAvailable {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.orange)
                        .background(Circle().fill(.black))
                        .offset(x: 4, y: -3)
                }
            }

            Text(item.displayName)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(item.isAvailable ? .white : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 76)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.white.opacity(0.055))
        )
        .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.displayName)
        .accessibilityValue(item.isAvailable ? "Available" : "File is no longer available")
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
