#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
DIST_DIR="$PROJECT_DIR/dist"
APP_NAME="Re:notch.app"
APP_PATH="$DIST_DIR/$APP_NAME"
VOLUME_NAME="Re-notch"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_DIR/Resources/Info.plist" 2>/dev/null || echo "1.2.0")"
DMG_PATH="$DIST_DIR/Re-notch-${VERSION}.dmg"
DMG_TEMP="$DIST_DIR/temp_renotch.dmg"
STAGING_DIR="$DIST_DIR/dmg_staging"

# 1. Build the app bundle first
"$SCRIPT_DIR/build-app.sh"

echo "Creating Drag-to-Install DMG for Re:notch ${VERSION}..."

# 2. Prepare clean staging directory
rm -rf "$STAGING_DIR" "$DMG_TEMP" "$DMG_PATH"
mkdir -p "$STAGING_DIR/.background"

# Copy App into staging
cp -R "$APP_PATH" "$STAGING_DIR/"

# Create symlink to /Applications
ln -s /Applications "$STAGING_DIR/Applications"

# Set volume icon if available
if [ -f "$PROJECT_DIR/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/AppIcon.icns" "$STAGING_DIR/.VolumeIcon.icns"
fi

# Generate stylish DMG background image
BG_IMAGE_PATH="$STAGING_DIR/.background/background.png"
swift -e '
import AppKit

let width = 560
let height = 340
let image = NSImage(size: NSSize(width: width, height: height))
image.lockFocus()

// Sleek dark background matching macOS aesthetic
let bgGradient = NSGradient(
    colors: [
        NSColor(calibratedRed: 0.12, green: 0.13, blue: 0.15, alpha: 1.0),
        NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.10, alpha: 1.0)
    ]
)
bgGradient?.draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: -45)

// Subtly rounded notch preview / pill container in background center
let pillRect = NSRect(x: 185, y: 140, width: 190, height: 42)
let pillPath = NSBezierPath(roundedRect: pillRect, xRadius: 21, yRadius: 21)
NSColor(calibratedWhite: 1.0, alpha: 0.05).setFill()
pillPath.fill()
NSColor(calibratedWhite: 1.0, alpha: 0.10).setStroke()
pillPath.lineWidth = 1.0
pillPath.stroke()

// Text style
let paragraphStyle = NSMutableParagraphStyle()
paragraphStyle.alignment = .center

let titleFont = NSFont.systemFont(ofSize: 13, weight: .semibold)
let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: titleFont,
    .foregroundColor: NSColor(calibratedWhite: 0.88, alpha: 1.0),
    .paragraphStyle: paragraphStyle
]

// Text: "Drag to Install"
let textRect = NSRect(x: 190, y: 151, width: 180, height: 20)
("Drag to Install" as NSString).draw(in: textRect, withAttributes: titleAttrs)

// Sleek directional arrow pointing right: App -> Applications
let arrowPath = NSBezierPath()
let startX: CGFloat = 245
let endX: CGFloat = 315
let y: CGFloat = 130

arrowPath.move(to: NSPoint(x: startX, y: y))
arrowPath.line(to: NSPoint(x: endX, y: y))
// Arrow head
arrowPath.line(to: NSPoint(x: endX - 8, y: y + 5))
arrowPath.move(to: NSPoint(x: endX, y: y))
arrowPath.line(to: NSPoint(x: endX - 8, y: y - 5))

arrowPath.lineWidth = 2.5
arrowPath.lineCapStyle = .round
arrowPath.lineJoinStyle = .round
NSColor(calibratedRed: 0.38, green: 0.65, blue: 0.98, alpha: 0.85).setStroke()
arrowPath.stroke()

image.unlockFocus()

if let tiffData = image.tiffRepresentation,
   let bitmap = NSBitmapImageRep(data: tiffData),
   let pngData = bitmap.representation(using: .png, properties: [:]) {
    let target = CommandLine.arguments[1]
    try? pngData.write(to: URL(fileURLWithPath: target))
}
' "$BG_IMAGE_PATH"

# 3. Create a temporary read-write DMG image
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDRW \
    -size 150m \
    "$DMG_TEMP"

# 4. Mount the temporary DMG image to customize Finder layout
MOUNT_OUTPUT=$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_TEMP")
DEV_NAME=$(echo "$MOUNT_OUTPUT" | head -n 1 | awk '{print $1}')
MOUNT_DIR=$(echo "$MOUNT_OUTPUT" | grep "/Volumes/" | awk -F'\t' '{print $NF}' | xargs)

if [ -z "$MOUNT_DIR" ]; then
    MOUNT_DIR="/Volumes/$VOLUME_NAME"
fi

# Set custom volume icon attribute
if [ -f "$MOUNT_DIR/.VolumeIcon.icns" ]; then
    SetFile -a C "$MOUNT_DIR" 2>/dev/null || true
fi

sleep 1

# Configure Finder window presentation (icon positions, window size, background, icon size)
osascript <<EOF || true
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        delay 1
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 200, 960, 540}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 120
        set text size of theViewOptions to 14
        try
            set background picture of theViewOptions to file ".background:background.png"
        end try
        try
            set position of item "$APP_NAME" to {140, 160}
            set position of item "Applications" to {420, 160}
        end try
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF

# Ensure changes are flushed
sync || true
sleep 1

# Detach the volume
hdiutil detach "$DEV_NAME" -force 2>/dev/null || hdiutil detach "/Volumes/$VOLUME_NAME" -force 2>/dev/null || true
rm -rf "$STAGING_DIR"

# 5. Convert to compressed, read-only final DMG
hdiutil convert "$DMG_TEMP" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH"
rm -f "$DMG_TEMP"

echo "Successfully built: $DMG_PATH"

