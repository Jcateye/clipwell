#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_SVG="${1:-$ROOT_DIR/marketing/clipwell/assets/icon.svg}"
OUTPUT_DIR="${2:-$ROOT_DIR/Resources}"
ICONSET_DIR="$OUTPUT_DIR/Clipwell.iconset"
ICNS_PATH="$OUTPUT_DIR/Clipwell.icns"
MARKETING_ICON_PATH="$OUTPUT_DIR/Clipwell-AppStore-1024.png"

if command -v magick >/dev/null 2>&1; then
  RENDER=(magick "$SOURCE_SVG")
elif command -v convert >/dev/null 2>&1; then
  RENDER=(convert "$SOURCE_SVG")
else
  printf 'error: ImageMagick is required. Install it with: brew install imagemagick\n' >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"
trap 'rm -rf "$ICONSET_DIR"' EXIT

render_png() {
  local size="$1"
  local path="$2"
  "${RENDER[@]}" -background none -resize "${size}x${size}" "$path"
}

render_png 16 "$ICONSET_DIR/icon_16x16.png"
render_png 32 "$ICONSET_DIR/icon_16x16@2x.png"
render_png 32 "$ICONSET_DIR/icon_32x32.png"
render_png 64 "$ICONSET_DIR/icon_32x32@2x.png"
render_png 128 "$ICONSET_DIR/icon_128x128.png"
render_png 256 "$ICONSET_DIR/icon_128x128@2x.png"
render_png 256 "$ICONSET_DIR/icon_256x256.png"
render_png 512 "$ICONSET_DIR/icon_256x256@2x.png"
render_png 512 "$ICONSET_DIR/icon_512x512.png"
render_png 1024 "$ICONSET_DIR/icon_512x512@2x.png"
render_png 1024 "$MARKETING_ICON_PATH"

/usr/bin/iconutil -c icns "$ICONSET_DIR" -o "$ICNS_PATH"

printf '%s\n' "$ICNS_PATH"
