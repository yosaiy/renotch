import SwiftUI

struct CompactShelfView: View {
    @ObservedObject var shelf: ShelfStore

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "tray.full.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.notchAccent)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.notchAccent.opacity(0.12)))

            VStack(alignment: .leading, spacing: 1) {
                Text("\(shelf.items.count) 个文件")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                Text("点击或悬停查看暂存文件")
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(Color.notchMuted)
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
