import SwiftUI

struct CompactActivityGlanceView: View {
    let glance: DeveloperActivityGlance

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(glance.kind.tint.opacity(0.14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(glance.kind.tint.opacity(0.16), lineWidth: 0.7)
                    }
                Image(systemName: glance.kind.symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(glance.kind.tint)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(glance.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(glance.subtitle)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(Color.notchMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 6)

            HStack(spacing: 5) {
                ActivityStateDot(state: glance.state)
                Text(glance.state == .success ? "DONE" : "LIVE")
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundStyle(glance.state.tint)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(glance.title), \(glance.subtitle)")
    }
}
