# Notch Overlay Motion Redesign

Date: 2026-05-28

Updated: 2026-06-06

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

Hover preview uses the same separation with an additional fit gate:

1. Hover enter moves to `.hoverPreviewPending`.
2. Pending mounts the hover preview content invisibly so SwiftUI can measure the target content.
3. Pending may preheat the transparent panel canvas, but the visible shell and hit-test `visibleSize` stay tucked.
4. Once the current content fit is available, the controller freezes the target hover canvas size for this hover cycle.
5. The engine promotes to `.hoverPreview` only after both the frozen size is ready and the 70 ms preheat delay has elapsed. A 180 ms maximum preheat fallback freezes the current baseline size so hover never gets stuck.
6. During `.hoverPreview`, AppKit keeps applying panel frames without visible animation; the SwiftUI shell expands to the frozen target size.
7. Hover content reveals about 120 ms after shell expansion starts using top reveal, opacity, scale, and blur.
8. On hover exit, `.hoverPreviewDismissing` hides content immediately, holds the expanded shell for about 90 ms, then collapses the shell back to the tucked size. The engine settles to `.hidden` after about 240 ms, allowing the panel frame to return to tucked.

The intended hover behavior is therefore fit-preheat, frozen target, shell expansion, delayed content reveal, content removal, shell collapse, then hidden panel tuck.

## Architecture

`ReminderEngine` owns presentation phases and schedules the short promotion from `.reminderPending` to `.presenting`. It cancels that promotion when a reminder is cancelled, completed, snoozed, or dismissed.

`ScreenPlacementService` remains the geometry authority. It keeps hidden tucked, lets pending/dismissing phases use expanded canvas geometry when needed, and separately reports `visibleSize` so hit testing can remain limited to the visible island.

`NotchOverlayMetrics` carries the current top inset, tucked size, canvas size, live content fit request, cached content fit request, and the frozen hover preview size into SwiftUI/AppKit coordination. Live fit requests may keep updating the cache, but a visible hover cycle uses the frozen size so content measurement cannot resize the shell mid-expansion.

`NotchWindowController` applies placement without visible frame animation for routine presentation changes. AppKit remains responsible for positioning and hit-test bounds; SwiftUI owns the visible motion. Voice input overlays should use the same `.presenting` geometry rather than inheriting sizing from any underlying reminder content.

`NotchView` keeps hover content mounted through pending, active, and dismissing phases, but gates visibility with explicit reveal and shell-hold state. This keeps measurement available during preheat while preventing content flash or click interception before the visible shell is ready.

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
- hover preview waits for fit readiness, expands to a frozen size, and reveals content after the shell starts moving
- hover preview dismissal hides content before the shell collapses
- voice input overlay still presents and dismisses
- no-notch display fallback remains centered and usable
