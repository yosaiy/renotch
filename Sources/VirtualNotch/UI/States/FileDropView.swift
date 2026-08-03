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

            Text("Drop to Shelf")
                .font(.system(size: 14, weight: .semibold))

            Text("Files stay on this Mac and are not copied")
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
