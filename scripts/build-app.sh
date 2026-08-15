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
# Build for Apple Silicon (arm64) and Intel (x86_64)
swift build -c "$BUILD_CONFIGURATION" --triple arm64-apple-macosx --product Renotch
swift build -c "$BUILD_CONFIGURATION" --triple arm64-apple-macosx --product RenotchBrowserBridge
swift build -c "$BUILD_CONFIGURATION" --triple x86_64-apple-macosx --product Renotch
swift build -c "$BUILD_CONFIGURATION" --triple x86_64-apple-macosx --product RenotchBrowserBridge

BIN_DIR_ARM64="$(swift build -c "$BUILD_CONFIGURATION" --triple arm64-apple-macosx --show-bin-path)"
BIN_DIR_X86="$(swift build -c "$BUILD_CONFIGURATION" --triple x86_64-apple-macosx --show-bin-path)"

rm -rf "$APP_PATH"
mkdir -p "$CONTENTS_PATH/MacOS" "$CONTENTS_PATH/Resources"

# Create Universal binaries supporting both Apple Silicon and Intel Macs
lipo -create \
    "$BIN_DIR_ARM64/Renotch" \
    "$BIN_DIR_X86/Renotch" \
    -output "$CONTENTS_PATH/MacOS/Renotch"

lipo -create \
    "$BIN_DIR_ARM64/RenotchBrowserBridge" \
    "$BIN_DIR_X86/RenotchBrowserBridge" \
    -output "$CONTENTS_PATH/MacOS/RenotchBrowserBridge"

# Bundle.module resources (menu bar icon, etc.). Placed in Contents/Resources:
# codesign --deep rejects the plist-less SwiftPM bundle as nested code in
# Contents/MacOS, and Bundle.module looks in Resources too.
if [ -d "$BIN_DIR_ARM64/Renotch_Renotch.bundle" ]; then
    cp -R "$BIN_DIR_ARM64/Renotch_Renotch.bundle" "$CONTENTS_PATH/Resources/"
elif [ -d "$BIN_DIR_X86/Renotch_Renotch.bundle" ]; then
    cp -R "$BIN_DIR_X86/Renotch_Renotch.bundle" "$CONTENTS_PATH/Resources/"
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

codesign \
    --force \
    --deep \
    --options runtime \
    --entitlements "$PROJECT_DIR/Resources/Renotch.entitlements" \
    --sign "$SIGN_IDENTITY" \
    "$APP_PATH"

echo "Built: $APP_PATH"
