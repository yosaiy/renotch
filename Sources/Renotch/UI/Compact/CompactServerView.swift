import SwiftUI

struct CompactServerView: View {
    @ObservedObject var service: DeveloperActivityService
    let message: String?

    var body: some View {
        let activity = service.primaryServerActivity
        return HStack(spacing: 9) {
            ZStack {
                Circle()
                    .fill(activity.kind.tint.opacity(0.14))
                ServerFaviconImage(
                    faviconData: activity.faviconData,
                    fallbackTint: activity.kind.tint,
                    size: 14
                )
            }
            .frame(width: 23, height: 23)

            VStack(alignment: .leading, spacing: 1) {
                Text(message ?? activity.title)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(message == nil ? .white : Color.notchAccent)
                    .lineLimit(1)
                Text(activity.subtitle)
                    .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.notchMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            HStack(spacing: 5) {
                ActivityStateDot(state: activity.state)
                Text(service.isRefreshing ? "SYNC" : activity.state.compactLabel)
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundStyle(service.isRefreshing ? Color.notchMuted : activity.state.tint)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(activity.title), \(activity.subtitle)")
    }
}
