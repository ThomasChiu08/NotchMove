#!/usr/bin/env bash
set -euo pipefail

APP_NAME="NotchMove"
VERSION="${VERSION:-1.0}"
CHANNEL="${CHANNEL:-test}"
BUILD_STAMP="${BUILD_STAMP:-$(date +%Y%m%d-%H%M)}"
DMG_NAME="${DMG_NAME:-$APP_NAME-$VERSION-$CHANNEL-$BUILD_STAMP.dmg}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/NotchMove/NotchMove.xcodeproj"
DERIVED_DATA_PATH="$ROOT_DIR/NotchMove/build/DerivedData"
RELEASE_APP="$DERIVED_DATA_PATH/Build/Products/Release/$APP_NAME.app"
STAGING_DIR="$ROOT_DIR/NotchMove/build/dmg-staging"
STAGING_APP="$STAGING_DIR/$APP_NAME.app"
DIST_DIR="$ROOT_DIR/NotchMove/dist"
DMG_PATH="$DIST_DIR/$DMG_NAME"
VERIFY_SCRIPT="$ROOT_DIR/script/verify_release_privacy.sh"
GUIDE_SOURCE="$ROOT_DIR/docs/FRIEND_TEST_INSTALL_USAGE.zh-Hans.md"
GUIDE_NAME="NotchMove-Install-Usage-zh-Hans.md"

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
if [[ -f "$GUIDE_SOURCE" ]]; then
  cp "$GUIDE_SOURCE" "$STAGING_DIR/$GUIDE_NAME"
else
  printf 'warning: install guide not found: %s\n' "$GUIDE_SOURCE" >&2
fi

"$VERIFY_SCRIPT" "$STAGING_APP"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

printf 'packaged: %s\n' "$DMG_PATH"
