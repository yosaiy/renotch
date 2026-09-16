import SwiftUI

struct CompactMusicView: View {
    @ObservedObject var music: MusicService
    @ObservedObject var timer: TimerService
    let message: String?
    var showsTrackInfo = false

    var body: some View {
        HStack(spacing: 9) {
            AlbumArtworkView(artwork: music.artwork, cornerRadius: 6)
                .frame(width: 24, height: 24)
                .overlay(alignment: .bottomLeading) {
                    if music.activeSource == .appleMusic {
                        AppleMusicBadge(size: 10)
                            .padding(1.5)
                            .transition(.opacity.combined(with: .scale(scale: 0.85)))
                    }
                }
                .animation(.easeOut(duration: 0.2), value: music.activeSource)

            if showsTrackInfo {
                VStack(alignment: .leading, spacing: 1) {
                    Text(message ?? music.track?.title ?? "音乐")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(message == nil ? .white : Color.notchAccent)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(Color.notchMuted)
                        .lineLimit(1)
                }
                .transition(.opacity)
            }

            Spacer(minLength: 6)

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
                AudioWaveform(isPlaying: music.isPlaying, barCount: 6)
                    .frame(width: 24, height: 11)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: 0.18), value: showsTrackInfo)
    }

    private var subtitle: String {
        if let artist = music.track?.artist, !artist.isEmpty {
            return "\(artist) · \(music.activeSource.displayName)"
        }
        switch music.playbackState {
        case .notRunning: return "QQ 音乐 / Apple Music / Spotify"
        case .stopped: return "未播放"
        case .paused: return "已暂停"
        case .playing: return "正在播放"
        }
    }
}
