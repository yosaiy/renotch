#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
DIST_DIR="$PROJECT_DIR/dist"
APP_PATH="$DIST_DIR/Re:notch.app"
CONTENTS_PATH="$APP_PATH/Contents"
BUILD_CONFIGURATION="${BUILD_CONFIGURATION:-release}"
SIGN_IDENTITY="${CODE_SIGN_IDENTITY:-}"

# TCC ties privacy grants (Calendar, etc.) to the signing identity. Ad-hoc
# signing keys grants on the binary cdhash, which changes on every rebuild,
# forcing users to re-grant Calendar access after each build. Prefer a real
# identity so grants persist across rebuilds.
if [ -z "$SIGN_IDENTITY" ]; then
    SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
        | awk -F'"' '/"/ { print $2; exit }')"
fi
if [ -z "$SIGN_IDENTITY" ]; then
    # Local self-signed code signing identity (see repo README/scripts setup).
    # Not listed by `find-identity` (untrusted chain) but usable by codesign,
    # and gives TCC a stable certificate hash so grants persist.
    if security find-certificate -c "Re:notch Local Code Sign" "$HOME/Library/Keychains/login.keychain-db" >/dev/null 2>&1; then
        SIGN_IDENTITY="Re:notch Local Code Sign"
    fi
fi
if [ -z "$SIGN_IDENTITY" ]; then
    SIGN_IDENTITY="-"
    echo "warning: no code signing identity found; using ad-hoc signing."
    echo "warning: TCC grants (Calendar access) will NOT survive rebuilds."
    echo "warning: set CODE_SIGN_IDENTITY to a Developer ID / Apple Development certificate."
fi

cd "$PROJECT_DIR"
swift build -c "$BUILD_CONFIGURATION" --product VirtualNotch
swift build -c "$BUILD_CONFIGURATION" --product VirtualNotchBrowserBridge
BIN_DIR="$(swift build -c "$BUILD_CONFIGURATION" --show-bin-path)"

rm -rf "$APP_PATH"
mkdir -p "$CONTENTS_PATH/MacOS" "$CONTENTS_PATH/Resources"
cp "$BIN_DIR/VirtualNotch" "$CONTENTS_PATH/MacOS/VirtualNotch"
cp "$BIN_DIR/VirtualNotchBrowserBridge" "$CONTENTS_PATH/MacOS/VirtualNotchBrowserBridge"
# Bundle.module resources (menu bar icon, etc.). Placed in Contents/Resources:
# codesign --deep rejects the plist-less SwiftPM bundle as nested code in
# Contents/MacOS, and Bundle.module looks in Resources too.
if [ -d "$BIN_DIR/VirtualNotch_VirtualNotch.bundle" ]; then
    cp -R "$BIN_DIR/VirtualNotch_VirtualNotch.bundle" "$CONTENTS_PATH/Resources/"
fi
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_PATH/Info.plist"
cp -R "$PROJECT_DIR/BrowserExtension" "$CONTENTS_PATH/Resources/BrowserExtension"

# Use custom AppIcon.icns from project root
CUSTOM_ICON="$PROJECT_DIR/AppIcon.icns"
if [ -f "$CUSTOM_ICON" ]; then
    cp "$CUSTOM_ICON" "$CONTENTS_PATH/Resources/AppIcon.icns"
    echo "Using custom AppIcon.icns"
else
    echo "error: AppIcon.icns not found at $CUSTOM_ICON"
    exit 1
fi

echo "Signing with identity: $SIGN_IDENTITY"

# Sign binaries individually first: avoids deep-signing failures and keeps the
# stable identity attached to each Mach-O (what TCC keys privacy grants on).
codesign --force --options runtime --sign "$SIGN_IDENTITY" "$BIN_DIR/VirtualNotch"
codesign --force --options runtime --sign "$SIGN_IDENTITY" "$BIN_DIR/VirtualNotchBrowserBridge"

codesign \
    --force \
    --deep \
    --options runtime \
    --entitlements "$PROJECT_DIR/Resources/VirtualNotch.entitlements" \
    --sign "$SIGN_IDENTITY" \
    "$APP_PATH"

echo "Built: $APP_PATH"
