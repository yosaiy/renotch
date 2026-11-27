import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var isContinueHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brandHeader

            VStack(alignment: .leading, spacing: 4) {
                Text("Your workspace, one glance away.")
                    .font(.system(size: 18, weight: .semibold))
                    .tracking(-0.45)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text("Servers, builds, and containers stay close without interrupting your flow.")
                    .font(.system(size: 10.5, weight: .regular))
                    .foregroundStyle(Color.notchMuted)
                    .lineLimit(1)
            }
            .padding(.top, 8)

            activityRail
                .padding(.top, 9)

            HStack(spacing: 12) {
                Toggle(isOn: $model.settings.expandOnHover) {
                    Text("Enlarge on hover")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.78))
                }
                .toggleStyle(.switch)
                .controlSize(.mini)

                Spacer(minLength: 8)

                Button {
                    model.completeOnboarding()
                } label: {
                    Text("Continue")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.9))
                        .padding(.horizontal, 14)
                        .frame(height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(isContinueHovered ? 1 : 0.92))
                        )
                }
                .buttonStyle(WelcomePrimaryButtonStyle())
                .onHover { isContinueHovered = $0 }
                .animation(.easeOut(duration: 0.16), value: isContinueHovered)
                .accessibilityHint("Finish setup and collapse Re:notch")
            }
            .padding(.top, 9)
        }
    }

    private var brandHeader: some View {
        HStack(spacing: 9) {
            ReNotchMark()

            VStack(alignment: .leading, spacing: 1) {
                Text("Re:notch")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(-0.2)
                    .foregroundStyle(.white.opacity(0.96))
                Text("Developer workspace")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Color.notchMuted)
            }

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(Color.notchAccent)
                    .frame(width: 5, height: 5)
                Text("Ready")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.76))
            }
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
        }
    }

    private var activityRail: some View {
        HStack(spacing: 0) {
            WelcomeSignal(icon: "network", title: "Servers")
            railDivider
            WelcomeSignal(icon: "hammer.fill", title: "Builds")
            railDivider
            WelcomeSignal(icon: "shippingbox.fill", title: "Containers")
        }
        .frame(height: 32)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(Color.white.opacity(0.075), lineWidth: 0.7)
                )
        )
    }

    private var railDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 1, height: 14)
    }
}

private struct ReNotchMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.075))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.09), lineWidth: 0.7)
                )

            VStack(spacing: 2.5) {
                Capsule()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 12, height: 4)
                Circle()
                    .fill(Color.notchAccent)
                    .frame(width: 3.5, height: 3.5)
            }
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }
}

private struct WelcomeSignal: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.notchAccent.opacity(0.9))
                .frame(width: 12)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.67))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct WelcomePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
