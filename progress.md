# Daily Schedule Reminder Progress

## 2026-04-30

- Researched open-source references for macOS schedule and meeting reminders.
- Confirmed NotchMove already has local daily schedule models, import parsing, dashboard UI, and a polling reminder engine.
- Started execution plan focused on imported schedule visibility and notch-based reminders.
- Added project planning files.
- Added schedule reminder snooze state to `DailyScheduleItem` and `DailyScheduleStore`.
- Routed daily schedule reminders through the notch overlay via `DailyScheduleNotchPresenter`.
- Added schedule-specific notch UI with Done and Later actions.
- Added manual schedule item creation from the dashboard.
- Added menu bar next-schedule status and dashboard reminder status labels.
- Updated daily schedule tests for completion, snooze, and stale reminder windows.
- Ran `xcodebuild -project NotchMove/NotchMove.xcodeproj -scheme NotchMove -destination 'platform=macOS' test`; result: passed.
- Began AI voice schedule assistant Phase 1 from `docs/plans/2026-04-30-ai-voice-schedule-design.md`.
- Added provider-agnostic AI schedule models, transcription/parser protocols, Keychain-backed OpenAI API key storage, temporary audio recording, OpenAI transcription, and OpenAI Responses structured-output parsing.
- Added AI Assistant settings, menu bar `AI Add Schedule...`, Today/Schedule `Speak` actions, and a review sheet that lets users edit/select drafts before writing to `DailyScheduleStore`.
- Added sandbox microphone and outgoing network entitlements plus `NSMicrophoneUsageDescription`.
- Added AI assistant unit tests for draft conversion, schema decoding, service order, temporary audio cleanup, empty transcript handling, past-date warnings, response extraction, and API key redaction.
- Re-ran `xcodebuild -project NotchMove/NotchMove.xcodeproj -scheme NotchMove -destination 'platform=macOS' test`; result: passed.

## 2026-05-01

- Analyzed the existing AI assistant implementation and confirmed the current path is already provider-agnostic and draft-confirmed.
- Researched GitHub references: Pindrop, AudioWhisper, AssisChat, and argmaxinc/argmax-oss-swift.
- Ran `xcodebuild -project NotchMove.xcodeproj -scheme NotchMove -destination 'platform=macOS' test` from `NotchMove/`; result: passed.
- Saved AI research notes to `docs/plans/2026-05-01-ai-schedule-assistant-research.md`.
- Saved staged implementation plan to `docs/plans/2026-05-01-ai-schedule-assistant-implementation-plan.md`.
- Completed AI schedule assistant implementation Phase 1: pre-recording readiness validation, localized capture errors, provider/privacy status in review, stricter selected-draft title validation, non-today warnings, and additional AI assistant regression tests.
- Ran `xcodebuild -project NotchMove/NotchMove.xcodeproj -scheme NotchMove -destination 'platform=macOS' test`; result: passed.
