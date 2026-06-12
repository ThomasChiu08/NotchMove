#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENTITLEMENTS="$ROOT_DIR/NotchMove/NotchMove/NotchMove.entitlements"
PROJECT_FILE="$ROOT_DIR/NotchMove/NotchMove.xcodeproj/project.pbxproj"

fail() {
  printf 'source privacy check failed: %s\n' "$1" >&2
  exit 1
}

require_entitlement_true() {
  local key="$1"
  local value
  value="$(/usr/libexec/PlistBuddy -c "Print :$key" "$ENTITLEMENTS" 2>/dev/null || true)"
  if [[ "$value" != "true" ]]; then
    fail "missing or false entitlement: $key"
  fi
}

require_entitlement_absent() {
  local key="$1"
  if /usr/libexec/PlistBuddy -c "Print :$key" "$ENTITLEMENTS" >/dev/null 2>&1; then
    fail "unexpected broad entitlement: $key"
  fi
}

require_project_setting() {
  local setting="$1"
  if ! grep -Fq "$setting" "$PROJECT_FILE"; then
    fail "missing project setting: $setting"
  fi
}

required_entitlements=(
  "com.apple.security.app-sandbox"
  "com.apple.security.automation.apple-events"
  "com.apple.security.device.camera"
  "com.apple.security.device.microphone"
  "com.apple.security.files.user-selected.read-write"
  "com.apple.security.network.client"
  "com.apple.security.personal-information.calendars"
)

for entitlement in "${required_entitlements[@]}"; do
  require_entitlement_true "$entitlement"
done

blocked_entitlements=(
  "com.apple.security.files.all"
  "com.apple.security.files.downloads.read-only"
  "com.apple.security.files.downloads.read-write"
  "com.apple.security.files.desktop.read-only"
  "com.apple.security.files.desktop.read-write"
  "com.apple.security.files.documents.read-only"
  "com.apple.security.files.documents.read-write"
  "com.apple.security.files.home-relative-path.read-only"
  "com.apple.security.files.home-relative-path.read-write"
)

for entitlement in "${blocked_entitlements[@]}"; do
  require_entitlement_absent "$entitlement"
done

required_project_settings=(
  "CODE_SIGN_ENTITLEMENTS = NotchMove/NotchMove.entitlements;"
  "ENABLE_HARDENED_RUNTIME = YES;"
  "PRODUCT_BUNDLE_IDENTIFIER = com.thomaschiu.developer.NotchMove;"
  "INFOPLIST_KEY_NSAppleEventsUsageDescription ="
  "INFOPLIST_KEY_NSCameraUsageDescription ="
  "INFOPLIST_KEY_NSCalendarsFullAccessUsageDescription ="
  "INFOPLIST_KEY_NSCalendarsUsageDescription ="
  "INFOPLIST_KEY_NSMicrophoneUsageDescription ="
  "INFOPLIST_KEY_NSSpeechRecognitionUsageDescription ="
)

for setting in "${required_project_settings[@]}"; do
  require_project_setting "$setting"
done

quarantine_bypass_command="xattr -dr com.apple.""quarantine"
grep_output="$(mktemp "${TMPDIR:-/tmp}/notchmove-quarantine-grep.XXXXXX")"
trap 'rm -f "$grep_output"' EXIT

if grep -R --line-number -F "$quarantine_bypass_command" "$ROOT_DIR/docs" "$ROOT_DIR/README.md" >"$grep_output" 2>/dev/null; then
  cat "$grep_output" >&2
  fail "distribution docs must not tell users to bypass Gatekeeper quarantine"
fi

cleartext_url_literal='URL(string: "http:'"//"
if grep -R --line-number -F "$cleartext_url_literal" "$ROOT_DIR/NotchMove/NotchMove" >"$grep_output" 2>/dev/null; then
  cat "$grep_output" >&2
  fail "app sources must not hard-code cleartext HTTP URLs"
fi

printf 'source privacy check passed\n'
