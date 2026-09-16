#!/bin/zsh
set -euo pipefail
SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
cd "$PROJECT_DIR"
mkdir -p .build
swiftc -swift-version 5 \
    Sources/Renotch/Models/NotchModels.swift \
    Sources/Renotch/Services/MusicService.swift \
    Sources/Renotch/Services/QQMusicBridge.swift \
    Tests/QQMusicTests.swift -framework AppKit -o .build/renotch-qq-music-tests
.build/renotch-qq-music-tests
