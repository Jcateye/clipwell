#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DMG_PATH="${1:-$ROOT_DIR/dist/Clipwell.dmg}"
KEYCHAIN_PROFILE="${NOTARYTOOL_PROFILE:-}"

if [[ -z "$KEYCHAIN_PROFILE" ]]; then
  cat >&2 <<'EOF'
error: set NOTARYTOOL_PROFILE to an xcrun notarytool keychain profile.

Create one first, for example:
  xcrun notarytool store-credentials clipwell-notary \
    --apple-id you@example.com \
    --team-id YOURTEAMID \
    --password app-specific-password

Then run:
  NOTARYTOOL_PROFILE=clipwell-notary scripts/notarize_dmg.sh
EOF
  exit 1
fi

xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$KEYCHAIN_PROFILE" \
  --wait

xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
