#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
DIST_DIR="$PROJECT_DIR/dist"
APP_NAME="Re:notch.app"
APP_PATH="$DIST_DIR/$APP_NAME"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_DIR/Resources/Info.plist" 2>/dev/null || echo "1.2.0")"
ZIP_PATH="$DIST_DIR/Re-notch-${VERSION}.zip"

# 1. Build the app bundle
"$SCRIPT_DIR/build-app.sh"

# 2. Package as standard macOS release zip (preserves code signature and permissions)
echo "Creating release zip for Re:notch ${VERSION}..."
rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

echo "Successfully built: $ZIP_PATH"
