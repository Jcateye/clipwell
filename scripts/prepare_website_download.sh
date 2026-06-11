#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-release}"
DOWNLOAD_DIR="$ROOT_DIR/marketing/clipwell/downloads"
DOWNLOAD_ZIP="$DOWNLOAD_DIR/Clipwell-latest.zip"
DOWNLOAD_DMG="$DOWNLOAD_DIR/Clipwell-latest.dmg"

"$ROOT_DIR/scripts/package_dmg.sh" "$CONFIGURATION" >/dev/null

mkdir -p "$DOWNLOAD_DIR"
cp "$ROOT_DIR/dist/Clipwell-macOS.zip" "$DOWNLOAD_ZIP"
cp "$ROOT_DIR/dist/Clipwell.dmg" "$DOWNLOAD_DMG"

printf '%s\n' "$DOWNLOAD_DMG"
