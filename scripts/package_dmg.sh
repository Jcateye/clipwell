#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-release}"
BUNDLE_NAME="Clipwell"
APP_DIR="$ROOT_DIR/.build/app/${BUNDLE_NAME}.app"
DIST_DIR="$ROOT_DIR/dist"
STAGING_DIR="$ROOT_DIR/.build/dmg/${BUNDLE_NAME}"
DMG_PATH="$DIST_DIR/${BUNDLE_NAME}.dmg"
VOLUME_NAME="$BUNDLE_NAME"

"$ROOT_DIR/scripts/package_app.sh" "$CONFIGURATION" >/dev/null

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_DIR" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

mkdir -p "$DIST_DIR"
rm -f "$DMG_PATH"

COPYFILE_DISABLE=1 hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

printf '%s\n' "$DMG_PATH"
