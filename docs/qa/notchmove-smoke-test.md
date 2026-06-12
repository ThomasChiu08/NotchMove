# NotchMove Smoke Test

Last updated: 2026-06-11

Run this checklist on a signed local build before release.

## Menu Bar

- Open the status item and confirm next reminder, break count, pause, Notch Hub, Pomodoro, sound, dashboard, and quit rows render without truncation.
- Use Pause 15 minutes, Pause 30 minutes, Pause 1 hour, and Pause until tomorrow; confirm the row changes to Resume and reminders stop.
- Use Resume and confirm the next reminder preview schedules again.
- Start, pause/resume, and stop Pomodoro from the menu.

## Settings

- Open Dashboard, visit Reminders, Notch Hub, Voice Input, Behavior, Statistics, Language, Startup, and About.
- Confirm Voice Input is off by default, the shortcut row appears only after enabling it, and cleanup modes switch between Raw, Clean, and Polished.
- Confirm About > Diagnostics can copy JSON and save a `.json` file without exposing API keys or audio.
- Restore defaults and confirm Voice Input returns to off.

## Overlay

- Trigger Remind me now and confirm the reminder stages from tucked to presenting.
- Use Later, Skip, and movement completion controls.
- Hover the notch while idle and confirm preview entry/exit remains staged and does not resize the hit target unexpectedly.
- Enable Notch Hub and confirm active reminders stay ahead of Hub surfaces.

## Voice Input Manual QA

- Enable Voice Input, choose a shortcut, and confirm shortcut registration status becomes registered.
- With Microphone, Speech Recognition, and Accessibility unavailable, confirm permission rows show the correct recovery actions.
- Dictate into Notes or a browser text field with Accessibility allowed; confirm text inserts and Undo is available.
- Disable Accessibility and dictate again; confirm text is copied or pasted through fallback without losing the previous clipboard when possible.
- Test Raw, Clean, and Polished modes. Polished should only use the configured AI provider after AI polishing is enabled.
