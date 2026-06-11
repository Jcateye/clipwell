#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-debug}"
EXECUTABLE_NAME="ClipboardDrawer"
BUNDLE_NAME="Clipwell"
APP_DIR="$ROOT_DIR/.build/app/${BUNDLE_NAME}.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"
DIST_DIR="$ROOT_DIR/dist"
ZIP_PATH="$DIST_DIR/${BUNDLE_NAME}-macOS.zip"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"

cd "$ROOT_DIR"
"$ROOT_DIR/scripts/generate_app_icon.sh" >/dev/null
swift build -c "$CONFIGURATION" >&2
BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path 2>/dev/null)"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BIN_DIR/$EXECUTABLE_NAME" "$MACOS_DIR/$EXECUTABLE_NAME"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT_DIR/Resources/Clipwell.icns" "$RESOURCES_DIR/Clipwell.icns"
chmod +x "$MACOS_DIR/$EXECUTABLE_NAME"

/usr/bin/codesign --force --options runtime --timestamp --sign "$CODESIGN_IDENTITY" "$APP_DIR" >/dev/null 2>&1 || {
  if [[ "$CODESIGN_IDENTITY" == "-" ]]; then
    /usr/bin/codesign --force --sign - "$APP_DIR" >/dev/null 2>&1 || true
  else
    printf 'error: codesign failed with identity: %s\n' "$CODESIGN_IDENTITY" >&2
    exit 1
  fi
}
mkdir -p "$DIST_DIR"
rm -f "$ZIP_PATH"
COPYFILE_DISABLE=1 ditto -c -k --keepParent --norsrc --noextattr "$APP_DIR" "$ZIP_PATH"
printf '%s\n' "$APP_DIR"
printf '%s\n' "$ZIP_PATH" >&2
