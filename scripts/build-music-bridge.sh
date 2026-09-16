#!/bin/zsh
set -euo pipefail
SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
BRIDGE_OUTPUT="${1:-$PROJECT_DIR/.build/music-bridge}"
mkdir -p "$BRIDGE_OUTPUT"
xcrun clang -dynamiclib -fobjc-arc -O2 -mmacosx-version-min=13.0 \
    -arch arm64 -arch x86_64 -framework AppKit \
    "$PROJECT_DIR/MediaBridge/QQMusicBridge.m" \
    -o "$BRIDGE_OUTPUT/libQQMusicBridge.dylib"
cp "$PROJECT_DIR/MediaBridge/qq-music-bridge.pl" "$BRIDGE_OUTPUT/qq-music-bridge.pl"
