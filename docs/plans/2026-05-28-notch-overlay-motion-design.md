# Notch Overlay Motion Redesign

Date: 2026-05-28

Updated: 2026-06-04

## Goal

Make the NotchMove overlay feel like a native macOS notch surface: the visible island should grow out of the physical notch, reveal content after the body has started expanding, and collapse back into the notch without visible AppKit resize stutter.

## Current Problem

The existing implementation animates the `NSPanel` frame and SwiftUI content at the same time. The reminder state jumps directly to `.presenting`, so the existing `.reminderPending` notch-sized state is not used as a visual staging phase. The content insertion transition only moves by a few points, which reads as a fade rather than a notch reveal.

This makes the overlay appear as a window resize with content fading in, not as a native surface emerging from the notch.

## Design

Use a staged, state-driven motion pipeline:

1. Reminder starts in `.reminderPending`, with an expanded transparent panel canvas already positioned around the notch while the visible island and hit-test area remain tucked.
2. After a short preflight delay, the reminder promotes to `.presenting`.
3. During `.presenting`, the visible SwiftUI island expands inside that prepared canvas.
4. The visible SwiftUI island animates its own frame from the tucked size to the expanded size.
5. Content uses a top-reveal transition with opacity, scale, and vertical offset after the shape begins expanding.
6. During `.dismissAnimating`, the panel stays expanded while the SwiftUI island collapses back to the tucked size.
7. Once the engine settles to `.hidden`, the panel shrinks back to the tucked frame.

Hover preview uses the same separation: `.hoverPreviewPending` and `.hoverPreviewDismissing` may own the expanded transparent canvas, but visible size and hit testing stay tucked until `.hoverPreview` is active. The intended hover timing is a quick entry promotion of about 70 ms and a calmer dismissal of about 240 ms.

## Architecture

`ReminderEngine` owns presentation phases and schedules the short promotion from `.reminderPending` to `.presenting`. It cancels that promotion when a reminder is cancelled, completed, snoozed, or dismissed.

`ScreenPlacementService` remains the geometry authority. It keeps hidden tucked, lets pending/dismissing phases use expanded canvas geometry when needed, and separately reports `visibleSize` so hit testing can remain limited to the visible island.

`NotchOverlayMetrics` carries the current top inset, tucked size, and canvas size into SwiftUI. `NotchView` renders a clear full-canvas root and centers a separately sized island shell at the top.

`NotchWindowController` applies placement without visible frame animation for routine presentation changes. AppKit remains responsible for positioning and hit-test bounds; SwiftUI owns the visible motion. Voice input overlays should use the same `.presenting` geometry rather than inheriting sizing from any underlying reminder content.

## Safety

The design avoids copying external code. DynamicNotchKit is MIT and can inform architecture concepts such as preparing SwiftUI state before revealing the panel, but the implementation stays local to NotchMove.

CodeIsland is licensed under CC BY-NC 4.0, boring.notch-macos is CC BY-NC-ND 4.0, and Atoll/isle are GPL-3.0. Treat them as visual and interaction references only; do not copy or adapt their source into NotchMove.

The panel should be large only while an overlay is pending, visible, or dismissing, then return to the tucked size to avoid unnecessary click interception near the menu bar.

## Verification

Run:

```bash
xcodebuild -project NotchMove/NotchMove.xcodeproj -scheme NotchMove -destination 'platform=macOS' test
```

Manual checks:

- manual reminder grows from the notch instead of appearing as a resized panel
- automatic reminder enters pending before presenting
- dismissal collapses into the notch before the panel tucks
- hover preview still works
- voice input overlay still presents and dismisses
- no-notch display fallback remains centered and usable
