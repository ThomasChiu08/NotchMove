# Lightweight Focus Notch Hub Plan

Date: 2026-06-08
Status: Proposed plan for Scheme A
Scope: Product and implementation plan for making Notch Hub a reminder-first, lightweight focus surface.

## Context

NotchMove is strongest when it has one clear job: quietly monitor active Mac
usage and interrupt at the right moment with a notch-aligned movement or focus
reminder. The current Notch Hub implementation already includes seven widgets:
Live, Media, Calendar, Shortcuts, Notes, Mirror, and Tray.

That breadth creates a product risk. If every useful desktop micro-tool is
visible by default, Hub starts to feel like a small control center instead of a
supporting layer for NotchMove's health and focus reminder flow.

Scheme A keeps Hub, but narrows its default role: a lightweight focus hub that
helps the user answer three questions quickly:

1. What is my current reminder/focus state?
2. What is the next time-sensitive item?
3. What quick note or action do I need to capture without opening a full app?

## Reverse Thinking

Hub fails if:

- It makes NotchMove's product sentence unclear.
- It asks for too many permissions before the user sees value.
- It competes with active reminders or voice input for the same notch surface.
- It exposes seven equal-looking widgets, but none are important enough to
  become a habit.
- It turns Settings into a dense matrix of feature toggles.
- It uses high-friction integrations such as Camera, Files, Apple Events, or
  Shortcuts as first-run defaults.

Therefore, the plan optimizes by subtraction first:

- Keep Hub optional.
- Make the first Hub experience local, low-permission, and reminder-aligned.
- Move sensitive or power-user widgets out of the default path.
- Treat reminders and voice input as higher-priority surfaces than Hub.

## Recommended Product Shape

The default Hub should become a "Focus Overview" instead of a tab strip of seven
equal widgets.

Default visible modules:

- Live: next stand reminder, pomodoro/focus state, paused/disabled state.
- Calendar: upcoming local schedule item, with optional external Calendar
  access only after user request.
- Notes: a compact local scratch note.

Optional visible module:

- Media: useful, but should stay permission-gated and disabled by default until
  the user opts in to Apple Events.

Advanced modules:

- Shortcuts: useful for power users, but too configuration-heavy for default
  onboarding.
- Tray: useful but file-permission sensitive and conceptually less tied to
  reminders.
- Mirror: camera access is high-trust and should not be a default Hub signal.

## UX Plan

### First Open

When the user enables and opens Hub, show a Focus Overview as the default
surface. It should fit the existing expanded notch panel dimensions and avoid
feeling like a dashboard card stack.

The overview should contain:

- A compact reminder status row.
- A compact pomodoro/focus row when pomodoro is enabled or active.
- The next local schedule item, if available.
- A quick note text area or one-line scratch capture.

The widget icon row can remain, but should only show default modules:

- Live or Overview
- Calendar
- Notes

Media appears only after the user enables it. Shortcuts, Tray, and Mirror appear
only under an advanced setting.

### Settings

Replace the "all widgets equal" mental model with grouped settings:

- Core: Focus Overview, Calendar, Notes.
- Optional: Media controls.
- Advanced local tools: Shortcuts, File Tray, Camera Mirror.

Sensitive toggles should explain what permission they may trigger, but the app
should defer the actual permission prompt until the user opens or uses that
module.

### Priority Behavior

Hub must continue to yield to:

1. Voice input overlay.
2. Active break reminder or reminder dismissal animation.
3. Reminder hover preview, when Hub is not explicitly open.

If a reminder becomes active while Hub is open, the reminder should take over
the notch surface. Hub may collapse or stay logically selected, but it must not
block reminder presentation.

## Technical Plan

### Phase 1: Classify Widgets

Add a stable widget classification in the Notch Hub model layer:

- `core`
- `optional`
- `advanced`

Use that classification for defaults, settings grouping, and migration.

Expected files:

- `NotchMove/NotchMove/Features/NotchHub/NotchHubModels.swift`
- `NotchMove/NotchMove/Features/Settings/SettingsView.swift`
- `NotchMove/NotchMoveTests/NotchMoveTests.swift`

Acceptance criteria:

- New installs default to the core widget set only.
- Existing users keep their stored enabled widgets.
- Live or Focus Overview cannot be removed if it is the required fallback.

### Phase 2: Build Focus Overview

Introduce a first-class overview surface that composes existing local state
instead of adding a new integration.

Expected files:

- `NotchMove/NotchMove/Features/NotchHub/NotchHubViews.swift`
- `NotchMove/NotchMove/Features/NotchHub/NotchHubModels.swift`
- `NotchMove/NotchMove/Features/Notch/NotchView.swift`

Acceptance criteria:

- Opening Hub lands on the overview by default.
- The overview shows reminder state without invoking sensitive providers.
- Calendar external events are fetched only when Calendar access is enabled.
- Media provider is not queried unless Apple Events are enabled.

### Phase 3: Simplify Settings

Make Settings read like product decisions instead of implementation switches.

Expected files:

- `NotchMove/NotchMove/Features/Settings/SettingsView.swift`
- Localization files under `NotchMove/NotchMove/Resources/*.lproj/Localizable.strings`

Acceptance criteria:

- Core, Optional, and Advanced groups are visually and semantically separated.
- Advanced widgets are not presented as first-run essentials.
- Permission copy is clear and local-first.
- Default widget picker cannot select disabled or unavailable widgets.

### Phase 4: Preserve Surface Priority

Keep Hub below voice and active reminders in the surface resolver and production
paths.

Expected files:

- `NotchMove/NotchMove/Features/NotchHub/NotchHubModels.swift`
- `NotchMove/NotchMove/Features/Notch/NotchWindowController.swift`
- `NotchMove/NotchMove/Features/Notch/NotchView.swift`
- `NotchMove/NotchMoveTests/NotchMoveTests.swift`

Acceptance criteria:

- Voice input always wins over Hub.
- Active reminders always win over Hub.
- Hover preview still behaves according to the existing motion design.
- `visibleSize` hit testing remains intact.

### Phase 5: Tests And Migration

Add regression coverage around defaults and permission boundaries.

Test cases:

- Fresh defaults enable only the Scheme A core set.
- Existing stored widget preferences are preserved.
- Disabling optional/advanced widgets normalizes the selected/default widget.
- Media status refresh does not call the provider while Apple Events are off.
- Calendar external fetch does not run until Calendar access is enabled.
- Hub collapses or yields when reminder presentation becomes active.

## Non-Goals

Do not:

- Add new external services.
- Add cloud sync, accounts, or analytics.
- Make Hub the main product surface.
- Request Camera, Files, Calendar, Apple Events, or Shortcuts permissions during
  first open.
- Expand the notch panel into a large dashboard.
- Rework the reminder engine beyond what is necessary for priority correctness.

## Verification Plan

Run after implementation:

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

If package state is stale, run first:

```sh
xcodebuild -resolvePackageDependencies \
  -project NotchMove/NotchMove.xcodeproj \
  -scheme NotchMove
```

## Implementation Prompt

```text
Please continue in /Users/thomaschiu/Public/Codex/MacOS/NotchMove_codex/NotchMove_codex_V1.

Read docs/plans/2026-06-08-lightweight-focus-notch-hub-plan.md first.

Implement Scheme A: make Notch Hub a lightweight reminder-first Focus Hub.

Requirements:
1. Classify Notch Hub widgets into core, optional, and advanced groups.
2. Fresh installs should default to the core set only: Live/Focus Overview, Calendar, and Notes.
3. Preserve existing stored widget preferences during migration.
4. Make Hub open to a Focus Overview that combines local reminder/focus status, next local schedule item, and quick notes without triggering sensitive integrations.
5. Keep Media optional and Apple Events-gated. Do not query media status until Apple Events are explicitly enabled.
6. Move Shortcuts, File Tray, and Camera Mirror into advanced settings/default-hidden behavior.
7. Keep voice input and active reminders ahead of Hub in production overlay priority.
8. Preserve existing hover-preview motion and visibleSize hit-testing.
9. Add focused tests for defaults, migration, permission gating, widget normalization, and surface priority.

Do not add cloud sync, accounts, analytics, new external services, or a large dashboard surface.

After editing, run git diff --check, plutil -lint on project/entitlements/localization files, and xcodebuild -project NotchMove/NotchMove.xcodeproj -scheme NotchMove -destination 'platform=macOS' -derivedDataPath /tmp/NotchMove-DerivedData test if the environment allows it. Report exact verification results.
```
