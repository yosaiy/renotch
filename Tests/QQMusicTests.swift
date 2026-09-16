import AppKit
import Foundation

@main
struct QQMusicTests {
    @MainActor static func main() {
        var checks = 0
        func expect(_ result: Bool, _ name: String) {
            checks += 1
            if !result { fputs("FAIL: \(name)\n", stderr); exit(1) }
        }
        let example: [String: Any] = [
            "kind": "snapshot", "available": true, "bundleID": "com.tencent.QQMusicMac",
            "title": "测试歌曲\n第二行", "artist": "歌手 A", "album": "专辑", "trackID": "123",
            "duration": 263.0, "position": 170.0, "playing": true
        ]
        let playing = QQMusicBridge.parseSnapshot(example)!
        expect(playing.source == .qqMusic, "QQ source preserved")
        expect(playing.track?.id == "qqMusic:123", "IDs namespaced by player")
        expect(playing.track?.title == "测试歌曲\n第二行", "Unicode and multiline text preserved")
        expect(playing.track?.artist == "歌手 A", "artist decoded")
        expect(playing.track?.album == "专辑", "album decoded")
        expect(playing.track?.duration == 263, "QQ duration in seconds")
        expect(playing.position == 170, "QQ elapsed time in seconds")
        expect(playing.playbackState == .playing, "playing callback controls state")
        var changed = example
        changed["playing"] = false
        changed["playbackRate"] = 1
        expect(QQMusicBridge.parseSnapshot(changed)?.playbackState == .paused, "stale playbackRate must not imply playing")
        for foreign in ["com.apple.Music", "com.spotify.client", "com.google.Chrome", ""] {
            changed = example; changed["bundleID"] = foreign
            expect(QQMusicBridge.parseSnapshot(changed) == nil, "foreign media owner rejected")
        }
        changed = example; changed["available"] = false
        expect(QQMusicBridge.parseSnapshot(changed) == nil, "inactive QQ has no stale card")
        expect(QQMusicBridge.parseSnapshot([:]) == nil, "empty metadata rejected")
        for title in ["", "  \n "] {
            changed = example; changed["title"] = title
            expect(QQMusicBridge.parseSnapshot(changed) == nil, "empty title rejected")
        }
        for (value, result) in [(Double.nan, 0.0), (Double.infinity, 0.0), (-10.0, 0.0), (500.0, 263.0)] {
            changed = example; changed["position"] = value
            expect(QQMusicBridge.parseSnapshot(changed)?.position == result, "invalid position bounded")
        }
        changed = example; changed["duration"] = -1.0
        expect(QQMusicBridge.parseSnapshot(changed)?.track?.duration == 0, "negative duration bounded")
        expect(QQMusicBridge.parseSnapshot(changed)?.position == 0, "position bounded by missing duration")
        changed = example; changed.removeValue(forKey: "trackID")
        expect(QQMusicBridge.parseSnapshot(changed)?.track?.id.contains("测试歌曲") == true, "deterministic fallback identity")
        changed = example; changed["artwork"] = Data([1, 2, 3]).base64EncodedString()
        expect(QQMusicBridge.parseSnapshot(changed)?.artworkData == Data([1, 2, 3]), "embedded cover decoded without network")
        changed["artwork"] = "invalid!"
        expect(QQMusicBridge.parseSnapshot(changed)?.artworkData == nil, "invalid cover discarded")
        expect(QQMusicCommand(rawValue: "launch") == nil, "unknown command rejected")
        expect(QQMusicCommand(rawValue: "toggle") != nil, "play toggle allowed")
        expect(QQMusicCommand(rawValue: "next") != nil, "next track allowed")
        expect(QQMusicCommand(rawValue: "previous") != nil, "previous track allowed")
        // Existing player parsing keeps its original duration conventions.
        let legacy = ["playing", "track", "歌曲", "歌手", "专辑", "263000", "170", "70", ""].joined(separator: "\u{001F}")
        expect(MusicService.parseMetadata(legacy, source: .spotify)?.track?.duration == 263, "Spotify milliseconds unchanged")
        let apple = legacy.replacingOccurrences(of: "263000", with: "263")
        expect(MusicService.parseMetadata(apple, source: .appleMusic)?.track?.duration == 263, "Apple Music seconds unchanged")
        changed = example; changed["playing"] = false; changed["position"] = 0.0; changed["positionAvailable"] = false
        let paused = QQMusicBridge.parseSnapshot(changed)!
        expect(!paused.hasPosition, "QQ paused zero is unknown, not a reset")
        let preserved = QQMusicBridge.merge(paused, previous: playing)!
        expect(preserved.position == 170 && preserved.hasPosition, "pause retains last observed progress")
        expect(QQMusicBridge.merge(paused, previous: nil)?.hasPosition == false, "startup while paused does not invent progress")
        changed["trackID"] = "new-song"
        expect(QQMusicBridge.merge(QQMusicBridge.parseSnapshot(changed), previous: playing)?.hasPosition == false, "old song progress never transfers to a new song")
        expect(QQMusicBridge.merge(nil, previous: playing) == nil, "loss of QQ ownership clears previous metadata")
        print("PASS: \(checks) QQ Music checks")
    }
}
