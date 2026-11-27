import AppKit
import SwiftUI

struct FocusTakeoverView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var timer: TimerService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let site: String
    let appName: String

    @State private var randomQuoteIndex = 0
    @State private var keyMonitor: Any?
    @State private var isVisible = false
    @State private var isCloseHovered = false

    private static let quotes = [
        "Lock in twin",
        "Stay focused and keep going.",
        "Deep work is the superpower of the 21st century.",
        "Starve your distractions, feed your focus.",
        "No more brainrot"
    ]

    var body: some View {
        ZStack {
            // Solid Dark Base Layer (completely blocks underlying website)
            Color.black
                .ignoresSafeArea()

            // Ambient Backdrop Glows
            ambientAuraLayer

            // Main Content Layout
            VStack(spacing: 0) {
                Spacer()

                // Center Content (Headline, Clock, Quote, and Action Button)
                centerContent
                    .offset(y: isVisible ? 0 : (reduceMotion ? 0 : 8))
                    .opacity(isVisible ? 1.0 : 0.0)

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(isVisible ? 1.0 : 0.0)
        .onAppear {
            randomQuoteIndex = Int.random(in: 0..<Self.quotes.count)
            setupKeyboardMonitor()
            if reduceMotion {
                isVisible = true
            } else {
                withAnimation(.spring(response: 0.36, dampingFraction: 1.0)) {
                    isVisible = true
                }
            }
        }
        .onDisappear {
            if let keyMonitor {
                NSEvent.removeMonitor(keyMonitor)
            }
        }
    }

    // MARK: - Ambient Backdrop Layer

    private var ambientAuraLayer: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.07, blue: 0.06),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Rectangle()
                .fill(Color.notchAccent.opacity(0.35))
                .frame(height: 2)
                .ignoresSafeArea(edges: .top)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Center Content (No Box Card)

    private var centerContent: some View {
        VStack(spacing: 0) {
            // Main Headline
            Text("Deep Work Session")
                .font(.system(size: 34, weight: .bold, design: .default))
                .foregroundStyle(.white)
                .tracking(-0.4)

            // Blocked Site Subtitle
            HStack(spacing: 4) {
                Text("Access to")
                    .foregroundStyle(.white.opacity(0.6))

                Text(site.isEmpty ? "Distraction" : site)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text("is blocked")
                    .foregroundStyle(.white.opacity(0.6))
            }
            .font(.system(size: 16, weight: .regular))
            .padding(.top, 8)

            // Big Digital Timer Clock
            Text(timer.isActive ? TimerService.formatted(timer.remaining) : "25:00")
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .tracking(-1.2)
                .padding(.top, 24)

            // Mode indicator
            Text("remaining in \(timer.currentMode.title)")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.top, 4)

            // Quote text
            Text(Self.quotes[randomQuoteIndex])
                .font(.system(size: 14.5, weight: .regular))
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 460)
                .padding(.top, 28)

            // Action Button directly under quotes
            actionButtonGroup
                .padding(.top, 32)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Action Button Group

    private var actionButtonGroup: some View {
        VStack(spacing: 10) {
            Button {
                model.closeTabAndResume()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.black.opacity(0.85))

                    Text("Close Tab & Return to Focus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)

                    Text("⌘W")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black.opacity(0.78))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(isCloseHovered ? 1.0 : 0.92))
                )
            }
            .buttonStyle(TactileAppleButtonStyle())
            .onHover { isCloseHovered = $0 }
            .animation(.easeOut(duration: 0.14), value: isCloseHovered)

            Text("Press ⌘W or click to close tab")
                .font(.system(size: 11.5, weight: .regular))
                .foregroundStyle(Color.notchMuted)
        }
    }

    // MARK: - Keyboard Handling

    private func setupKeyboardMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let key = event.charactersIgnoringModifiers?.lowercased()
            if event.modifierFlags.contains(.command) && key == "w" {
                // Cmd+W
                Task { @MainActor in
                    model.closeTabAndResume()
                }
                return nil
            }
            return event
        }
    }
}

// MARK: - Tactile Press Button Style

struct TactileAppleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.82), value: configuration.isPressed)
    }
}
