#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/NotchMove-DerivedData}"

cd "$ROOT_DIR"

echo "== git diff --check =="
git diff --check

echo "== plutil -lint =="
plutil -lint \
  NotchMove/NotchMove.xcodeproj/project.pbxproj \
  NotchMove/NotchMove/NotchMove.entitlements \
  NotchMove/NotchMove/Resources/en.lproj/Localizable.strings \
  NotchMove/NotchMove/Resources/zh-Hans.lproj/Localizable.strings \
  NotchMove/NotchMove/Resources/zh-Hant.lproj/Localizable.strings \
  NotchMove/NotchMove/Resources/ja.lproj/Localizable.strings

echo "== localization parity =="
python3 script/check_localization_keys.py

echo "== source privacy and distribution safety =="
script/check_source_privacy.sh

echo "== xcodebuild test =="
xcodebuild \
  -project NotchMove/NotchMove.xcodeproj \
  -scheme NotchMove \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  test
