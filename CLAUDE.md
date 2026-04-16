# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**NotchMove** is a macOS utility app (targeting macOS 26.2+) built with SwiftUI + SwiftData. The project is at its initial stage — currently just the Xcode default template.

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

MVVM with SwiftData for persistence. Default structure to follow when adding features:

```
NotchMove/NotchMove/
├── App/
│   └── NotchMoveApp.swift      # @main, ModelContainer setup
├── Features/
│   └── <Feature>/
│       ├── <Feature>View.swift
│       ├── <Feature>ViewModel.swift
│       └── <Feature>Service.swift   # if needed
├── Core/
│   ├── Models/                 # @Model SwiftData types
│   ├── Services/
│   └── Extensions/
└── Resources/
```

Currently all code lives flat in `NotchMove/NotchMove/`. Migrate to this structure as features are added.

## Key Conventions

- **SwiftData models**: Use `@Model` macro, defined in `Core/Models/`. The existing `Item.swift` is a placeholder — delete when building real models.
- **ViewModel**: Use `@Observable` (not `ObservableObject`) — macOS 26.2 supports it fully.
- **macOS-specific**: This is macOS only (no iOS target). Use `NSStatusBar` / `NSStatusItem` APIs for notch/menu bar functionality when implementing the core feature.
- **Testing**: `NotchMoveTests` (XCTest) for unit tests, `NotchMoveUITests` for UI tests.
