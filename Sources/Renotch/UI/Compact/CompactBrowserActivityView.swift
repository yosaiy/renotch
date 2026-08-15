import AppKit
import SwiftUI

struct CompactBrowserMediaView: View {
    let media: BrowserMediaActivity
    let artwork: NSImage?

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

            Image(systemName: media.isPlaying ? "waveform" : "pause.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(media.isPlaying ? Color.red : .secondary)
                .frame(width: 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("YouTube, \(media.title), \(media.isPlaying ? "playing" : "paused")")
    }
}

struct ExpandedBrowserMediaView: View {
    let media: BrowserMediaActivity
    let artwork: NSImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 13) {
                Group {
                    if let artwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        ZStack {
                            Color(red: 0.78, green: 0.05, blue: 0.08)
                            Image(systemName: "play.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .frame(width: 104, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.7)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Image(systemName: "play.rectangle.fill")
                        Text("YOUTUBE")
                            .tracking(0.8)
                        Circle()
                            .fill(media.isPlaying ? Color.red : Color.white.opacity(0.35))
                            .frame(width: 4, height: 4)
                        Text(media.isPlaying ? "Playing" : "Paused")
                    }
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(media.isPlaying ? Color.red : Color.notchMuted)

                    Text(media.title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(media.channel)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.notchMuted)
                        .lineLimit(1)

                    if let pageURL = media.pageURL {
                        Button {
                            NSWorkspace.shared.open(pageURL)
                        } label: {
                            Label("Open video", systemImage: "arrow.up.right")
                                .font(.system(size: 8.5, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white.opacity(0.82))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let progress = media.progress {
                HStack(spacing: 8) {
                    Text(formatted(media.position))
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.1))
                            Capsule().fill(Color.red).frame(width: proxy.size.width * progress)
                        }
                    }
                    .frame(height: 3)
                    Text("−\(formatted(max(0, media.duration - media.position)))")
                }
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .foregroundStyle(Color.notchMuted)
                .monospacedDigit()
            }
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
