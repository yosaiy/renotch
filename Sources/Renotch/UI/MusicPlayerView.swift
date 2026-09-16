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
                    } else if music.activeSource == .qqMusic {
                        Text("QQ 音乐")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(4)
                            .background(.green, in: RoundedRectangle(cornerRadius: 5))
                            .padding(5)
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
                    Text(([music.activeSource.displayName, metadata(for: track)]).filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.notchMuted)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                HStack(spacing: 4) {
                    Circle()
                        .fill(music.isPlaying ? Color.musicAccent : Color.white.opacity(0.28))
                        .frame(width: 5, height: 5)
                    Text(music.isPlaying ? "正在播放" : "已暂停")
                }
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .accessibilityLabel("播放状态：\(music.isPlaying ? "播放中" : "已暂停")")
            }

            if music.positionIsAvailable {
            HStack(spacing: 7) {
                Text(MusicService.formattedTime(activePosition))
                    .frame(width: 28, alignment: .leading)
                if music.supportsExtendedControls {
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
                } else {
                    ProgressView(value: activePosition, total: max(track.duration, 1))
                        .tint(sourceAccent)
                        .help("QQ 音乐播放进度；拖动进度请在 QQ 音乐中操作")
                }
                Text("−" + MusicService.formattedTime(max(0, track.duration - activePosition)))
                    .frame(width: 36, alignment: .trailing)
            }
            .font(.system(size: 8, weight: .medium, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(Color.notchMuted)
            } else {
                HStack {
                    Text("进度暂不可用")
                    Spacer()
                    Text("时长 \(MusicService.formattedTime(track.duration))")
                }
                .font(.system(size: 9))
                .foregroundStyle(Color.notchMuted)
                .frame(height: 16)
            }

            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    if music.supportsExtendedControls {
                    PlayerControlButton(
                        icon: "shuffle",
                        title: music.shuffleEnabled ? "已开启随机播放" : "已关闭随机播放",
                        size: 27,
                        isActive: music.shuffleEnabled,
                        activeColor: sourceAccent,
                        action: music.toggleShuffle
                    )
                    }

                    PlayerControlButton(
                        icon: "backward.fill",
                        title: "上一首",
                        size: 27,
                        action: music.previousTrack
                    )

                    Button(action: music.togglePlayback) {
                        Image(systemName: music.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(.white))
                            .contentShape(Circle())
                    }
                    .buttonStyle(PlayerPressButtonStyle())
                    .help(music.isPlaying ? "暂停" : "播放")
                    .accessibilityLabel(music.isPlaying ? "暂停音乐" : "播放音乐")
                    .accessibilityIdentifier("music-toggle")

                    PlayerControlButton(
                        icon: "forward.fill",
                        title: "下一首",
                        size: 27,
                        action: music.nextTrack
                    )

                    if music.supportsExtendedControls {
                    PlayerControlButton(
                        icon: music.repeatMode == .one ? "repeat.1" : "repeat",
                        title: repeatHelp,
                        size: 27,
                        isActive: music.repeatMode != .off,
                        activeColor: sourceAccent,
                        action: music.cycleRepeatMode
                    )
                    }
                }
                .padding(.horizontal, 4)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.045))
                )

                Spacer(minLength: 8)

                if music.supportsExtendedControls {
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
                } else {
                    Button("打开 QQ 音乐") { music.open(.qqMusic) }
                        .font(.system(size: 10, weight: .medium))
                        .buttonStyle(.plain)
                        .foregroundStyle(sourceAccent)
                        .help("在 QQ 音乐中调整音量、进度和播放模式")
                }
            }
            if music.activeSource == .qqMusic, let error = music.qqMusicError {
                Text(error).font(.system(size: 9)).foregroundStyle(.orange).lineLimit(2)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(
                music.automationDenied
                    ? "尚未授权访问 \(music.activeSource.displayName)"
                    : "暂无播放内容"
            )
                .font(.system(size: 14, weight: .semibold))
            Text(
                music.automationDenied
                    ? "请在“系统设置 → 隐私与安全性 → 自动化”中，允许 Re:notch 控制 \(music.activeSource.displayName)。"
                    : (music.qqMusicError ?? "在 QQ 音乐、Apple Music 或 Spotify 中播放音乐后，这里会显示歌曲和播放控制。")
            )
            .font(.system(size: 10))
            .foregroundStyle(Color.notchMuted)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 7) {
                sourceButton(.appleMusic)
                sourceButton(.qqMusic)
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
                Text(source.displayName)
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .frame(height: 27)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(source == .appleMusic ? Color.musicAccent : spotifyAccent)
            )
        }
        .buttonStyle(.plain)
        .disabled(!music.isInstalled(source))
        .opacity(music.isInstalled(source) ? 1 : 0.4)
        .help("打开 \(source.displayName)")
        .accessibilityLabel("打开 \(source.displayName)")
    }

    private var activePosition: Double {
        draggedPosition ?? music.position
    }

    private var activeVolume: Double {
        draggedVolume ?? music.volume
    }

    private var sourceAccent: Color {
        music.activeSource == .appleMusic ? Color.musicAccent : spotifyAccent
    }

    private var spotifyAccent: Color {
        Color(red: 0.12, green: 0.78, blue: 0.36)
    }

    private var repeatHelp: String {
        switch music.repeatMode {
        case .off: return "已关闭循环播放"
        case .all: return "列表循环"
        case .one: return "单曲循环"
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
            .accessibilityLabel("正在播放 Apple Music")
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
        .accessibilityLabel(isPlaying ? "音乐播放中" : "音乐已暂停")
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
