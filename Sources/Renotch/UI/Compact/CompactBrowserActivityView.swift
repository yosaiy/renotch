import AppKit
import SwiftUI

struct CompactBrowserMediaView: View {
    let media: BrowserMediaActivity
    let artwork: NSImage?
    @ObservedObject var timer: TimerService

    var body: some View {
        HStack(spacing: 9) {
            Group {
                if let artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        Color(red: 0.78, green: 0.05, blue: 0.08)
                        Image(systemName: "play.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(width: 24, height: 24)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(media.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Circle()
                        .fill(media.isPlaying ? Color.red : Color.white.opacity(0.35))
                        .frame(width: 5, height: 5)
                    Text(media.isPlaying ? media.channel : "Paused · \(media.channel)")
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(Color.notchMuted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            if timer.isActive {
                // Apple Dynamic Island Live Timer Pill
                HStack(spacing: 4.5) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.14), lineWidth: 1.5)
                        Circle()
                            .trim(from: 0, to: timer.progress)
                            .stroke(
                                timer.currentMode.tint,
                                style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.25), value: timer.progress)
                        Image(systemName: timer.isPaused ? "pause.fill" : timer.currentMode.icon)
                            .font(.system(size: 5.5, weight: .bold))
                            .foregroundStyle(timer.currentMode.tint)
                    }
                    .frame(width: 12, height: 12)

                    Text(TimerService.formatted(timer.remaining))
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(timer.currentMode.tint)
                        .fixedSize()
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(timer.currentMode.tint.opacity(0.12))
                )
                .overlay(
                    Capsule()
                        .stroke(timer.currentMode.tint.opacity(0.22), lineWidth: 0.5)
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .animation(.snappy(duration: 0.25), value: timer.isActive)
            } else {
                Image(systemName: media.isPlaying ? "waveform" : "pause.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(media.isPlaying ? Color.red : .secondary)
                    .frame(width: 22)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("YouTube, \(media.title), \(media.isPlaying ? "playing" : "paused")")
    }
}

struct ExpandedBrowserMediaView: View {
    let media: BrowserMediaActivity
    let artwork: NSImage?
    @State private var isOpenHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 14) {
                Group {
                    if let artwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        ZStack {
                            Color.white.opacity(0.06)
                            Image(systemName: "play.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color.musicAccent)
                        }
                    }
                }
                .frame(width: 112, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.7)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(media.isPlaying ? Color.musicAccent : Color.notchMuted)
                            .frame(width: 5, height: 5)
                            .accessibilityHidden(true)
                        Text("YouTube · \(media.isPlaying ? "Playing" : "Paused")")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(media.isPlaying ? Color.musicAccent : Color.notchMuted)
                    }

                    Text(media.title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(media.channel)
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(Color.notchMuted)
                            .lineLimit(1)

                        Spacer(minLength: 4)

                        if let pageURL = media.pageURL {
                            Button {
                                NSWorkspace.shared.open(pageURL)
                            } label: {
                                HStack(spacing: 4) {
                                    Text("Open video")
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 8, weight: .bold))
                                }
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundStyle(isOpenHovered ? .white : .white.opacity(0.84))
                                .padding(.horizontal, 8)
                                .frame(height: 22)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color.white.opacity(isOpenHovered ? 0.14 : 0.08))
                                )
                                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                            .buttonStyle(NotchPressButtonStyle())
                            .onHover { isOpenHovered = $0 }
                            .animation(.easeOut(duration: 0.14), value: isOpenHovered)
                            .accessibilityLabel("Open video in browser")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let progress = media.progress {
                HStack(spacing: 8) {
                    Text(formatted(media.position))
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(Color.white.opacity(0.1))
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(Color.musicAccent)
                                .frame(width: max(0, proxy.size.width * progress))
                        }
                    }
                    .frame(height: 3.5)
                    Text("−\(formatted(max(0, media.duration - media.position)))")
                }
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(Color.notchMuted)
                .monospacedDigit()
            }
        }
        .padding(.top, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func formatted(_ value: TimeInterval) -> String {
        let seconds = max(0, Int(value.rounded(.down)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

struct CompactBrowserDownloadView: View {
    let download: BrowserDownloadActivity

    var body: some View {
        HStack(spacing: 10) {
            downloadIndicator
                .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text(download.displayName)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(statusText)
                    .font(.system(size: 8.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.notchMuted)
                    .monospacedDigit()
                    .lineLimit(1)

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.1))
                        Capsule()
                            .fill(indicatorColor)
                            .frame(width: proxy.size.width * (download.progress ?? 0.12))
                    }
                }
                .frame(height: 3)
            }

            Spacer(minLength: 4)

            if let progress = download.progress, download.state == .inProgress {
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(download.displayName), \(statusText)")
    }

    private var downloadIndicator: some View {
        ZStack {
            Circle().fill(indicatorColor.opacity(0.13))
            Circle()
                .trim(from: 0, to: download.progress ?? 0.24)
                .stroke(indicatorColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.25), value: download.bytesReceived)
            Image(systemName: indicatorIcon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(indicatorColor)
        }
    }

    private var indicatorIcon: String {
        switch download.state {
        case .complete: return "checkmark"
        case .interrupted: return "exclamationmark"
        case .inProgress: return download.paused ? "pause.fill" : "arrow.down"
        }
    }

    private var indicatorColor: Color {
        switch download.state {
        case .complete: return Color.notchAccent
        case .interrupted: return .orange
        case .inProgress: return Color(red: 0.32, green: 0.68, blue: 1)
        }
    }

    private var statusText: String {
        switch download.state {
        case .complete: return "Download complete"
        case .interrupted: return "Download interrupted"
        case .inProgress:
            if download.paused { return "Paused · \(formattedBytes(download.bytesReceived))" }
            if download.totalBytes > 0 {
                return "\(formattedBytes(download.bytesReceived)) of \(formattedBytes(download.totalBytes))"
            }
            return "Downloading · \(formattedBytes(download.bytesReceived))"
        }
    }

    private func formattedBytes(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }
}
