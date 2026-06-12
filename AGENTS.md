# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Project Overview

**NotchMove** is a native macOS accessory utility (targeting macOS 26.2+) built with SwiftUI + AppKit. It runs from the menu bar, monitors active computer usage, and presents a notch-shaped reminder overlay on notch Macs with a centered fallback on other displays.

## Build & Test Commands

```bash
# Build (from repo root)
xcodebuild -project NotchMove/NotchMove.xcodeproj \
  -scheme NotchMove \
  -destination 'platform=macOS' \
  build

# Run unit tests
xcodebuild -project NotchMove/NotchMove.xcodeproj \
  -scheme NotchMove \
  -destination 'platform=macOS' \
  test

# Run a single test class
xcodebuild -project NotchMove/NotchMove.xcodeproj \
  -scheme NotchMove \
  -destination 'platform=macOS' \
  -only-testing:NotchMoveTests/NotchMoveTests \
  test
```

## Architecture

Current architecture is intentionally lightweight:

```
NotchMove/NotchMove/
├── App/
│   └── AppDelegate.swift             # runtime composition root
├── Features/
│   ├── MenuBar/                      # NSStatusItem and menu actions
│   ├── Notch/                        # overlay view, view model, and window control
│   └── Settings/                     # SwiftUI settings window
├── Core/
│   ├── Services/                     # settings, schedule policy, activity/scheduler logic
│   └── Extensions/                   # NSScreen notch helpers
└── Resources/                        # localized strings
```

Persistence is currently `UserDefaults`-based through `AppSettings`; there is no SwiftData model layer yet.

## Key Conventions

- **Persistence**: Keep persisted app preferences in `AppSettings`. Add SwiftData only if the app starts storing durable history or richer user-managed records.
- **ViewModel**: Use `@Observable` (not `ObservableObject`) — macOS 26.2 supports it fully.
- **macOS-specific**: This is macOS only (no iOS target). Use `NSStatusBar` / `NSStatusItem` APIs for notch/menu bar functionality when implementing the core feature.
- **Testing**: Keep the default test path focused on `NotchMoveTests` until the accessory-app UI tests have a dedicated harness.
