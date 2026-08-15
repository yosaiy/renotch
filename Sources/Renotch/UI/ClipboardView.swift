import SwiftUI

struct ClipboardView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var clipboard: ClipboardService

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Recent copies")
                    .font(.system(size: 12, weight: .semibold))
                Text("\(clipboard.items.count)/20")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if !clipboard.items.isEmpty {
                    Button("Clear all", role: .destructive) { clipboard.clear() }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.red.opacity(0.9))
                }
            }

            if clipboard.items.isEmpty {
                VStack(spacing: 5) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(Color.notchMuted)
                    Text("Copied text will appear here")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 5) {
                        ForEach(clipboard.items) { item in
                            ClipboardRow(item: item)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

private struct ClipboardRow: View {
    @EnvironmentObject private var model: AppModel
    let item: ClipboardItem

    var body: some View {
        HStack(spacing: 8) {
            Button {
                model.copyClipboardItem(item)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.notchAccent)
                    Text(item.content.replacingOccurrences(of: "\n", with: " "))
                        .font(.system(size: 10))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                    Text(item.createdAt, style: .relative)
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                model.clipboard.delete(item)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.055))
        )
    }
}
