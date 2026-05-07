#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-debug}"
APP_NAME="ClipboardDrawer"
APP_DIR="$ROOT_DIR/.build/app/${APP_NAME}.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

cd "$ROOT_DIR"
swift build -c "$CONFIGURATION" >&2
BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path 2>/dev/null)"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BIN_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
chmod +x "$MACOS_DIR/$APP_NAME"

/usr/bin/codesign --force --sign - "$APP_DIR" >/dev/null 2>&1 || true
printf '%s\n' "$APP_DIR"
