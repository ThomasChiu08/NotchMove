# NotchMove

NotchMove is a native macOS accessory app that reminds users to stand up and move with a notch-shaped overlay. It runs from the menu bar, tracks active computer usage, and presents the reminder on notch Macs or a centered fallback on other displays.

## Build

```bash
xcodebuild -project NotchMove/NotchMove.xcodeproj \
  -scheme NotchMove \
  -destination 'platform=macOS' \
  build
```

## Test

```bash
xcodebuild -project NotchMove/NotchMove.xcodeproj \
  -scheme NotchMove \
  -destination 'platform=macOS' \
  test
```

## Runtime Overview

- `PreferencesStore` is the single source of truth for persisted app preferences.
- `BreakStatsStore` owns daily and weekly break counters.
- `ReminderEngine` owns reminder timing, pause/schedule state, hover preview state, and presentation lifecycle.
- `NotchWindowController` renders the overlay and applies `ScreenPlacementService` output.
- `MenuBarController` emits user intents and renders current reminder/break status on demand.

See [ARCHITECTURE.md](./ARCHITECTURE.md) for the detailed runtime flow.
