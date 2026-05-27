# NotchMove AI Schedule Assistant Research

Date: 2026-05-01

Current status as of 2026-05-22: this remains a research snapshot, not the active implementation plan. Read it with `docs/plans/2026-05-01-ai-schedule-assistant-implementation-plan.md` and `docs/plans/2026-05-01-ai-input-full-flow-optimization-plan.md`; readiness diagnostics, local WhisperKit, Apple Speech, and opt-in global shortcut support have since been implemented.

## Goal

Capture the current NotchMove AI assistant analysis, summarize comparable GitHub projects, and define copyable implementation patterns for adding AI in a way that fits NotchMove's quiet menu bar product.

## Current Project Fit

NotchMove now has a working AI assistant implementation. The existing flow is:

```text
AudioCaptureService
  -> AIScheduleAssistantService
  -> TranscriptionProvider
  -> ScheduleParserProvider
  -> AIScheduleDraft
  -> DailyScheduleStore
  -> DailyScheduleReminderEngine
```

The important integration points are:

- `Core/Services/AI/AIScheduleAssistantService.swift`: orchestrates transcription, parsing, temporary audio cleanup, and draft validation.
- `Core/Services/AI/AIProviderPreferences.swift`: defines provider capabilities, credential fields, defaults, models, and current selections.
- `Core/Services/AI/APIKeyStore.swift`: stores AI credentials in macOS Keychain.
- `Core/Services/AI/ScheduleParserPrompt.swift`: gives the parser a strict reminder-extraction task and JSON schema.
- `Features/Dashboard/AIScheduleCaptureSheet.swift`: provides record, process, review, edit, and add-selected UI.
- `Features/Dashboard/UnifiedDashboardView.swift` and `Features/MenuBar/MenuBarController.swift`: expose dashboard and menu bar entry points.
- `DailyScheduleStore` and `DailyScheduleReminderEngine`: already persist confirmed schedule items and present due reminders.

The current direction is sound: AI produces drafts, the user confirms, and the existing schedule/reminder system remains the source of truth.

## GitHub References

### Pindrop

Repository: https://github.com/watzon/pindrop

Pindrop is a native macOS menu bar dictation app built with Swift/SwiftUI and WhisperKit. Its strongest reusable patterns are:

- Local-first transcription as a product trust signal.
- Separate transcription engines behind a protocol.
- Global hotkey modes after the core recording flow works.
- Optional AI enhancement, off by default.
- API keys and provider endpoints stored outside normal preferences.
- Clear distinction between microphone permission and optional Accessibility permission.

What NotchMove should copy conceptually:

- Add a local transcription provider later rather than making every user send audio to a cloud provider.
- Treat global push-to-talk as a second phase because it increases permission surface.
- Keep AI enhancement/extraction optional and scoped, not a chatbot.

### AudioWhisper

Repository: https://github.com/mazdak/AudioWhisper

AudioWhisper is a lightweight macOS menu bar transcription app with OpenAI, Gemini, Local WhisperKit, and Parakeet-MLX. Its strongest reusable patterns are:

- A provider dashboard that separates local and cloud engines.
- Model download, verify, and delete flows for local STT.
- Privacy copy that explicitly states when audio leaves the device.
- Keychain storage for cloud provider credentials.
- Permission copy split by feature: microphone, hotkeys, smart paste, and input monitoring.

What NotchMove should copy conceptually:

- A provider readiness check before capture starts.
- A model readiness state for local transcription.
- A privacy footer that changes meaningfully based on the selected provider.

What NotchMove should not copy for the first pass:

- Clipboard auto-paste.
- Transcription history dashboards.
- Usage metrics.
- General-purpose dictation behavior.

### AssisChat

Repository: https://github.com/noobnooc/AssisChat

AssisChat is a Swift/SwiftUI BYOK AI assistant supporting OpenAI and Claude. Its relevant pattern is adapter-based provider setup:

- User supplies API key and optional base URL.
- The app validates the provider before enabling it.
- Model availability is derived from active adapters.

What NotchMove should copy conceptually:

- Validate credentials and provider endpoint before letting users rely on them.
- Keep provider adapters small and replaceable.

What NotchMove should avoid:

- A chat-first UI. NotchMove's AI feature should stay a fast capture tool.

### Argmax Open-Source Swift / WhisperKit

Repository: https://github.com/argmaxinc/argmax-oss-swift

This is the current home of WhisperKit and related on-device speech frameworks. It became the technical base for NotchMove's implemented local transcription provider.

Copyable pattern:

- WhisperKit was added as a Swift Package product.
- It is wrapped behind NotchMove's existing `TranscriptionProvider` protocol.
- Model selection is explicit and capture does not trigger surprise downloads.

## Copyable Patterns

### 1. Pipeline Separation

Keep the pipeline split into independent stages:

```text
record audio -> transcribe -> parse schedule -> validate drafts -> user confirms -> save items
```

This makes testing straightforward and prevents provider-specific behavior from leaking into UI or reminder storage.

### 2. User-Confirmed Writes

AI should never silently create reminders. Draft review is the correct product boundary because schedule errors are user-visible and time-sensitive.

### 3. Provider Capability Matrix

The current capability split is right:

- transcription providers
- schedule parser providers
- credential fields per provider
- default model per provider
- custom OpenAI-compatible parser support

The next improvement is to add readiness and validation state, not to add more provider names.

### 4. Local-First Privacy Mode

Cloud providers are acceptable for an MVP, but the product should have a credible local STT path. The local model path should state:

- audio stays on device
- parser text may still go to the selected LLM provider unless a local parser exists
- local model files require disk space and download/verify steps

### 5. Permission Staging

Do not ask for Accessibility or Input Monitoring on first launch. Start with menu bar and dashboard capture. Historical recommendation: defer global push-to-talk until the base flow is trusted.

2026-05-22 update: global shortcut support is now implemented through Carbon registered hotkeys without requiring Accessibility/Input Monitoring for shortcut registration. Accessibility remains relevant for automatic text insertion in the voice input flow.

### 6. Narrow AI Scope

The feature should be "AI Add Schedule", not "AI Chat". The model should extract structured reminder drafts, not hold conversations or generate broad lifestyle advice in version 1.

## Recommended Product Direction

Ship the AI feature as a focused schedule capture assistant:

1. Make the current cloud batch flow reliable and easy to configure.
2. Add local WhisperKit transcription as the privacy-first option.
3. Add global push-to-talk after the app has clear permission copy.

2026-05-22 update: all three items above have implementation coverage. Live microphone/provider/manual release QA remains pending.

This preserves NotchMove's character: quiet, native, low-interruption, and explicit about privacy.

## Verification Snapshot

On 2026-05-01, the current project test suite passed with:

```bash
xcodebuild -project NotchMove.xcodeproj -scheme NotchMove -destination 'platform=macOS' test
```

Result: `TEST SUCCEEDED`.
