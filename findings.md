# Daily Schedule Reminder Findings

## Online Reference Projects

- `nilBora/meeting-reminder` is the closest product reference. It uses EventKit, a 30-second monitor loop, shown-event tracking, snooze state, sound, and a strong overlay.
- `leits/MeetingBar` is the mature menu bar calendar reference. It exposes the next meeting in the status bar/menu and schedules local notifications with actions.
- `pakerwreah/Calendr` and `sfsam/Itsycal` are better references for compact agenda display than for NotchMove's health-reminder overlay.
- `DamascenoRafael/reminders-menubar` demonstrates robust Apple Reminders menu bar management, but GPL-3.0 makes direct code reuse inappropriate.

## Local Codebase Findings

- Current storage is in `NotchMove/NotchMove/Core/Services/DailyScheduleStore.swift`.
- Current import parsing is in `NotchMove/NotchMove/Core/Services/DailyScheduleImportParser.swift`.
- Current schedule dashboard UI is in `NotchMove/NotchMove/Features/Dashboard/DailyScheduleDashboardView.swift`.
- Current schedule reminders are in `NotchMove/NotchMove/Core/Services/DailyScheduleReminderEngine.swift` and use `NSAlert`.
- Current notch overlay is driven by `ReminderEngine.OverlayState` and rendered by `NotchView`.
- `AppDelegate` already creates both `ReminderEngine` and `DailyScheduleReminderEngine`, so the integration point is straightforward.

## Product Decision

First pass should not add EventKit. The local import path already exists and directly addresses the user's current pain. EventKit can be added later as an additional source once the reminder loop is stable.
