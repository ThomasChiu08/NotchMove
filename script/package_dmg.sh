#!/usr/bin/env bash
set -euo pipefail

APP_NAME="NotchMove"
DMG_NAME="NotchMove-1.0.dmg"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/NotchMove/NotchMove.xcodeproj"
DERIVED_DATA_PATH="$ROOT_DIR/NotchMove/build/DerivedData"
RELEASE_APP="$DERIVED_DATA_PATH/Build/Products/Release/$APP_NAME.app"
STAGING_DIR="$ROOT_DIR/NotchMove/build/dmg-staging"
STAGING_APP="$STAGING_DIR/$APP_NAME.app"
DIST_DIR="$ROOT_DIR/NotchMove/dist"
DMG_PATH="$DIST_DIR/$DMG_NAME"
VERIFY_SCRIPT="$ROOT_DIR/script/verify_release_privacy.sh"

if [[ ! -x "$VERIFY_SCRIPT" ]]; then
  printf 'missing executable verifier: %s\n' "$VERIFY_SCRIPT" >&2
  exit 1
fi

rm -rf "$RELEASE_APP" "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR" "$DIST_DIR"

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  clean build

"$VERIFY_SCRIPT" "$RELEASE_APP"

ditto "$RELEASE_APP" "$STAGING_APP"
ln -s /Applications "$STAGING_DIR/Applications"

"$VERIFY_SCRIPT" "$STAGING_APP"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

printf 'packaged: %s\n' "$DMG_PATH"
