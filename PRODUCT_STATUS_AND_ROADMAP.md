# NotchMove Product Status And Roadmap

Date: 2026-06-01

## 1. Purpose

This document is the current product status and roadmap for NotchMove. It supersedes the older 2026-04-30 analysis where later implementation has already closed several gaps.

The goal is to keep one clear source of truth for:

- what is implemented now
- what is still missing
- what belongs in the near-term roadmap
- what should remain later enhancement work

Historical implementation plans remain in `task_plan.md`, `progress.md`, and `docs/plans/`, but completed phase plans should not be treated as the active product roadmap.

## 2. Current Product Positioning

NotchMove is a native macOS menu bar utility for low-interruption standing and movement reminders. The current product surface has been simplified back to the core reminder loop: menu bar status, activity-aware timing, notch/fallback overlay presentation, basic settings, and lightweight break statistics.

Current positioning:

- lightweight menu bar companion for long computer sessions
- notch-shaped overlay reminder experience on supported Macs, with fallback placement on other displays
- activity-aware reminders that avoid counting long idle time as active sitting
- quiet local preferences and break counters, with no account system
- retained but hidden legacy modules for daily schedule, AI schedule capture, and voice input

Do not position the current product as an AI input tool, full schedule/calendar app, full health platform, team management tool, or cloud sync product.

## 3. Current Implemented Capabilities

### 3.1 App Shape

- Native macOS app using Swift, SwiftUI, AppKit, and Observation.
- Menu bar accessory app using `LSUIElement`, with no Dock icon by default.
- Hardened Runtime is enabled.
- App Sandbox is enabled.
- `AppDelegate` wires preferences, statistics, activity monitoring, reminders, menu bar, dashboard, settings, and the notch overlay.
- Daily schedule, AI schedule capture, voice input, and global hotkey modules remain in the codebase, but they are no longer started from the default app flow.

### 3.2 Reminder Loop

Implemented in `ReminderEngine`:

- active-use accumulation based on system idle time
- manual pause/resume
- work-hours and weekday gating
- hover preview
- notch overlay presentation
- auto-dismiss
- break reminder completion
- break reminder Snooze for 10 minutes
- break reminder Skip through dismiss without counting completion
- staged hover preview motion: transparent panel canvas opens first, then the visible island expands and content reveals

Important remaining limitation:

- manual pause is still an indefinite toggle. There is no persisted `pauseUntil` and no menu options for Pause 15 min / 30 min / 1 hour / until tomorrow.

### 3.3 Retained Daily Schedule Module

Retained but hidden from the current product surface:

- `DailyScheduleItem` with title, start/end time, notes, reminder lead time, enabled state, last reminded date, and snoozed-until date.
- `DailyScheduleStore` persistence through `UserDefaults`.
- text import parser for simple daily schedule lines.
- manual add/edit/delete dashboard views and import flows.
- schedule reminder engine and shared overlay content.

Current product decision:

- Daily Schedule, Today/Schedule dashboard pages, next-schedule menu status, AI schedule capture entry points, and schedule reminder startup are hidden for the simplified reminder-first experience.

Out of scope:

- EventKit calendar sync.
- full calendar/day timeline product.
- recurring schedule profiles beyond the current local daily routine.

### 3.4 Dashboard And Settings

Implemented in `UnifiedDashboardView` and `SettingsView`; retained schedule views still exist but are not in the default navigation:

- `NavigationSplitView` primary window.
- sidebar with Workspace page: Breaks.
- sidebar with Settings pages: Reminders, Behavior, Statistics, Language, Startup, About.
- sidebar status showing tracking, paused, schedule-blocked, reminding, or idle state.
- Breaks page with today/week counts and a 7-day weekly strip.
- native Forms and property rows for settings.
- Startup settings page with launch-at-login toggle.

Remaining limitations:

- Breaks statistics show daily/week counts and a weekly strip, but there is no daily goal, goal completion rate, or productized 7-day trend/insight.
- About does not yet include Feedback / Report Issue.
- There is no first-run onboarding flow.

### 3.5 Login At Launch

Implemented:

- `LoginItemService` uses `SMAppService.mainApp`.
- `Preferences.launchAtLoginEnabled` and `hasSeenLaunchAtLoginPrompt` persist user choice.
- `SettingsView` exposes the Startup / launch-at-login toggle and handles requires-approval state.
- `AppDelegate` reconciles the desired login item state on launch after user opt-in.

This is no longer a roadmap gap. It remains subject to manual QA on a signed build and a real login session.

### 3.6 Retained AI Schedule Capture And Voice Input Modules

Retained but hidden from the current product surface:

- provider-agnostic `TranscriptionProvider` and `ScheduleParserProvider` seams.
- OpenAI and OpenAI-compatible schedule parser flow.
- cloud transcription providers and mainland provider adapters.
- local WhisperKit transcription with model management.
- Apple Speech transcription provider with Speech Recognition permission handling.
- microphone permission handling and generated privacy usage descriptions.
- Keychain-backed credentials.
- provider readiness diagnostics and redacted provider errors.
- AI schedule capture sheet with transcript, editable drafts, and user-confirmed writes into `DailyScheduleStore`.
- menu bar and dashboard AI capture entry points.
- opt-in global shortcut handling through `GlobalAICaptureHotkeyController`.
- voice input session flow with notch overlay states: recording, processing, inserted, copied, failed, undo, dismiss.
- text insertion through Accessibility when trusted, with clipboard fallback.

Current product decision:

- Menu bar Voice Input, menu bar AI Add Schedule, AI Assistant settings, dashboard AI capture sheet, and AI global hotkey registration are hidden/disabled in the default app flow.

Remaining limitations if these modules are reactivated:

- live manual QA is still pending for microphone permission, real provider credentials, cloud failure recovery, local model missing state, and release-package behavior.
- AI diagnostics exist for provider readiness, but there is no general app diagnostic export covering displays, reminder state, app version, OS version, pause state, and settings.

### 3.7 Localization

Implemented languages:

- English
- Simplified Chinese
- Traditional Chinese
- Japanese

Current resource size as of 2026-06-01:

- `en.lproj/Localizable.strings`: 353 lines
- `zh-Hans.lproj/Localizable.strings`: 353 lines
- `zh-Hant.lproj/Localizable.strings`: 353 lines
- `ja.lproj/Localizable.strings`: 353 lines

The older "about 75 lines" status is obsolete.

Remaining work:

- keep key coverage checks current as new features land
- manually inspect long labels in all four languages, especially notch overlay buttons and compact settings rows

### 3.8 Packaging And Release Documentation

Implemented:

- `script/package_dmg.sh` builds a Developer ID signed release app and DMG.
- `script/verify_release_privacy.sh` verifies signing, Hardened Runtime, privacy usage strings, entitlements, and related release metadata.
- README documents package creation, optional environment overrides, notarization with `NOTARIZE=1`, stapling, Gatekeeper assessment, DMG output path, and TCC reset commands for old builds.
- DMG background asset and packaged test DMGs exist under the project.

This is no longer a missing-script/documentation gap.

Remaining work:

- keep the release checklist's manual acceptance portion current.
- run signed manual QA before public release.

### 3.9 Testing Status

Known verified checkpoints:

- Daily schedule reminder plan passed `xcodebuild test` on 2026-04-30, but the module is now hidden from the default product surface.
- AI schedule assistant phases passed `xcodebuild test` on 2026-05-01, but the module is now hidden from the default product surface.
- AI input full-flow optimization passed macOS tests, Release build, and release privacy verification on 2026-05-15, but voice/AI entry points are now disabled in the default product surface.
- Core reminder simplification and staged hover preview tests passed `xcodebuild test` on 2026-06-01.

Current limitation:

- UI tests are still marked unavailable and do not provide useful UI coverage.
- A minimal UI smoke harness is still missing.
- Signed-build manual QA for the simplified core reminder flow remains pending.

## 4. Implemented Or Retained Items That Should Not Be Listed As Core Gaps

Do not keep these in P0 or active gap lists:

- launch at login
- break reminder Snooze and Skip
- `NavigationSplitView` dashboard with Workspace and Settings sidebar
- DMG packaging script
- signing/privacy verification script
- README packaging, signing, and notarization usage
- four-language localization growth to 353 lines per language file

These retained modules are not core release gaps while their entry points remain hidden:

- schedule reminder Done and Snooze
- shared notch overlay support for retained schedule reminders
- daily schedule visibility after import
- manual schedule item creation
- WhisperKit transcription
- Apple Speech transcription and permission handling
- AI provider readiness diagnostics
- opt-in global shortcut
- voice input notch overlay state

## 5. Current Unfinished Work

These are the real remaining items as of 2026-06-01:

1. First-run onboarding
   - Explain menu bar app behavior and no Dock icon.
   - Let users choose basic reminder interval and launch-at-login.
   - Explain privacy and permissions.
   - Provide a test reminder or test overlay action.

2. Daily goal and 7-day trend
   - Current statistics track today/week counts and expose a weekly strip.
   - Add a daily goal, goal progress, and a clearer 7-day trend view before treating statistics as complete.

3. Feedback / Report Issue
   - Add a visible entry in About or a privacy/about section.
   - A mailto or GitHub issue link is enough for the first pass.

Completed in the 2026-06-11 release-quality batch:

- Runtime temporary pause for 15 minutes, 30 minutes, 1 hour, and until tomorrow morning with auto-resume on tick.
- Privacy-safe diagnostics copy/save JSON covering app, preferences, permissions, reminder, Pomodoro, Notch Hub, AI provider selection, and screens without exporting credentials or audio.
- Manual smoke checklist at `docs/qa/notchmove-smoke-test.md`.
- Opt-in Voice Input / Typeless Lite settings page, shortcut registration, cleanup modes, personal terms, and overlay transcript preview.

7. Manual QA and release acceptance
   - Complete signed DMG install/manual release QA.
   - Complete hover preview, manual reminder, auto reminder, pause/resume, settings persistence, launch-at-login, and non-notch fallback QA on a signed build.
   - Keep the release checklist's manual acceptance section current.

## 6. Roadmap

### P0: Release Readiness

These are the highest-priority unfinished items before a broader beta or public release:

- temporary pause with persisted `pauseUntil`
- first-run onboarding
- general diagnostics export
- minimal UI smoke test
- signed-build manual QA for the simplified core reminder flow
- manual release checklist completion for DMG install, launch, hover preview, reminders, settings persistence, login item, and non-notch fallback

Acceptance:

- temporary pause survives relaunch and auto-resumes
- onboarding appears once and can be reopened from settings/help
- diagnostics output is privacy-safe and useful for support
- smoke harness catches app/dashboard/settings/reminder regressions
- release checklist clearly separates automated checks from human verification

### P1: Core Experience Enhancement

Next improvements after release readiness:

- daily goal and goal progress
- clearer 7-day trend/statistics view
- Feedback / Report Issue entry
- optional movement suggestion library
- settings information architecture polish as the feature set grows
- localization length review across English, Simplified Chinese, Traditional Chinese, and Japanese

### P2: Distribution And Retention

Later work:

- Sparkle or other auto-update path for independent distribution
- richer break history with `BreakEvent`
- streaks and custom movement library
- optional notification fallback
- optional Focus Mode or meeting-mode integration

### P3: Not Recommended For The Current Stage

Defer unless the product strategy changes:

- account system
- cloud sync
- team dashboard
- camera posture detection
- Apple Health deep integration
- complex achievement system
- full calendar sync as a dependency of the core reminder flow

## 7. Data Model Notes

Continue using `UserDefaults` for current settings and lightweight state:

- reminder interval
- sound
- idle-aware behavior
- work hours / weekday gating
- language
- display mode
- launch-at-login preference
- local statistics counters

AI provider non-secret preferences remain only as retained-module state while AI/voice entry points are hidden.

Likely near-term additions:

- `pauseUntil: Date?`
- `onboardingCompleted: Bool`
- `dailyGoal: Int`
- default quick-pause duration

Introduce a separate event store only when statistics need more than daily/week counters and the current weekly strip. Candidate future event:

```swift
struct BreakEvent: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let outcome: ReminderOutcome
    let movementID: String?
    let reminderSource: ReminderSource
    let durationSeconds: TimeInterval
    let snoozeCount: Int
}
```

## 8. Suggested Minimum Test And QA Plan

Automated:

- `xcodebuild test`
- release build
- `script/verify_release_privacy.sh`
- minimal UI smoke harness once implemented

Manual release QA:

- fresh install from DMG
- launch from Applications
- menu bar item visible
- dashboard opens
- settings open and persist changes
- manual reminder appears
- break Complete increments statistics
- break Snooze reappears later
- break Skip does not increment statistics
- launch-at-login can be enabled and reconciled after login
- hover preview expands and dismisses smoothly on notch and fallback placements
- automatic reminder overlay appears and dismisses correctly
- four localizations do not visibly break compact UI

## 9. Immediate Next Actions

1. Add first-run onboarding.
2. Complete signed-build manual core QA using `docs/qa/notchmove-smoke-test.md`.
3. Add daily goal and 7-day trend.
4. Add Feedback / Report Issue.
5. Update release checklist with manual acceptance evidence.
6. Run localization length review after the next UI changes.
7. Keep completed phase plans archived so they are not mistaken for active gaps.

## 10. Conclusion

NotchMove now has a substantially larger implementation than the original 2026-04-30 roadmap described. Launch at login, Snooze/Skip, retained schedule reminders, retained AI schedule capture, retained local/system transcription, retained global shortcuts, retained voice input, packaging scripts, signing checks, privacy verification, notarization instructions, and the split dashboard have all been built at some point.

The current roadmap should focus on the simplified core product gaps: temporary pause, onboarding, general diagnostics, smoke testing, daily goal/trends, feedback entry, and signed-build manual QA for the reminder, hover, settings, login item, and fallback-display paths.
