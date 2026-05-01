# NotchMove AI Input Full-Flow Optimization Plan

## Summary

Implement a complete AI input flow that fits macOS: Apple Speech/system permission support, a clearer native Settings experience, reliable readiness diagnostics, and the existing draft-review boundary before writing schedule items.

Current baseline:

- The app already has microphone entitlement and usage copy, Keychain-backed credentials, WhisperKit, cloud transcription/parser providers, the AI capture sheet, and AI assistant tests.
- The missing pieces are Apple Speech as a transcription provider, `NSSpeechRecognitionUsageDescription`, explicit Speech Recognition permission handling, actionable system settings recovery, and a less crowded AI settings layout.

## Key Changes

- Add Apple Speech as a transcription provider behind the existing `TranscriptionProvider` protocol.
- Keep Apple Speech scoped to transcription; schedule extraction still uses the selected parser provider.
- Add Speech Recognition authorization checks, request flow, localized errors, and macOS Settings recovery buttons.
- Add `NSSpeechRecognitionUsageDescription` to generated Info.plist build settings.
- Split AI Settings into overview, input, parser, credentials, and diagnostics sections.
- Show microphone and Speech Recognition permission state in Settings.
- Keep privacy copy accurate for cloud, Apple Speech, and local WhisperKit flows.
- Keep AI output as editable drafts; confirmed drafts are still the only path into `DailyScheduleStore`.

## Test Plan

- Unit tests for provider registry, Apple Speech provider construction, no-credential behavior, and model defaults.
- Existing AI assistant tests for parser fixtures, provider factory wiring, readiness diagnostics, secret redaction, and temporary audio cleanup.
- Manual checks for Settings layout, Apple Speech permission request, microphone denial recovery, local model missing state, and AI capture draft review.

## Assumptions

- Apple Speech is an added input option, not a replacement for WhisperKit or cloud transcription.
- Non-secret preferences remain in `UserDefaults`; credentials remain in Keychain.
- No SwiftData or persistent AI provenance metadata is added in this pass.
