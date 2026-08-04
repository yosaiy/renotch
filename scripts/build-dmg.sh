#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
APP_PATH="$PROJECT_DIR/dist/Re:notch.app"
DMG_PATH="$PROJECT_DIR/dist/Re-notch-1.0.0.dmg"

"$SCRIPT_DIR/build-app.sh"
rm -f "$DMG_PATH"
hdiutil create \
    -volname "Re:notch" \
    -srcfolder "$APP_PATH" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

echo "Built: $DMG_PATH"
