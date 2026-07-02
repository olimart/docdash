#!/bin/bash
# Builds DocDash.app from the SwiftPM executable — no Xcode project needed.
#
# Usage: scripts/make_app.sh [output-dir] [--universal]
#   output-dir defaults to ./dist
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${DOCDASH_VERSION:-0.0.0-dev}"
SCRATCH="${DOCDASH_SCRATCH:-$ROOT/.build}"

OUTPUT_DIR="$ROOT/dist"
UNIVERSAL=0
for arg in "$@"; do
  case "$arg" in
    --universal) UNIVERSAL=1 ;;
    *) OUTPUT_DIR="$arg" ;;
  esac
done

cd "$ROOT"

BUILD_CMD=(swift build -c release --scratch-path "$SCRATCH" --disable-index-store)
BIN_SUBDIR="release"
if [ "$UNIVERSAL" = 1 ]; then
  BUILD_CMD+=(--arch arm64 --arch x86_64)
  BIN_SUBDIR="apple/Products/Release"
fi

echo "==> ${BUILD_CMD[*]}"
"${BUILD_CMD[@]}"
BINARY="$SCRATCH/$BIN_SUBDIR/DocDash"
[ -f "$BINARY" ] || { echo "binary not found: $BINARY" >&2; exit 1; }

APP="$OUTPUT_DIR/DocDash.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BINARY" "$APP/Contents/MacOS/DocDash"

echo "==> generating icon"
swift "$ROOT/scripts/make_icon.swift" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>DocDash</string>
    <key>CFBundleIdentifier</key>
    <string>com.internal.docdash</string>
    <key>CFBundleName</key>
    <string>DocDash</string>
    <key>CFBundleDisplayName</key>
    <string>DocDash</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Internal use only.</string>
</dict>
</plist>
PLIST

echo "==> ad-hoc code signing"
codesign --force --sign - "$APP"

echo "==> built $APP"
lipo -info "$APP/Contents/MacOS/DocDash" 2>/dev/null || true
