import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                NotchIcon(size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Meet your developer activity notch")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("Local servers, builds, containers, Git, and terminal activity—one hover away.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                WelcomeFeature(icon: "network", title: "Local servers")
                WelcomeFeature(icon: "hammer.fill", title: "Builds")
                WelcomeFeature(icon: "shippingbox.fill", title: "Containers")
            }

            HStack {
                Toggle("Expand on hover", isOn: $model.settings.expandOnHover)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .font(.system(size: 11))
                Spacer()
                Button("Get started") { model.completeOnboarding() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.notchAccent)
                    .foregroundStyle(.black)
                    .controlSize(.small)
            }
        }
    }
}

private struct WelcomeFeature: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(Color.notchAccent)
            Text(title)
                .foregroundStyle(.white.opacity(0.82))
        }
        .font(.system(size: 10, weight: .medium))
        .frame(maxWidth: .infinity)
        .frame(height: 42)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }
}
