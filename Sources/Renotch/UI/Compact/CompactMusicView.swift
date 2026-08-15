import SwiftUI

struct CompactMusicView: View {
    @ObservedObject var music: MusicService
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
                    Text(message ?? music.track?.title ?? "Music")
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

            Spacer(minLength: 8)

            AudioWaveform(isPlaying: music.isPlaying, barCount: 6)
                .frame(width: 24, height: 11)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: 0.18), value: showsTrackInfo)
    }

    private var subtitle: String {
        if let artist = music.track?.artist, !artist.isEmpty {
            return "\(artist) · \(music.activeSource.displayName)"
        }
        switch music.playbackState {
        case .notRunning: return "Apple Music or Spotify"
        case .stopped: return "Not playing"
        case .paused: return "Paused"
        case .playing: return "Now playing"
        }
    }
}
