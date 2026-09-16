import SwiftUI

struct FileDropView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isTargeted: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 26, weight: .semibold))
                .scaleEffect(reduceMotion ? 1 : (isTargeted ? 1.08 : 1))
                .animation(
                    reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.72),
                    value: isTargeted
                )

            Text("拖入暂存区")
                .font(.system(size: 14, weight: .semibold))

            Text("文件保留在这台 Mac 的原位置，不会复制")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isTargeted ? Color.white.opacity(0.09) : .clear)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    Color.white.opacity(isTargeted ? 0.28 : 0.12),
                    style: StrokeStyle(lineWidth: 1, dash: [5, 5])
                )
        }
        .padding(.horizontal, 28)
        .padding(.top, 18)
        .padding(.bottom, 22)
    }
}
