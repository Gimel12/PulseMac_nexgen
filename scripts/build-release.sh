#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$PROJECT_DIR/dist"
WORK_DIR="$PROJECT_DIR/.build/pulsemac-packaging"
APP_DIR="$DIST_DIR/PulseMac.app"
ICONSET_DIR="$WORK_DIR/PulseMac.iconset"

cd "$PROJECT_DIR"
swift build -c release

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$ICONSET_DIR"
swift Packaging/make_icon.swift "$WORK_DIR/PulseMac-1024.png"

sips -z 16 16 "$WORK_DIR/PulseMac-1024.png" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$WORK_DIR/PulseMac-1024.png" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$WORK_DIR/PulseMac-1024.png" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$WORK_DIR/PulseMac-1024.png" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$WORK_DIR/PulseMac-1024.png" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$WORK_DIR/PulseMac-1024.png" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$WORK_DIR/PulseMac-1024.png" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$WORK_DIR/PulseMac-1024.png" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$WORK_DIR/PulseMac-1024.png" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
cp "$WORK_DIR/PulseMac-1024.png" "$ICONSET_DIR/icon_512x512@2x.png"
iconutil -c icns "$ICONSET_DIR" -o "$WORK_DIR/AppIcon.icns"

cp ".build/release/PulseMac" "$APP_DIR/Contents/MacOS/PulseMac"
cp "Packaging/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$WORK_DIR/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$DIST_DIR/PulseMac-1.0.zip"

echo "Built $DIST_DIR/PulseMac-1.0.zip"
