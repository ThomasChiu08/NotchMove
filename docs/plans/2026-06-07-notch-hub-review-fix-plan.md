# Notch Hub Review Fix Plan

Date: 2026-06-07
Branch: codex/daily-schedule-reminders
Latest reviewed commit: 673d6e8 feat: add notch hub widgets

## Context

NotchMove now has a Notch Hub layer with media, calendar, shortcuts, notes,
mirror, and file tray widgets. The feature is intended to stay optional and
permission-gated while preserving the reminder-first overlay behavior.

The review found several issues that should be fixed before this branch is
merged or released.

## Findings To Fix

### P1: Media status refresh bypasses the Apple Events gate

`NotchHubStore.refreshActiveWidget()` refreshes media status whenever the active
widget is `.media`. That calls `SystemMediaControlProvider.currentStatus()`,
which uses AppleScript to query Music or Spotify. This can trigger macOS
Automation permission prompts even when `preferences.allowAppleEvents` is false.

Fix:
- Gate `refreshMediaStatus()` or the `.media` branch in `refreshActiveWidget()`
  behind `preferences.allowAppleEvents`.
- When disabled, reset `mediaStatus` to unavailable or leave it unchanged, but
  do not call the provider.
- Add a unit test proving that selecting or opening Media does not call the
  provider until `allowAppleEvents` is true.

Relevant files:
- `NotchMove/NotchMove/Features/NotchHub/NotchHubModels.swift`
- `NotchMove/NotchMove/Features/NotchHub/NotchHubProviders.swift`
- `NotchMove/NotchMoveTests/NotchMoveTests.swift`

### P2: Camera session starts on the main thread

`CameraMirrorPreview.Coordinator.configureIfNeeded()` calls
`AVCaptureSession.startRunning()` from the SwiftUI/AppKit view path. This can
block the main thread and hurt overlay animation/input responsiveness.

Fix:
- Add a serial `DispatchQueue` inside `CameraMirrorPreview.Coordinator`.
- Run AVCaptureSession configuration, `startRunning()`, and `stopRunning()` on
  that queue.
- Keep layer creation and layout on the main thread.
- Ensure `dismantleNSView` stops the session through the same queue.

Relevant file:
- `NotchMove/NotchMove/Features/NotchHub/NotchHubViews.swift`

### P2: Hub presentation can remain expanded after disabling Hub or current widget

Settings bind directly to `notchHubStore.preferences.isEnabled`. If Hub is open
and the user disables it, `presentation` can remain `.widget(...)`. Re-enabling
can unexpectedly reopen the Hub. Similarly, disabling the current widget
normalizes selection but does not update the active presentation.

Fix:
- Add explicit store APIs for enabling/disabling Hub and widgets, instead of
  binding settings directly to `preferences`.
- Collapse when Hub is disabled.
- If disabling the active widget while expanded, move `presentation` to the
  normalized selected widget.
- Add unit tests for both transitions.

Relevant files:
- `NotchMove/NotchMove/Features/NotchHub/NotchHubModels.swift`
- `NotchMove/NotchMove/Features/Settings/SettingsView.swift`
- `NotchMove/NotchMoveTests/NotchMoveTests.swift`

### P3: Priority resolver is tested but not used by production code

`NotchHubPresentationResolver` is unit-tested, but production logic still uses
hand-written priority checks in `NotchWindowController` and `NotchView`.
This can let tests pass while real overlay priority drifts.

Fix:
- Either route production priority through `NotchHubPresentationResolver`, or
  replace the resolver tests with tests that exercise production computed
  surface behavior.
- Keep voice overlay and active reminder ahead of Hub.
- Preserve `visibleSize` hit-testing in `NotchWindowController`.

Relevant files:
- `NotchMove/NotchMove/Features/NotchHub/NotchHubModels.swift`
- `NotchMove/NotchMove/Features/Notch/NotchWindowController.swift`
- `NotchMove/NotchMove/Features/Notch/NotchView.swift`
- `NotchMove/NotchMoveTests/NotchMoveTests.swift`

### Repo hygiene: DMG artifacts are tracked

The PR includes multiple generated DMG files under `NotchMove/dist/`, about
31 MB total. If these are not intended source artifacts, move them to GitHub
Releases or another artifact store and add ignore rules for generated release
outputs.

Relevant paths:
- `NotchMove/dist/*.dmg`
- `NotchMove/build/dmg-staging/`

## Verification Plan

Run these after fixes:

```sh
git diff --check
plutil -lint \
  NotchMove/NotchMove.xcodeproj/project.pbxproj \
  NotchMove/NotchMove/NotchMove.entitlements \
  NotchMove/NotchMove/Resources/en.lproj/Localizable.strings \
  NotchMove/NotchMove/Resources/zh-Hans.lproj/Localizable.strings \
  NotchMove/NotchMove/Resources/zh-Hant.lproj/Localizable.strings \
  NotchMove/NotchMove/Resources/ja.lproj/Localizable.strings
xcodebuild -project NotchMove/NotchMove.xcodeproj \
  -scheme NotchMove \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/NotchMove-DerivedData \
  test
```

If Xcode package state is stale, first run:

```sh
xcodebuild -resolvePackageDependencies \
  -project NotchMove/NotchMove.xcodeproj \
  -scheme NotchMove
```

## Prompt For Next Conversation

```text
Please continue in /Users/thomaschiu/Public/Codex/MacOS/NotchMove_codex/NotchMove_codex_V1.

Read docs/plans/2026-06-07-notch-hub-review-fix-plan.md first, then implement the fixes in priority order:
1. P1: Media status refresh must not call AppleScript/provider until Notch Hub Apple Events is explicitly enabled. Add a regression test.
2. P2: Move CameraMirrorPreview AVCaptureSession start/stop/configuration off the main thread onto a serial queue.
3. P2: Add NotchHubStore APIs so disabling Hub collapses it, and disabling the active widget updates presentation to the normalized selected widget. Update SettingsView to use those APIs and add tests.
4. P3: Either route production overlay priority through NotchHubPresentationResolver or replace resolver-only tests with production-path tests.

Preserve the existing reminder-first overlay behavior and visibleSize hit-testing. Do not revert unrelated changes. After editing, run git diff --check, plutil -lint on project/entitlements/localization files, and xcodebuild -project NotchMove/NotchMove.xcodeproj -scheme NotchMove -destination 'platform=macOS' -derivedDataPath /tmp/NotchMove-DerivedData test if the environment allows it. Report exact verification results.
```
