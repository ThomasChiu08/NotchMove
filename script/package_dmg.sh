#!/usr/bin/env bash
set -euo pipefail

APP_NAME="NotchMove"
VOLUME_NAME="${VOLUME_NAME:-$APP_NAME Installer}"
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
RW_DMG_PATH="$DIST_DIR/${DMG_NAME%.dmg}.rw.dmg"
VERIFY_SCRIPT="$ROOT_DIR/script/verify_release_privacy.sh"
GUIDE_SOURCE="$ROOT_DIR/docs/FRIEND_TEST_INSTALL_USAGE.zh-Hans.md"
GUIDE_NAME="NotchMove-Install-Usage-zh-Hans.md"
BACKGROUND_SOURCE="$ROOT_DIR/NotchMove/Packaging/NotchMove-dmg-background.png"
BACKGROUND_NAME="NotchMove-dmg-background.png"
MOUNT_PATH=""

cleanup() {
  if [[ -n "$MOUNT_PATH" && -d "$MOUNT_PATH" ]]; then
    hdiutil detach "$MOUNT_PATH" -quiet || hdiutil detach "$MOUNT_PATH" -force -quiet || true
  fi
  rm -f "$RW_DMG_PATH"
}

detach_existing_volume_mounts() {
  local volume
  for volume in "/Volumes/$VOLUME_NAME" /Volumes/"$VOLUME_NAME "*; do
    if [[ -e "$volume" ]]; then
      hdiutil detach "$volume" -quiet || true
    fi
  done
}

trap cleanup EXIT

if [[ ! -x "$VERIFY_SCRIPT" ]]; then
  printf 'missing executable verifier: %s\n' "$VERIFY_SCRIPT" >&2
  exit 1
fi

if [[ ! -f "$BACKGROUND_SOURCE" ]]; then
  printf 'missing DMG background: %s\n' "$BACKGROUND_SOURCE" >&2
  exit 1
fi

rm -rf "$RELEASE_APP" "$STAGING_DIR" "$DMG_PATH" "$RW_DMG_PATH"
mkdir -p "$STAGING_DIR/.background" "$DIST_DIR"

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
cp "$BACKGROUND_SOURCE" "$STAGING_DIR/.background/$BACKGROUND_NAME"

"$VERIFY_SCRIPT" "$STAGING_APP"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDRW \
  "$RW_DMG_PATH"

detach_existing_volume_mounts
MOUNT_INFO="$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG_PATH")"
MOUNT_PATH="$(printf '%s\n' "$MOUNT_INFO" | awk '/\/Volumes\// {print substr($0, index($0, "/Volumes/")); exit}')"
if [[ -z "$MOUNT_PATH" || ! -d "$MOUNT_PATH" ]]; then
  printf 'unable to find mounted DMG path\n%s\n' "$MOUNT_INFO" >&2
  exit 1
fi

osascript - "$VOLUME_NAME" "$GUIDE_NAME" "$BACKGROUND_NAME" "$MOUNT_PATH" <<'APPLESCRIPT'
on run argv
  set volumeName to item 1 of argv
  set guideName to item 2 of argv
  set backgroundName to item 3 of argv
  set mountPath to item 4 of argv
  set backgroundFile to POSIX file (mountPath & "/.background/" & backgroundName)

  tell application "Finder"
    activate
    tell disk volumeName
      open
      delay 1
      set current view of container window to icon view
      set toolbar visible of container window to false
      set statusbar visible of container window to false
      set bounds of container window to {100, 100, 1000, 700}

      set viewOptions to icon view options of container window
      set arrangement of viewOptions to not arranged
      set icon size of viewOptions to 96
      set background picture of viewOptions to backgroundFile

      set position of item "NotchMove.app" of container window to {190, 330}
      set position of item "Applications" of container window to {710, 330}
      if exists item guideName of container window then
        set position of item guideName of container window to {450, 470}
      end if

      update without registering applications
      delay 2
      close
      delay 1
    end tell
  end tell
end run
APPLESCRIPT

sync
if [[ ! -f "$MOUNT_PATH/.DS_Store" ]]; then
  printf 'DMG Finder layout was not written; missing .DS_Store at %s\n' "$MOUNT_PATH" >&2
  exit 1
fi

hdiutil detach "$MOUNT_PATH" -quiet
MOUNT_PATH=""

hdiutil convert \
  "$RW_DMG_PATH" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG_PATH" >/dev/null

printf 'packaged: %s\n' "$DMG_PATH"
