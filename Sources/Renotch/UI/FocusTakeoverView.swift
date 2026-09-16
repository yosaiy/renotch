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

    private static let quotes = [
        "进入专注状态",
        "保持专注，持续推进",
        "留出时间，专心做好一件事。",
        "减少干扰，让注意力回到当下。",
        "暂时放下无尽的信息流"
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

    // MARK: - Ambient Aura Layer

    private var ambientAuraLayer: some View {
        ZStack {
            // Top Left Magenta/Pink Aura
            Circle()
                .fill(Color(red: 0.85, green: 0.18, blue: 0.52).opacity(0.24))
                .frame(width: 520, height: 520)
                .offset(x: -120, y: -260)
                .blur(radius: 95)

            // Top Right Cyan/Teal Aura
            Circle()
                .fill(Color(red: 0.12, green: 0.68, blue: 0.68).opacity(0.22))
                .frame(width: 540, height: 540)
                .offset(x: 140, y: -260)
                .blur(radius: 95)

            // Center Blue Button Aura
            Circle()
                .fill(Color(red: 0.08, green: 0.52, blue: 1.0).opacity(0.24))
                .frame(width: 440, height: 260)
                .offset(y: 180)
                .blur(radius: 80)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Center Content (No Box Card)

    private var centerContent: some View {
        VStack(spacing: 0) {
            // Main Headline
            Text("深度专注时段")
                .font(.system(size: 34, weight: .bold, design: .default))
                .foregroundStyle(.white)
                .tracking(-0.4)

            // Blocked Site Subtitle
            HStack(spacing: 4) {
                Text("当前网站")
                    .foregroundStyle(.white.opacity(0.6))

                Text(site.isEmpty ? "干扰内容" : site)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text("已被屏蔽")
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
            Text("\(timer.currentMode.title)剩余时间")
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
                        .foregroundStyle(.white)

                    Text("关闭标签页，继续专注")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)

                    Text("⌘W")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.22))
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color(red: 0.08, green: 0.54, blue: 1.0))
                        .shadow(color: Color(red: 0.08, green: 0.54, blue: 1.0).opacity(0.55), radius: 18, y: 6)
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.25), lineWidth: 0.8)
                )
            }
            .buttonStyle(TactileAppleButtonStyle())

            Text("按 ⌘W 或点击关闭标签页")
                .font(.system(size: 11.5, weight: .regular))
                .foregroundStyle(.white.opacity(0.45))
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
