#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-}"
EXPECTED_BUNDLE_ID="com.thomaschiu.developer.NotchMove"
EXPECTED_CODE_SIGN_AUTHORITY="${EXPECTED_CODE_SIGN_AUTHORITY:-Developer ID Application}"
REQUIRE_GATEKEEPER_ACCEPTED="${REQUIRE_GATEKEEPER_ACCEPTED:-0}"

fail() {
  printf 'privacy verification failed: %s\n' "$1" >&2
  exit 1
}

if [[ -z "$APP_PATH" ]]; then
  fail "usage: $0 /path/to/NotchMove.app"
fi

if [[ ! -d "$APP_PATH" ]]; then
  fail "app bundle not found: $APP_PATH"
fi

INFO_PLIST="$APP_PATH/Contents/Info.plist"
if [[ ! -f "$INFO_PLIST" ]]; then
  fail "Info.plist not found in app bundle"
fi

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$INFO_PLIST" 2>/dev/null || true
}

require_info_value() {
  local key="$1"
  local value
  value="$(plist_value "$key")"
  if [[ -z "$value" ]]; then
    fail "missing Info.plist key: $key"
  fi
}

bundle_id="$(plist_value "CFBundleIdentifier")"
if [[ "$bundle_id" != "$EXPECTED_BUNDLE_ID" ]]; then
  fail "unexpected bundle id: ${bundle_id:-<missing>} (expected $EXPECTED_BUNDLE_ID)"
fi

require_info_value "NSMicrophoneUsageDescription"
require_info_value "NSSpeechRecognitionUsageDescription"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/notchmove-entitlements.XXXXXX")"
ENTITLEMENTS_PLIST="$TMP_DIR/entitlements.plist"
trap 'rm -rf "$TMP_DIR"' EXIT

if ! codesign -d --entitlements "$ENTITLEMENTS_PLIST" "$APP_PATH" >/dev/null 2>/dev/null; then
  fail "unable to read code signing entitlements"
fi

if ! codesign --verify --deep --strict --verbose=2 "$APP_PATH" >/dev/null 2>&1; then
  fail "code signature verification failed"
fi

SIGNING_DETAILS="$(codesign -dvvv "$APP_PATH" 2>&1 || true)"
if [[ "$SIGNING_DETAILS" != *"Authority=$EXPECTED_CODE_SIGN_AUTHORITY"* ]]; then
  fail "unexpected signing authority; expected an authority containing '$EXPECTED_CODE_SIGN_AUTHORITY'"
fi

if [[ "$SIGNING_DETAILS" != *"Runtime Version="* ]]; then
  fail "hardened runtime is missing from code signature"
fi

if [[ "$REQUIRE_GATEKEEPER_ACCEPTED" == "1" ]]; then
  if ! spctl -a -vv "$APP_PATH" >/dev/null 2>&1; then
    fail "Gatekeeper assessment failed"
  fi
fi

entitlement_value() {
  local key="$1"
  local value
  if value="$(/usr/libexec/PlistBuddy -c "Print :$key" "$ENTITLEMENTS_PLIST" 2>/dev/null)"; then
    printf '%s\n' "$value"
    return
  fi

  awk -v key="$key" '
    index($0, "[Key] " key) { found = 1; next }
    found && index($0, "[Bool] true") { print "true"; exit }
    found && index($0, "[Bool] false") { print "false"; exit }
    found && index($0, "[Key] ") { exit }
  ' "$ENTITLEMENTS_PLIST"
}

require_entitlement_true() {
  local key="$1"
  local value
  value="$(entitlement_value "$key")"
  if [[ "$value" != "true" ]]; then
    fail "missing or false entitlement: $key"
  fi
}

require_entitlement_true "com.apple.security.app-sandbox"
require_entitlement_true "com.apple.security.device.microphone"
require_entitlement_true "com.apple.security.network.client"

printf 'privacy verification passed: %s\n' "$APP_PATH"
