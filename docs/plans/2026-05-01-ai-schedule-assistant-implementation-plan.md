# NotchMove AI Schedule Assistant Implementation Plan

Date: 2026-05-01

## Goal

Original goal: turn the then-existing AI schedule assistant skeleton into a reliable, privacy-aware product feature. As of 2026-05-22, this implementation plan is complete through automated QA, and the remaining work is live manual QA.

The first shipped experience should let users speak a schedule command, review parsed drafts, edit mistakes, and add confirmed items to NotchMove's existing daily schedule reminder loop.

## Recommendation

Use a staged plan:

1. Harden the current cloud batch capture flow.
2. Add local WhisperKit transcription as a privacy-first transcription provider.
3. Defer global push-to-talk until permission handling is solid.

2026-05-22 note: this sequencing has since completed. The current app has opt-in global shortcut handling through Carbon and keeps menu bar/dashboard capture working without extra Accessibility/Input Monitoring permissions.

Do not build a general chatbot. Keep AI scoped to structured schedule capture.

## Non-Goals

- No automatic reminder creation without review.
- No general chat window.
- No transcription history or analytics in the first pass.
- No EventKit calendar sync as part of this AI feature.
- No global key monitoring before explicit user opt-in.

## Phase 1: Harden Current Cloud Capture

Status: complete

Purpose: make the existing batch upload flow dependable enough to use daily.

Scope:

- Keep `AIScheduleAssistantService` as the orchestrator.
- Keep `TranscriptionProvider` and `ScheduleParserProvider` as the provider seams.
- Keep confirmed drafts flowing into `DailyScheduleStore`.
- Improve provider readiness checks before recording starts.
- Add clearer localized errors for disabled AI, missing credentials, microphone denial, empty transcript, provider failure, invalid parser JSON, and past-date drafts.
- Improve review sheet ergonomics:
  - show provider and privacy status
  - show transcript
  - keep all drafts selected by default
  - require non-empty titles
  - preserve warning text per draft
  - keep edit controls compact enough for multiple drafts
- Decide future-date behavior:
  - either allow future items and add a future schedule view later
  - or in version 1 warn when a parsed item is not today

Acceptance criteria:

- A user can enable AI, save credentials, record a short schedule command, review drafts, and add selected items.
- Failed provider calls leave no temporary audio file behind.
- Empty transcripts do not call the parser.
- Parser output remains schema validated.
- `xcodebuild test` passes.

Completion notes:

- Added pre-recording capture readiness validation for enabled state, required credentials, parser provider setup, and custom OpenAI-compatible Base URL shape.
- Added localized capture errors for disabled AI, missing credentials, microphone denial, empty transcripts, provider failures, invalid parser JSON, and Keychain failures.
- Added provider and privacy status to the capture/review sheet.
- Kept drafts selected by default, tightened selected-draft title validation, and made draft editing controls more compact.
- Chose the version 1 future-date policy: future/non-today drafts are allowed but receive a warning because current dashboard views are today-centric.
- Added focused tests for parser failure cleanup, empty transcript cleanup, invalid parser JSON, invalid custom Base URL readiness, past-date warnings, and non-today warnings.
- Verified with `xcodebuild -project NotchMove/NotchMove.xcodeproj -scheme NotchMove -destination 'platform=macOS' test` on 2026-05-01.

Primary files:

- `Core/Services/AI/AIScheduleAssistantService.swift`
- `Core/Services/AI/AIProviderPreferences.swift`
- `Core/Services/AI/AIProviderFactory.swift`
- `Core/Services/AI/ScheduleParserPrompt.swift`
- `Features/Dashboard/AIScheduleCaptureSheet.swift`
- `Features/Settings/SettingsView.swift`
- `Resources/*/Localizable.strings`
- `NotchMoveTests/AIScheduleAssistantTests.swift`

## Phase 2: Add Local WhisperKit Transcription

Status: complete

Purpose: give privacy-sensitive users a path where audio stays on the Mac.

Architecture:

```text
WhisperKitTranscriptionProvider: TranscriptionProvider
  -> LocalSpeechModelStore
  -> model download/verify/delete
  -> transcribe local audio file
  -> Transcript
```

Scope:

- Add WhisperKit through Swift Package Manager when implementation begins.
- Add a new provider ID such as `localWhisperKit`.
- Add a model catalog with a small set of practical choices:
  - tiny: fastest debug path
  - base: default daily-use path
  - small: better accuracy
- Add model readiness states:
  - not downloaded
  - downloading
  - verifying
  - ready
  - failed
- Add settings controls:
  - choose local transcription provider
  - choose model
  - download/verify/delete model
  - show approximate disk usage
- Ensure capture does not trigger surprise model downloads.
- Keep parser provider separate. Local transcription does not automatically mean local parsing.

Acceptance criteria:

- If the local model is ready, AI capture can transcribe without sending audio to cloud STT.
- If the model is missing, capture explains exactly what to do.
- Cloud parser privacy copy remains visible when parser is still cloud-based.
- Unit tests cover provider selection, missing model behavior, and local provider factory wiring.

Completion notes:

- Added WhisperKit through Swift Package Manager using `argmaxinc/argmax-oss-swift` and linked the `WhisperKit` product to the app target.
- Added `LocalSpeechModelStore` with tiny/base/small model choices, persisted readiness, download, verify, delete, and missing-model error handling.
- Added `WhisperKitTranscriptionProvider` as a `TranscriptionProvider` implementation that transcribes existing capture audio files without triggering surprise downloads.
- Added the `Local WhisperKit` transcription provider, kept parser selection separate, and defaulted the local model to `base`.
- Added Settings controls for local model status, download, verify, delete, and approximate disk usage.
- Updated capture privacy copy so local STT is distinguished from the selected parser provider.
- Added localized model-management, privacy, and missing-model strings for English, Simplified Chinese, Traditional Chinese, and Japanese.
- Added tests for local provider selection, missing-model behavior, ready-model factory wiring, and persisted model readiness.
- Verified with `xcodebuild -project NotchMove/NotchMove.xcodeproj -scheme NotchMove -destination 'platform=macOS' test` on 2026-05-01.

Primary files to add or modify:

- `Core/Services/AI/WhisperKitTranscriptionProvider.swift`
- `Core/Services/AI/LocalSpeechModelStore.swift`
- `Core/Services/AI/AIProviderPreferences.swift`
- `Core/Services/AI/AIProviderFactory.swift`
- `Features/Settings/SettingsView.swift`
- `NotchMoveTests/AIScheduleAssistantTests.swift`

## Phase 3: Provider Validation and Setup Polish

Status: complete

Purpose: make setup less fragile before broad provider expansion.

Scope:

- Replace "test transcription provider" factory-only success with a real readiness result:
  - credential present
  - endpoint shape valid
  - optional network smoke test when safe
  - model local readiness for local providers
- Keep secrets redacted in all provider error messages.
- Add a single setup guide sheet per selected provider.
- Add a "current flow status" row:
  - transcription ready/not ready
  - parser ready/not ready
  - missing credential or model reason

Acceptance criteria:

- Users can tell what is blocking AI capture without attempting a recording.
- Provider errors do not expose API keys, secret keys, or tokens.
- Settings changes continue to persist through `UserDefaults` for non-secrets and Keychain for credentials.

Completion notes:

- Added structured capture readiness results for transcription and parser setup, including credentials, local model readiness, model names, and OpenAI-compatible endpoint shape.
- Changed the Settings transcriber test from factory-only construction to readiness validation; parser testing still performs its safe text-only smoke request after local readiness passes.
- Added a Settings flow status row showing transcription/parser ready state and the current blocking reason before recording.
- Moved provider guide access to the selected transcription/parser provider rows so providers without credentials, such as Local WhisperKit, still have setup help.
- Added multi-secret redaction for provider errors and covered direct provider error paths that bypass generic HTTP handling.
- Added unit tests for readiness diagnostics, custom endpoint shape validation, local-model readiness, and multi-secret redaction.
- Verified with `xcodebuild -project NotchMove/NotchMove.xcodeproj -scheme NotchMove -destination 'platform=macOS' test` on 2026-05-01.

## Phase 4: Global Push-To-Talk

Status: complete

Purpose: make AI capture fast without prematurely increasing permission surface.

Scope:

- Add optional global hotkey setting.
- Start with toggle mode:
  - press once to open/start capture
  - press again or click stop to process
- Add push-to-talk only if the chosen hotkey approach can reliably observe key-up.
- Add explicit onboarding for any required macOS permission.
- Do not request Accessibility/Input Monitoring until the user enables this feature.

Acceptance criteria:

- Menu bar and dashboard capture still work with no extra permissions.
- Global shortcut is opt-in.
- The app clearly explains why a permission is needed.
- Shortcut registration failure has a recoverable UI state.

Likely reference pattern:

- Pindrop's hotkey modes.
- AudioWhisper's permission split.

Completion notes:

- Added opt-in global shortcut settings with selectable presets and persisted `UserDefaults` state.
- Registered shortcuts through Carbon `RegisterEventHotKey`, avoiding Accessibility/Input Monitoring for the toggle-mode flow.
- Added recoverable shortcut status UI with retry, conflict/failure messaging, and permission onboarding copy.
- Routed global shortcut presses into the dashboard AI capture sheet: first press opens/starts recording, second press stops and processes.
- Kept menu bar and dashboard capture paths independent of the shortcut setting.
- Added regression tests for default opt-in behavior, shortcut persistence, and dedicated hotkey preference notifications.
- Verified with `xcodebuild -project NotchMove/NotchMove.xcodeproj -scheme NotchMove -destination 'platform=macOS' test` on 2026-05-01.

## Phase 5: QA and Release Readiness

Status: complete for automated QA; live manual QA pending

Current status as of 2026-05-22: this remains accurate. Later work in `docs/plans/2026-05-01-ai-input-full-flow-optimization-plan.md` was implemented and verified on 2026-05-15, adding Apple Speech permission handling, a clearer AI Settings flow, full voice input, notch overlay voice states, Release build verification, and release privacy verification. That later plan extends this one, but it does not close the live microphone/provider/manual release QA items below.

Scope:

- Add parser fixture tests for English, Simplified Chinese, Traditional Chinese, and Japanese.
- Add tests for:
  - missing credentials
  - invalid custom base URL
  - invalid parser JSON
  - past-date warning
  - future-date warning or acceptance
  - draft-to-schedule conversion
  - temporary audio cleanup on success and failure
- Run:

```bash
xcodebuild -project NotchMove.xcodeproj -scheme NotchMove -destination 'platform=macOS' test
```

- Manual QA:
  - first-run AI disabled state
  - microphone permission denied
  - provider credential missing
  - record short Chinese command
  - record short English command
  - add one selected draft
  - cancel review sheet
  - cloud parser failure
  - local model missing

Completion notes:

- Added parser fixture tests for English, Simplified Chinese, Traditional Chinese, and Japanese provider outputs.
- Confirmed existing regression tests cover missing credentials, invalid custom Base URL, invalid parser JSON, past-date warning, future/non-today warning, draft-to-schedule conversion, and temporary audio cleanup on success and failure.
- Verified with `xcodebuild -project NotchMove/NotchMove.xcodeproj -scheme NotchMove -destination 'platform=macOS' test` on 2026-05-01.
- Live manual QA still needs a local signed run with microphone permission and real provider credentials for recording and cloud failure scenarios.

## Risks

- Provider model names and API behavior change over time. Keep provider definitions easy to update and avoid hard-coding too much UI copy around one model.
- Local STT adds package size, model management, disk-space UI, and memory pressure concerns. Keep it phase 2.
- Global hotkeys can create trust friction on macOS. Keep them opt-in and avoid asking for permissions until the user chooses the feature.
- Future-dated schedule items are already storable, but the current dashboard is today-centric. Decide the UI policy before relying on future reminders heavily.

## Implementation Order

1. Finish Phase 1 and ship a reliable cloud MVP.
2. Add provider readiness polish from Phase 3 where it reduces support burden.
3. Add Phase 2 local WhisperKit STT.
4. Add Phase 4 global shortcut.
5. Expand to richer schedule views only after the capture loop is stable.

## Definition of Done

The AI schedule assistant is done for the first release when:

- AI capture has clear entry points in menu bar and dashboard.
- Users can configure providers without guessing what is missing.
- AI output is always reviewed before saving.
- Confirmed drafts become normal `DailyScheduleItem` values.
- Existing schedule reminders handle saved AI items.
- Tests pass and privacy copy accurately reflects selected providers.
