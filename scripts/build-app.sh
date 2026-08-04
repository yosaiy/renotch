#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
DIST_DIR="$PROJECT_DIR/dist"
APP_PATH="$DIST_DIR/Re:notch.app"
CONTENTS_PATH="$APP_PATH/Contents"
BUILD_CONFIGURATION="${BUILD_CONFIGURATION:-release}"
SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"

cd "$PROJECT_DIR"
swift build -c "$BUILD_CONFIGURATION" --product VirtualNotch
swift build -c "$BUILD_CONFIGURATION" --product VirtualNotchBrowserBridge
BIN_DIR="$(swift build -c "$BUILD_CONFIGURATION" --show-bin-path)"

rm -rf "$APP_PATH"
mkdir -p "$CONTENTS_PATH/MacOS" "$CONTENTS_PATH/Resources"
cp "$BIN_DIR/VirtualNotch" "$CONTENTS_PATH/MacOS/VirtualNotch"
cp "$BIN_DIR/VirtualNotchBrowserBridge" "$CONTENTS_PATH/MacOS/VirtualNotchBrowserBridge"
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_PATH/Info.plist"
cp -R "$PROJECT_DIR/BrowserExtension" "$CONTENTS_PATH/Resources/BrowserExtension"

ICON_TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$ICON_TEMP_DIR"' EXIT
ICONSET_PATH="$ICON_TEMP_DIR/AppIcon.iconset"
MASTER_ICON="$ICON_TEMP_DIR/AppIcon-1024.png"
mkdir -p "$ICONSET_PATH"
swift "$PROJECT_DIR/scripts/generate-icon.swift" "$MASTER_ICON"

sips -z 16 16 "$MASTER_ICON" --out "$ICONSET_PATH/icon_16x16.png" >/dev/null
sips -z 32 32 "$MASTER_ICON" --out "$ICONSET_PATH/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$MASTER_ICON" --out "$ICONSET_PATH/icon_32x32.png" >/dev/null
sips -z 64 64 "$MASTER_ICON" --out "$ICONSET_PATH/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$MASTER_ICON" --out "$ICONSET_PATH/icon_128x128.png" >/dev/null
sips -z 256 256 "$MASTER_ICON" --out "$ICONSET_PATH/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$MASTER_ICON" --out "$ICONSET_PATH/icon_256x256.png" >/dev/null
sips -z 512 512 "$MASTER_ICON" --out "$ICONSET_PATH/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$MASTER_ICON" --out "$ICONSET_PATH/icon_512x512.png" >/dev/null
cp "$MASTER_ICON" "$ICONSET_PATH/icon_512x512@2x.png"
iconutil -c icns "$ICONSET_PATH" -o "$CONTENTS_PATH/Resources/AppIcon.icns"

codesign \
    --force \
    --deep \
    --options runtime \
    --entitlements "$PROJECT_DIR/Resources/VirtualNotch.entitlements" \
    --sign "$SIGN_IDENTITY" \
    "$APP_PATH"

echo "Built: $APP_PATH"
