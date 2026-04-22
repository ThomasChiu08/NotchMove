# Architecture

## Core State

- `PreferencesStore` hydrates from `AppSettings` on launch and persists every preference mutation back to `UserDefaults`.
- `BreakStatsStore` persists completed-break counters directly in `UserDefaults` and exposes observable daily/weekly totals.
- `ReminderEngine` is the only reminder lifecycle state source. It owns:
  - active time accumulation
  - manual pause state
  - schedule gating state
  - hover preview state
  - presenting / dismissing reminder state

## Runtime Flow

1. `AppDelegate` creates `PreferencesStore`, `BreakStatsStore`, `LanguageManager`, `ActivityMonitor`, `ReminderEngine`, and the window/menu/settings controllers.
2. `ActivityMonitor` polls system idle time every 5 seconds.
3. `ReminderEngine` ticks every 5 seconds, evaluates schedule and idle state, and triggers reminder presentation when the configured interval is reached.
4. `MenuBarController` sends reminder intents such as pause/resume and manual trigger.
5. `NotchWindowController` observes `ReminderEngine.state.presentation`, asks `ScreenPlacementService` for geometry, and animates the `NSPanel`.
6. `SettingsView` edits `PreferencesStore.preferences` directly. No `UserDefaults.didChangeNotification` bridge is used.

## Placement Model

- `ScreenPlacementService` is a pure geometry service.
- `MainScreenProvider` adapts `NSScreen.main` into a `ScreenDescriptor`.
- `OverlayPlacement` contains the final panel frame and the top inset consumed by `NotchView`.

## Testing Focus

- `SchedulePolicy` is covered with direct rule tests.
- `PreferencesStore` tests protect restore-default semantics, including language reset.
- `BreakStatsStore` tests protect counter persistence behavior.
- `ReminderEngine` tests protect pause/schedule composition, automatic triggering, completion, auto-dismiss, and preference-driven cancellation.
- `ScreenPlacementService` tests protect notch and non-notch positioning behavior.
