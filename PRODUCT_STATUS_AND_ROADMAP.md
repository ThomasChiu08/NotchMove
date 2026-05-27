# NotchMove Product Status And Roadmap

Date: 2026-05-22

## 1. Purpose

This document is the current product status and roadmap for NotchMove. It supersedes the older 2026-04-30 analysis where later implementation has already closed several gaps.

The goal is to keep one clear source of truth for:

- what is implemented now
- what is still missing
- what belongs in the near-term roadmap
- what should remain later enhancement work

Historical implementation plans remain in `task_plan.md`, `progress.md`, and `docs/plans/`, but completed phase plans should not be treated as the active product roadmap.

## 2. Current Product Positioning

NotchMove is a native macOS menu bar health and input utility. Its core product still starts from low-interruption standing and movement reminders, but the current app also includes a local-first daily schedule reminder loop and AI-assisted voice capture/input features.

Current positioning:

- lightweight menu bar companion for long computer sessions
- notch-shaped overlay reminder experience on supported Macs, with fallback placement on other displays
- local daily schedule reminders with user-confirmed actions
- BYOK AI schedule capture and voice input, with local and system transcription options where available
- privacy-forward macOS utility with explicit permissions and no account system

Do not position the current product as a full health platform, team management tool, complete calendar app, or cloud sync product.

## 3. Current Implemented Capabilities

### 3.1 App Shape

- Native macOS app using Swift, SwiftUI, AppKit, and Observation.
- Menu bar accessory app using `LSUIElement`, with no Dock icon by default.
- Hardened Runtime is enabled.
- App Sandbox is enabled.
- `AppDelegate` wires preferences, statistics, activity monitoring, reminders, menu bar, dashboard, settings, global hotkey handling, voice input, and the notch overlay.

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
- schedule reminder presentation through the same notch overlay
- schedule reminder Done and Snooze actions

Important remaining limitation:

- manual pause is still an indefinite toggle. There is no persisted `pauseUntil` and no menu options for Pause 15 min / 30 min / 1 hour / until tomorrow.

### 3.3 Daily Schedule

Implemented:

- `DailyScheduleItem` with title, start/end time, notes, reminder lead time, enabled state, last reminded date, and snoozed-until date.
- `DailyScheduleStore` persistence through `UserDefaults`.
- text import parser for simple daily schedule lines.
- manual add/edit/delete flows in the dashboard.
- schedule reminder engine that routes due items into the notch overlay.
- next schedule status in menu/dashboard surfaces.
- Today and Schedule views that keep imported and manually added items visible and editable.

Out of scope / still not implemented:

- EventKit calendar sync.
- full calendar/day timeline product.
- recurring schedule profiles beyond the current local daily routine.

### 3.4 Dashboard And Settings

Implemented in `UnifiedDashboardView`, `DailyScheduleDashboardView`, and `SettingsView`:

- `NavigationSplitView` primary window.
- sidebar with Workspace pages: Today, Schedule, Breaks.
- sidebar with Settings pages: Reminders, AI Assistant, Behavior, Statistics, Language, Startup, About.
- sidebar status showing tracking, paused, schedule-blocked, reminding, or idle state.
- Today page with tracking status, next stand reminder, current schedule, next schedule, breaks today, and schedule timeline.
- Schedule page with row actions, add/edit/delete/import, reminder toggles, and selected item properties.
- Breaks page with today/week counts and a 7-day weekly strip.
- native Forms and property rows for settings.
- Startup settings page with launch-at-login toggle.
- AI Assistant settings split into overview/input/parser/credentials/diagnostics style sections.

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

### 3.6 AI Schedule Capture And Voice Input

Implemented:

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

Remaining limitations:

- live manual QA is still pending for microphone permission, real provider credentials, cloud failure recovery, local model missing state, and release-package behavior.
- AI diagnostics exist for provider readiness, but there is no general app diagnostic export covering displays, reminder state, app version, OS version, pause state, and settings.

### 3.7 Localization

Implemented languages:

- English
- Simplified Chinese
- Traditional Chinese
- Japanese

Current resource size as of 2026-05-22:

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

- Daily schedule reminder plan passed `xcodebuild test` on 2026-04-30.
- AI schedule assistant phases passed `xcodebuild test` on 2026-05-01.
- AI input full-flow optimization passed macOS tests, Release build, and release privacy verification on 2026-05-15.

Current limitation:

- UI tests are still marked unavailable and do not provide useful UI coverage.
- A minimal UI smoke harness is still missing.
- Live microphone/provider/manual release QA remains pending.

## 4. Completed Items That Should Not Be Listed As Gaps

Do not keep these in P0 or active gap lists:

- launch at login
- break reminder Snooze and Skip
- schedule reminder Done and Snooze
- shared notch overlay for break and schedule reminders
- daily schedule visibility after import
- manual schedule item creation
- `NavigationSplitView` dashboard with Workspace and Settings sidebar
- WhisperKit transcription
- Apple Speech transcription and permission handling
- AI provider readiness diagnostics
- opt-in global shortcut
- voice input notch overlay state
- DMG packaging script
- signing/privacy verification script
- README packaging, signing, and notarization usage
- four-language localization growth to 353 lines per language file

## 5. Current Unfinished Work

These are the real remaining items as of 2026-05-22:

1. Temporary pause
   - Add persisted `pauseUntil`.
   - Add Pause for 15 min / 30 min / 1 hour / until tomorrow.
   - Show remaining pause time and auto-resume on expiry.

2. First-run onboarding
   - Explain menu bar app behavior and no Dock icon.
   - Let users choose basic reminder interval and launch-at-login.
   - Explain privacy and permissions.
   - Provide a test reminder or test overlay action.

3. General diagnostics export
   - Existing AI readiness diagnostics are not enough.
   - Add a privacy-safe "Copy diagnostics" output for version/build, macOS version, sandbox/signing clues, screen list, selected display mode, reminder state, pause state, schedule state, AI provider readiness summary, and relevant preferences.

4. Minimal UI smoke test
   - Current UI tests are intentionally unavailable.
   - Add a small harness that can launch the app, open the menu/dashboard/settings, trigger a reminder, and validate the expected surfaces exist.

5. Daily goal and 7-day trend
   - Current statistics track today/week counts and expose a weekly strip.
   - Add a daily goal, goal progress, and a clearer 7-day trend view before treating statistics as complete.

6. Feedback / Report Issue
   - Add a visible entry in About or a privacy/about section.
   - A mailto or GitHub issue link is enough for the first pass.

7. Manual QA and release acceptance
   - Complete microphone permission QA.
   - Complete real provider credential QA.
   - Complete cloud provider failure QA.
   - Complete local WhisperKit missing/ready model QA.
   - Complete signed DMG install/manual release QA.
   - Keep the release checklist's manual acceptance section current.

## 6. Roadmap

### P0: Release Readiness

These are the highest-priority unfinished items before a broader beta or public release:

- temporary pause with persisted `pauseUntil`
- first-run onboarding
- general diagnostics export
- minimal UI smoke test
- signed-build manual QA for microphone/provider/voice input paths
- manual release checklist completion for DMG install, launch, permissions, login item, and basic reminders

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
- AI provider non-secret preferences
- local statistics counters

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
- schedule reminder Done/Snooze works
- launch-at-login can be enabled and reconciled after login
- microphone permission prompt and denial recovery work
- Apple Speech permission prompt and denial recovery work
- local WhisperKit missing-model message is understandable
- provider credential missing/wrong key/cloud failure flows are understandable
- four localizations do not visibly break compact UI

## 9. Immediate Next Actions

1. Implement temporary pause and persisted `pauseUntil`.
2. Add first-run onboarding.
3. Add general diagnostics export.
4. Build the minimal UI smoke harness.
5. Complete microphone/provider/manual release QA.
6. Add daily goal and 7-day trend.
7. Add Feedback / Report Issue.
8. Update release checklist with manual acceptance evidence.
9. Run localization length review after the next UI changes.
10. Keep completed phase plans archived so they are not mistaken for active gaps.

## 10. Conclusion

NotchMove now has a substantially larger implementation than the original 2026-04-30 roadmap described. Launch at login, Snooze/Skip, schedule reminders, AI schedule capture, local/system transcription, global shortcuts, voice input, packaging scripts, signing checks, privacy verification, notarization instructions, and the split dashboard are implemented.

The current roadmap should focus on the remaining operational gaps: temporary pause, onboarding, general diagnostics, smoke testing, daily goal/trends, feedback entry, and live manual QA for microphone/provider/release paths.
