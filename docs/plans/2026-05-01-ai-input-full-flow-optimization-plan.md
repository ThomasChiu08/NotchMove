# NotchMove AI Input Full-Flow Optimization Plan

## Summary

Implement a complete AI input flow that fits macOS: Apple Speech/system permission support, a clearer native Settings experience, reliable readiness diagnostics, and the existing draft-review boundary before writing schedule items.

Status: implemented and verified on 2026-05-15.

2026-05-22 consistency check: this status still matches `progress.md`, README release/privacy documentation, and the current implementation files for Apple Speech, WhisperKit, provider readiness diagnostics, voice input, notch overlay voice states, and release privacy verification. Remaining work is manual QA, not implementation of this plan.

Original baseline before this plan:

- The app already has microphone entitlement and usage copy, Keychain-backed credentials, WhisperKit, cloud transcription/parser providers, the AI capture sheet, and AI assistant tests.
- At the time, the missing pieces were Apple Speech as a transcription provider, `NSSpeechRecognitionUsageDescription`, explicit Speech Recognition permission handling, actionable system settings recovery, and a less crowded AI settings layout. Those items were implemented by this plan.

## Key Changes

- Add Apple Speech as a transcription provider behind the existing `TranscriptionProvider` protocol.
- Keep Apple Speech scoped to transcription; schedule extraction still uses the selected parser provider.
- Add Speech Recognition authorization checks, request flow, localized errors, and macOS Settings recovery buttons.
- Add `NSSpeechRecognitionUsageDescription` to generated Info.plist build settings.
- Split AI Settings into overview, input, parser, credentials, and diagnostics sections.
- Show microphone and Speech Recognition permission state in Settings.
- Keep privacy copy accurate for cloud, Apple Speech, and local WhisperKit flows.
- Keep AI output as editable drafts; confirmed drafts are still the only path into `DailyScheduleStore`.

## Completion Notes

- Added Apple Speech provider selection with automatic, English, Simplified Chinese, Traditional Chinese, and Japanese locale choices.
- Added Speech Recognition permission state, request, denial recovery, and generated Info.plist privacy metadata.
- Kept provider readiness diagnostics split between transcription and parser setup.
- Added text insertion access recovery for the hold-to-dictate voice input flow; when Accessibility is unavailable, cleaned dictation falls back to the clipboard.
- Routed menu bar and global shortcut voice input through the notch overlay with recording, processing, inserted, copied, failed, undo, and dismiss states.
- Updated localized Settings/menu/overlay strings in English, Simplified Chinese, Traditional Chinese, and Japanese.

## Test Plan

- Unit tests for provider registry, Apple Speech provider construction, no-credential behavior, and model defaults.
- Existing AI assistant tests for parser fixtures, provider factory wiring, readiness diagnostics, secret redaction, and temporary audio cleanup.
- Manual checks for Settings layout, Apple Speech permission request, microphone denial recovery, local model missing state, and AI capture draft review.

Verification:

- `xcodebuild -project NotchMove/NotchMove.xcodeproj -scheme NotchMove -destination 'platform=macOS' -derivedDataPath /private/tmp/NotchMove-DerivedData test` passed on 2026-05-15.
- `xcodebuild -project NotchMove/NotchMove.xcodeproj -scheme NotchMove -configuration Release -destination 'platform=macOS' -derivedDataPath /private/tmp/NotchMove-Release-DerivedData build` passed on 2026-05-15.
- `script/verify_release_privacy.sh /private/tmp/NotchMove-Release-DerivedData/Build/Products/Release/NotchMove.app` passed on 2026-05-15.

## Assumptions

- Apple Speech is an added input option, not a replacement for WhisperKit or cloud transcription.
- Non-secret preferences remain in `UserDefaults`; credentials remain in Keychain.
- No SwiftData or persistent AI provenance metadata is added in this pass.
