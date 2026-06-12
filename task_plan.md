# Daily Schedule Reminder Execution Plan

Status: archived / completed

Completion date: 2026-04-30

Current note as of 2026-05-22: this is a completed专项 execution plan for the daily schedule reminder loop, not the current overall product plan. Use `PRODUCT_STATUS_AND_ROADMAP.md` for the active roadmap and `progress.md` for chronological implementation history.

## Goal

Turn the current daily schedule feature from an import-only surface into a usable reminder loop:

- imported items remain visible and scannable after import
- the menu bar exposes today's next schedule item
- due schedule items trigger through the existing NotchMove reminder surface
- schedule reminders can be completed or snoozed without breaking the existing sedentary reminder flow

## Relevant Research

- `nilBora/meeting-reminder`: best fit for reminder scheduling. Key ideas to copy conceptually: a timer checks upcoming events, tracks shown IDs, supports snooze/dismiss, and presents an unmistakable overlay.
- `leits/MeetingBar`: useful for menu bar "next event" status, local notification categories, and snooze actions.
- `pakerwreah/Calendr` and `sfsam/Itsycal`: useful for agenda display and EventKit refresh patterns.
- `DamascenoRafael/reminders-menubar`: useful for Reminders CRUD and upcoming reminder filtering, but GPL-3.0 means avoid copying code.

## Original Findings Before Implementation

These findings describe the starting point on 2026-04-30. They are retained as historical context for this archived plan and are not current product gaps.

- `DailyScheduleStore` already persists `DailyScheduleItem` values in `UserDefaults`.
- `DailyScheduleImportParser` supports text lines like `09:00-10:00 Meeting`.
- `DailyScheduleDashboardView` already has an import sheet and today list.
- At the time, `DailyScheduleReminderEngine` fired on a 30-second loop but presented an `NSAlert`; this was resolved by routing schedule reminders through the notch overlay.
- At the time, `NotchView` was tied to `ReminderEngine` and only knew about sedentary break reminders; this was resolved by the completed shared overlay work in Phase 2.
- At the time, `MenuBarController` had a dashboard entry but no schedule preview/status; this was resolved by the completed visibility/menu affordance work in Phase 4.

## Implementation Phases

### Phase 1: Document and stabilize scope

Status: complete

- Create `task_plan.md`, `findings.md`, and `progress.md`.
- Keep first implementation focused on local imported schedules, not EventKit import.

### Phase 2: Shared notch overlay content

Status: complete

- Extend `ReminderEngine` overlay state with a content payload for break vs schedule reminder.
- Add intents for schedule reminder presentation, completion, snooze, and dismissal.
- Update `NotchView` to render schedule title/time and schedule actions when the payload is schedule-based.

### Phase 3: Daily schedule engine behavior

Status: complete

- Replace `NSAlert` presenter with a notch presenter that triggers `ReminderEngine`.
- Track fired state only when a reminder is completed or skipped, not just when it appears.
- Support snooze by writing a future `snoozedUntilDate` into `DailyScheduleItem`.
- Avoid repeated firing for the same item while a reminder is active.

### Phase 4: Visibility and menu affordance

Status: complete

- Add a menu bar line for next schedule item and countdown.
- Keep dashboard selection stable after import.
- Show reminder status in the dashboard row/detail.
- Add a manual "Add schedule item" sheet so import is not the only creation path.

### Phase 5: Tests and verification

Status: complete

- Update unit tests for lead-time firing, repeat suppression, completion, and snooze.
- Run `xcodebuild -project NotchMove/NotchMove.xcodeproj -scheme NotchMove -destination 'platform=macOS' test` from `NotchMove_codex_V1`.

## Out of Scope For First Pass

- EventKit calendar import/sync.
- Local notification scheduling while the app is not running.
- Full calendar/day timeline UI.
- System Reminders integration.

## Errors Encountered

| Error | Attempt | Resolution |
| --- | --- | --- |
| `NotchView` switch branches had mismatching `some View` types | First `xcodebuild test` | Added `@ViewBuilder` to `reminderContent`. |
| `ReminderEngine` still called the old `beginReminderPresentation(playSound:)` signature | First `xcodebuild test` | Replaced stale call with `beginBreakReminderPresentation(playSound:)`. |

## Verification

- `xcodebuild -project NotchMove/NotchMove.xcodeproj -scheme NotchMove -destination 'platform=macOS' test` passed on 2026-04-30.
