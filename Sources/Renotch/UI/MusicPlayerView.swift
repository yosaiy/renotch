import AppKit
import SwiftUI

struct MusicPlayerView: View {
    @ObservedObject var music: MusicService
    @State private var draggedPosition: Double?
    @State private var draggedVolume: Double?
    @State private var volumeBeforeMute: Double = 0.7

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            AlbumArtworkView(
                artwork: music.artwork,
                cornerRadius: 10,
                showGlow: true,
                isPlaying: music.isPlaying
            )
            .frame(width: 88, height: 88)

            if let track = music.track {
                playerDeck(track)
            } else {
                emptyDeck
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    // MARK: - Active Media Deck

    private func playerDeck(_ track: MusicTrack) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Track Identity + Source Status
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(metadata(for: track))
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundStyle(Color.notchMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                HStack(spacing: 5) {
                    Circle()
                        .fill(music.isPlaying ? sourceAccent : Color.white.opacity(0.28))
                        .frame(width: 5, height: 5)
                        .accessibilityHidden(true)
                    Text(music.isPlaying ? music.activeSource.displayName : "Paused")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(music.isPlaying ? .white.opacity(0.84) : Color.notchMuted)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(music.activeSource.displayName), \(music.isPlaying ? "playing" : "paused")")
            }

            Spacer(minLength: 6)

            // Scrubber + Precision Timestamps
            HStack(spacing: 8) {
                Text(MusicService.formattedTime(activePosition))
                    .frame(minWidth: 28, alignment: .leading)

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
                .tint(sourceAccent)
                .accessibilityLabel("Playback position")

                Text("−" + MusicService.formattedTime(max(0, track.duration - activePosition)))
                    .frame(minWidth: 34, alignment: .trailing)
            }
            .font(.system(size: 9, weight: .medium, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(Color.notchMuted)

            Spacer(minLength: 6)

            // Open Transport + Volume Rail
            HStack(spacing: 6) {
                PlayerControlButton(
                    icon: "shuffle",
                    title: music.shuffleEnabled ? "Shuffle on" : "Shuffle off",
                    size: 26,
                    isActive: music.shuffleEnabled,
                    activeColor: sourceAccent,
                    action: music.toggleShuffle
                )

                PlayerControlButton(
                    icon: "backward.fill",
                    title: "Previous track",
                    size: 26,
                    action: music.previousTrack
                )

                Button {
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                    music.togglePlayback()
                } label: {
                    Image(systemName: music.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(.white))
                        .contentShape(Circle())
                }
                .buttonStyle(PlayerPressButtonStyle())
                .help(music.isPlaying ? "Pause" : "Play")
                .accessibilityLabel(music.isPlaying ? "Pause" : "Play")

                PlayerControlButton(
                    icon: "forward.fill",
                    title: "Next track",
                    size: 26,
                    action: music.nextTrack
                )

                PlayerControlButton(
                    icon: music.repeatMode == .one ? "repeat.1" : "repeat",
                    title: repeatHelp,
                    size: 26,
                    isActive: music.repeatMode != .off,
                    activeColor: sourceAccent,
                    action: music.cycleRepeatMode
                )

                Spacer(minLength: 10)

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1, height: 16)

                HStack(spacing: 6) {
                    Button {
                        toggleMute()
                    } label: {
                        Image(systemName: activeVolume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(activeVolume == 0 ? Color.notchMuted : .white.opacity(0.8))
                            .frame(width: 18, height: 18)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlayerPressButtonStyle())
                    .help(activeVolume == 0 ? "Unmute" : "Mute")
                    .accessibilityLabel(activeVolume == 0 ? "Unmute" : "Mute")

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
                    .tint(.white.opacity(0.84))
                    .accessibilityLabel("Volume")
                }
                .frame(width: 96)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 88, alignment: .leading)
    }

    // MARK: - Empty / Permission State

    private var emptyDeck: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(
                music.automationDenied
                    ? "\(music.activeSource.displayName) access is off"
                    : "Nothing playing"
            )
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)

            Text(
                music.automationDenied
                    ? "Allow Re:notch to control \(music.activeSource.displayName) in System Settings > Privacy & Security > Automation."
                    : "Start playback in Apple Music or Spotify to control it from the notch."
            )
            .font(.system(size: 10.5))
            .foregroundStyle(Color.notchMuted)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                sourceButton(.appleMusic)
                sourceButton(.spotify)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sourceButton(_ source: MusicSource) -> some View {
        let installed = music.isInstalled(source)
        return Button {
            music.open(source)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: source == .spotify ? "waveform.circle.fill" : "music.note")
                    .font(.system(size: 10, weight: .semibold))
                Text("Open \(source.displayName)")
                    .font(.system(size: 10.5, weight: .semibold))
            }
            .foregroundStyle(source == .appleMusic ? .white : .black)
            .padding(.horizontal, 11)
            .frame(height: 27)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(source == .spotify ? Color.notchAccent : Color.musicAccent)
            )
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(PlayerPressButtonStyle())
        .disabled(!installed)
        .opacity(installed ? 1 : 0.35)
    }

    private func toggleMute() {
        if activeVolume > 0 {
            volumeBeforeMute = activeVolume
            music.setVolume(0)
        } else {
            music.setVolume(max(0.25, volumeBeforeMute))
        }
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

struct AlbumArtworkView: View {
    let artwork: NSImage?
    var cornerRadius: CGFloat = 10
    var showGlow: Bool = false
    var isPlaying: Bool = true

    var body: some View {
        ZStack {
            if showGlow, let artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 12)
                    .scaleEffect(1.06)
                    .opacity(isPlaying ? 0.24 : 0.08)
                    .offset(y: 3)
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.35), value: isPlaying)
            }

            mainArtwork
        }
    }

    private var mainArtwork: some View {
        Group {
            if let artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color.white.opacity(0.05)
                    Image(systemName: "music.note")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.notchMuted)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.7)
        )
        .shadow(color: .black.opacity(showGlow ? 0.32 : 0.0), radius: 6, y: 3)
    }
}

struct AudioWaveform: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isPlaying: Bool
    var barCount = 6

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1, paused: !isPlaying || reduceMotion)) { context in
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
        guard isPlaying, !reduceMotion else { return CGFloat([3, 5, 4, 6, 4, 3][index % 6]) }
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
                .foregroundStyle(isActive ? activeColor : (isHovering ? .white : .white.opacity(0.8)))
                .frame(width: size, height: size)
                .background(
                    Circle().fill(
                        isActive
                            ? activeColor.opacity(0.16)
                            : Color.white.opacity(isHovering ? 0.12 : 0.05)
                    )
                )
                .contentShape(Circle())
        }
        .buttonStyle(PlayerPressButtonStyle())
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.14), value: isHovering)
        .animation(.easeOut(duration: 0.14), value: isActive)
        .help(title)
        .accessibilityLabel(title)
    }
}

private struct PlayerPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
