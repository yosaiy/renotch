import SwiftUI

struct MusicPlayerView: View {
    @ObservedObject var music: MusicService
    @State private var draggedPosition: Double?
    @State private var draggedVolume: Double?

    var body: some View {
        HStack(spacing: 14) {
            AlbumArtworkView(artwork: music.artwork, cornerRadius: 12)
                .frame(width: 82, height: 82)
                .shadow(color: .black.opacity(0.45), radius: 10, y: 5)
                .overlay(alignment: .bottomLeading) {
                    if music.isPlaying, music.activeSource == .appleMusic {
                        AppleMusicBadge()
                            .padding(5)
                            .transition(.opacity.combined(with: .scale(scale: 0.85)))
                    }
                }
                .animation(.easeOut(duration: 0.2), value: music.isPlaying)
                .animation(.easeOut(duration: 0.2), value: music.activeSource)

            if let track = music.track {
                playerDetails(track)
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private func playerDetails(_ track: MusicTrack) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(track.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(metadata(for: track))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.notchMuted)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                HStack(spacing: 4) {
                    Circle()
                        .fill(music.isPlaying ? Color.musicAccent : Color.white.opacity(0.28))
                        .frame(width: 5, height: 5)
                    Text(music.isPlaying ? "Playing" : "Paused")
                }
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .accessibilityLabel("Playback status: \(music.isPlaying ? "playing" : "paused")")
            }

            HStack(spacing: 7) {
                Text(MusicService.formattedTime(activePosition))
                    .frame(width: 28, alignment: .leading)
                Slider(
                    value: Binding(
                        get: { activePosition },
                        set: { draggedPosition = $0 }
                    ),
                    in: 0...max(track.duration, 1),
                    onEditingChanged: { editing in
                        guard !editing, let draggedPosition else { return }
                        music.seek(to: draggedPosition)
                        self.draggedPosition = nil
                    }
                )
                .tint(Color.musicAccent)
                Text("−" + MusicService.formattedTime(max(0, track.duration - activePosition)))
                    .frame(width: 36, alignment: .trailing)
            }
            .font(.system(size: 8, weight: .medium, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(Color.notchMuted)

            HStack(spacing: 10) {
                HStack(spacing: 0) {
                    PlayerControlButton(
                        icon: "shuffle",
                        title: music.shuffleEnabled ? "Shuffle on" : "Shuffle off",
                        size: 27,
                        isActive: music.shuffleEnabled,
                        activeColor: sourceAccent,
                        action: music.toggleShuffle
                    )
                    .frame(maxWidth: .infinity)

                    PlayerControlButton(
                        icon: "backward.fill",
                        title: "Previous",
                        size: 27,
                        action: music.previousTrack
                    )
                    .frame(maxWidth: .infinity)

                    Button(action: music.togglePlayback) {
                        Image(systemName: music.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(.white))
                            .contentShape(Circle())
                    }
                    .buttonStyle(PlayerPressButtonStyle())
                    .frame(maxWidth: .infinity)
                    .help(music.isPlaying ? "Pause" : "Play")

                    PlayerControlButton(
                        icon: "forward.fill",
                        title: "Next",
                        size: 27,
                        action: music.nextTrack
                    )
                    .frame(maxWidth: .infinity)

                    PlayerControlButton(
                        icon: music.repeatMode == .one ? "repeat.1" : "repeat",
                        title: repeatHelp,
                        size: 27,
                        isActive: music.repeatMode != .off,
                        activeColor: sourceAccent,
                        action: music.cycleRepeatMode
                    )
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.045))
                )

                HStack(spacing: 7) {
                    Image(systemName: activeVolume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.notchMuted)
                    Slider(
                        value: Binding(
                            get: { activeVolume },
                            set: { draggedVolume = $0 }
                        ),
                        in: 0...1,
                        onEditingChanged: { editing in
                            guard !editing, let draggedVolume else { return }
                            music.setVolume(draggedVolume)
                            self.draggedVolume = nil
                        }
                    )
                    .tint(.white.opacity(0.82))
                }
                .frame(width: 94)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(
                music.automationDenied
                    ? "\(music.activeSource.displayName) access is off"
                    : "Nothing playing"
            )
                .font(.system(size: 14, weight: .semibold))
            Text(
                music.automationDenied
                    ? "Allow Re:notch to control \(music.activeSource.displayName) in System Settings → Privacy & Security → Automation."
                    : "Play a song in Apple Music or Spotify and its artwork and controls will appear here."
            )
            .font(.system(size: 10))
            .foregroundStyle(Color.notchMuted)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 7) {
                sourceButton(.appleMusic)
                sourceButton(.spotify)
            }
        }
        .frame(maxWidth: 310, alignment: .leading)
    }

    private func sourceButton(_ source: MusicSource) -> some View {
        Button {
            music.open(source)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: source == .spotify ? "waveform.circle.fill" : "music.note")
                Text("Open \(source.displayName)")
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .frame(height: 27)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(source == .spotify ? spotifyAccent : Color.musicAccent)
            )
        }
        .buttonStyle(.plain)
        .disabled(!music.isInstalled(source))
        .opacity(music.isInstalled(source) ? 1 : 0.4)
    }

    private var activePosition: Double {
        draggedPosition ?? music.position
    }

    private var activeVolume: Double {
        draggedVolume ?? music.volume
    }

    private var sourceAccent: Color {
        music.activeSource == .spotify ? spotifyAccent : Color.musicAccent
    }

    private var spotifyAccent: Color {
        Color(red: 0.12, green: 0.78, blue: 0.36)
    }

    private var repeatHelp: String {
        switch music.repeatMode {
        case .off: return "Repeat off"
        case .all: return "Repeat all"
        case .one: return "Repeat one"
        }
    }

    private func metadata(for track: MusicTrack) -> String {
        [track.artist, track.album]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

/// Source badge pinned to the bottom-left corner of the album artwork while
/// Apple Music is playing: the classic beamed-notes glyph with the Apple
/// Music gradient on a small blurred tile, sized to stay out of the way of
/// the artwork itself.
struct AppleMusicBadge: View {
    /// Tile edge length; every inner metric scales from this so the badge
    /// can shrink onto compact artwork without losing its proportions.
    var size: CGFloat = 17

    private var cornerRadius: CGFloat { size * 5 / 17 }

    var body: some View {
        Image(systemName: "music.note")
            .font(.system(size: size * 9 / 17, weight: .bold))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.35, blue: 0.47),
                        Color(red: 0.98, green: 0.48, blue: 0.33)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.black.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
            )
            .accessibilityLabel("Playing from Apple Music")
    }
}

struct AlbumArtworkView: View {
    let artwork: NSImage?
    var cornerRadius: CGFloat = 10
    var body: some View {
        Group {
            if let artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color(red: 0.12, green: 0.12, blue: 0.14)
                    Image(systemName: "music.note")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.46))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.7)
        )
    }
}

struct AudioWaveform: View {
    let isPlaying: Bool
    var barCount = 6

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1, paused: !isPlaying)) { context in
            HStack(spacing: 1.5) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(Color.white.opacity(isPlaying ? 0.92 : 0.46))
                        .frame(width: 2, height: barHeight(index, at: context.date))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityLabel(isPlaying ? "Music playing" : "Music paused")
    }

    private func barHeight(_ index: Int, at date: Date) -> CGFloat {
        guard isPlaying else { return CGFloat([3, 5, 4, 6, 4, 3][index % 6]) }
        let time = date.timeIntervalSinceReferenceDate
        let wave = abs(sin(time * (3.2 + Double(index) * 0.22) + Double(index) * 0.9))
        return 2.5 + CGFloat(wave) * 6.5
    }
}

private struct PlayerControlButton: View {
    let icon: String
    let title: String
    let size: CGFloat
    var isActive = false
    var activeColor: Color = .white
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isActive ? activeColor : .white.opacity(0.86))
                .frame(width: size, height: size)
                .background(
                    Circle().fill(
                        isActive
                            ? activeColor.opacity(0.16)
                            : Color.white.opacity(isHovering ? 0.13 : 0.08)
                    )
                )
                .contentShape(Circle())
        }
        .buttonStyle(PlayerPressButtonStyle())
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.16), value: isHovering)
        .animation(.easeOut(duration: 0.16), value: isActive)
        .help(title)
        .accessibilityLabel(title)
    }
}

private struct PlayerPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
