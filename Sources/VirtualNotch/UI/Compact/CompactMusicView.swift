import SwiftUI

struct CompactMusicView: View {
    @ObservedObject var music: MusicService
    let message: String?

    var body: some View {
        HStack(spacing: 9) {
            AlbumArtworkView(artwork: music.artwork, cornerRadius: 6)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(message ?? music.track?.title ?? "Apple Music")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(message == nil ? .white : Color.notchAccent)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(Color.notchMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            AudioWaveform(isPlaying: music.isPlaying, barCount: 6)
                .frame(width: 24, height: 11)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var subtitle: String {
        if let artist = music.track?.artist, !artist.isEmpty { return artist }
        switch music.playbackState {
        case .notRunning: return "Music is closed"
        case .stopped: return "Not playing"
        case .paused: return "Paused"
        case .playing: return "Now playing"
        }
    }
}
