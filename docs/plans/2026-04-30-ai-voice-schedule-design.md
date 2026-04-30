# NotchMove AI Voice Schedule Assistant Design

Date: 2026-04-30

## 1. Goal

Add an AI voice assistant to NotchMove so users can hold a shortcut or use a menu bar microphone action, describe their schedule and reminder needs, review the AI-parsed result, and add confirmed items to the existing daily schedule reminder system.

The feature should feel like a fast capture tool, not a general chatbot. It should preserve NotchMove's current product character: quiet, local-first where practical, low interruption, and explicit about privacy.

## 2. Product Principles

- User-confirmed writes: AI never creates reminders silently. Parsed items become drafts first.
- Push-to-talk by default: microphone capture starts only during an explicit user action.
- Provider-agnostic core: speech-to-text and schedule parsing are separate provider layers.
- Reuse existing reminder infrastructure: confirmed drafts become `DailyScheduleItem` records and are handled by the existing `DailyScheduleStore` and `DailyScheduleReminderEngine`.
- Privacy-forward language: settings and permission prompts must say when audio/text leaves the Mac.
- Start reliable, then make it realtime: first version should use completed audio upload, with realtime streaming reserved for a later phase.

## 3. Existing Project Fit

Current relevant systems:

- `DailyScheduleItem`: already models title, start/end time, notes, reminder lead time, reminder enabled state, snooze, and last reminded date.
- `DailyScheduleStore`: already persists schedule items through `UserDefaults` JSON and exposes add/update/delete/replace flows.
- `DailyScheduleReminderEngine`: already checks upcoming items every 30 seconds and presents schedule reminders through the notch overlay.
- `UnifiedDashboardView` and `DailyScheduleDashboardView`: already provide a primary window with Today and Schedule pages.
- `MenuBarController`: already owns quick actions from the menu bar.

The AI assistant should therefore be a capture and draft-generation layer, not a replacement for the schedule engine.

## 4. Provider Research Summary

### Speech-To-Text Providers

| Provider | Fit | Strengths | Risks / Notes |
| --- | --- | --- | --- |
| OpenAI | High | `gpt-4o-transcribe`, `gpt-4o-mini-transcribe`, Realtime transcription, same vendor can also do structured parsing | Realtime is more complex; cloud audio processing requires clear privacy copy |
| Deepgram | High | Strong realtime STT, Nova/Flux models, smart formatting, automatic language detection, keyterm prompting | STT only; still needs separate parser provider |
| AssemblyAI | High | Mature WebSocket streaming, clear pricing, word timestamps/confidence, strong voice product docs | STT only; multilingual streaming support is narrower than batch |
| xAI | Medium | Very low published STT pricing, REST and streaming support | Newer API surface; ecosystem and reliability need validation before default use |
| Groq | Medium | OpenAI-compatible transcription endpoint and fast Whisper-family inference | Better as fast completed-audio transcription than the first realtime default |
| Apple Speech / WhisperKit | Medium | Local/private transcription path; WhisperKit has native Swift package support | Larger implementation and model-management cost; better as later privacy mode |

### Parser Providers

| Provider | Fit | Strengths | Risks / Notes |
| --- | --- | --- | --- |
| OpenAI | High | Structured Outputs through JSON Schema; same vendor can handle STT and parsing | Keep parser prompt narrow and schema-driven |
| Anthropic Claude | Medium-High | Structured outputs / strict tool use available; strong instruction following | Separate API shape and beta/version headers may add maintenance |
| Google Gemini / Vertex AI | Medium-High | Response schema support; good extraction candidate | Google Cloud setup is heavier for a small menu bar app |
| Azure OpenAI | Medium | Structured outputs and enterprise deployment options | Most useful for enterprise users, not first indie-user default |
| Groq / OpenRouter | Medium | Can provide OpenAI-compatible chat completion style APIs | Schema fidelity varies by model/provider; should be treated as advanced adapter |

Key conclusion: "AI Provider" should be split into `TranscriptionProvider` and `ScheduleParserProvider`. A user might choose Deepgram for STT and OpenAI for parsing, or OpenAI for both.

## 5. Considered Approaches

### Approach A: OpenAI-Only MVP

Use OpenAI for completed-audio transcription and structured schedule parsing.

Flow:

1. Capture audio locally while the user holds the action.
2. Upload a short audio file to OpenAI transcription.
3. Send transcript to OpenAI Responses API with a strict schedule JSON schema.
4. Show drafts for confirmation.
5. Add confirmed drafts to `DailyScheduleStore`.

Pros:

- Fastest to build and test.
- One API key, one vendor, one error model.
- Good enough for a credible first version.
- Lets product UX mature before expanding provider complexity.

Cons:

- Provider choice is not fulfilled in the first shipped version.
- Users who prefer Deepgram, Claude, Gemini, or local STT must wait.

### Approach B: Provider-Agnostic Core From Day One

Build protocols and settings for multiple transcription and parser providers immediately, but initially ship one or two concrete adapters.

Pros:

- Supports the user's multi-provider direction.
- Avoids hard-coding OpenAI assumptions into the core feature.
- Makes future provider additions mostly adapter work.

Cons:

- More settings, validation, and testing up front.
- More failure modes before the main UX has been proven.

### Approach C: Realtime Voice Agent

Use a realtime STT or voice model from the start. Show live transcript in the notch overlay while the user speaks.

Pros:

- Best perceived latency and most "AI-native" feel.
- Can support live correction and richer interactions later.

Cons:

- WebSocket/WebRTC audio streaming adds more moving parts.
- Harder to test reliably.
- Not needed for the first value proposition because users are dictating short schedule commands.

## 6. Recommendation

Use a hybrid of Approach A and Approach B:

- Build the provider-agnostic interfaces in version 1.
- Ship OpenAI as the first working provider for both transcription and parsing.
- Design settings so Deepgram, AssemblyAI, xAI, Groq, Claude, Gemini, Azure OpenAI, and local STT can be added without changing the user flow.
- Use completed-audio upload in version 1. Realtime transcription becomes phase 3.

This keeps the first implementation small enough to finish while avoiding a dead-end architecture.

## 7. User Experience

### Primary Capture Entry Points

Version 1 should include:

- Menu bar item: `AI Add Schedule...` with a microphone symbol.
- Dashboard header action on Today and Schedule pages: `Speak`.
- Local app keyboard shortcut while the dashboard is focused.

Version 2 can add:

- Configurable global push-to-talk shortcut.
- Accessibility/Input Monitoring onboarding if the chosen global hotkey approach requires it.

Reasoning: global key monitoring can create a privacy/trust cost on macOS. Apple documents that global key monitors for key events require accessibility trust. NotchMove should avoid asking for that permission before the AI capture UX is proven.

### Capture Flow

```text
User action
  -> Record short audio locally
  -> Show recording state
  -> User releases / stops
  -> Transcribe
  -> Parse transcript into schedule drafts
  -> Show confirmation sheet
  -> User confirms selected drafts
  -> Add items to DailyScheduleStore
  -> Existing DailyScheduleReminderEngine handles reminders
```

### Confirmation Sheet

The confirmation sheet should show:

- Transcript text.
- Parsed schedule draft rows.
- Any AI questions or warnings.
- Editable title, time range, notes, reminder lead minutes, and enabled toggle.
- `Add Selected` primary action.
- `Cancel` secondary action.

The sheet should allow the user to fix AI mistakes without leaving the flow.

Example user command:

```text
今天下午三点提醒我开产品会议，提前十分钟提醒。明天早上九点半提醒我交报告。
```

Example result:

```text
Transcript
今天下午三点提醒我开产品会议，提前十分钟提醒。明天早上九点半提醒我交报告。

Drafts
Today 15:00  产品会议      10 min before
Tomorrow 09:30  交报告     10 min before
```

If the existing store only displays today's schedule, future-dated items may still be stored but should be surfaced in a future schedule view. If that broader UI is not ready, version 1 can limit accepted items to today and ask the user to confirm when a parsed item is outside today.

## 8. Data Model

### New Draft Model

Add a non-persistent draft model:

```swift
struct AIScheduleDraft: Identifiable, Equatable {
    var id: UUID
    var title: String
    var startDate: Date
    var endDate: Date?
    var notes: String?
    var reminderLeadMinutes: Int
    var isReminderEnabled: Bool
    var sourceTranscript: String
    var confidence: AIScheduleConfidence
    var warning: String?
}
```

### Existing Persistent Model

Confirmed drafts become `DailyScheduleItem`:

```swift
DailyScheduleItem(
    title: draft.title,
    startDate: draft.startDate,
    endDate: draft.endDate,
    notes: draft.notes,
    reminderLeadMinutes: draft.reminderLeadMinutes,
    isReminderEnabled: draft.isReminderEnabled
)
```

No persistence migration is required for version 1 if confirmed items only use existing fields.

### Future Metadata

If product needs provenance later, add optional fields to `DailyScheduleItem`:

- `source`: manual, import, aiVoice.
- `createdAt`.
- `updatedAt`.
- `originalTranscript`.

Do not add these in version 1 unless the UI uses them.

## 9. Parser Schema

The parser provider should return a strict schema. Use ISO 8601 dates with timezone offsets so relative phrases are resolved before app insertion.

```json
{
  "type": "object",
  "additionalProperties": false,
  "required": ["items", "questions", "warnings"],
  "properties": {
    "items": {
      "type": "array",
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "title",
          "startDate",
          "endDate",
          "notes",
          "reminderLeadMinutes",
          "isReminderEnabled",
          "confidence",
          "warning"
        ],
        "properties": {
          "title": { "type": "string" },
          "startDate": { "type": "string" },
          "endDate": { "type": ["string", "null"] },
          "notes": { "type": ["string", "null"] },
          "reminderLeadMinutes": { "type": "integer" },
          "isReminderEnabled": { "type": "boolean" },
          "confidence": {
            "type": "string",
            "enum": ["high", "medium", "low"]
          },
          "warning": { "type": ["string", "null"] }
        }
      }
    },
    "questions": {
      "type": "array",
      "items": { "type": "string" }
    },
    "warnings": {
      "type": "array",
      "items": { "type": "string" }
    }
  }
}
```

The parser prompt must include:

- Current date/time and timezone.
- App language.
- User locale.
- Existing schedule items for the target day, if available.
- Default reminder lead minutes.
- Rule: return drafts only; do not claim items have been added.
- Rule: ask questions when time/date is ambiguous.
- Rule: never invent exact dates for ambiguous future phrases.

## 10. Architecture

### Services

```text
Core/Services/AI/
├─ AIProviderPreferences.swift
├─ APIKeyStore.swift
├─ AudioCaptureService.swift
├─ AudioRecordingFile.swift
├─ TranscriptionProvider.swift
├─ OpenAITranscriptionProvider.swift
├─ ScheduleParserProvider.swift
├─ OpenAIScheduleParserProvider.swift
├─ AIScheduleDraft.swift
├─ AIScheduleAssistantService.swift
└─ AIScheduleAssistantError.swift
```

### Protocol Boundaries

```swift
protocol TranscriptionProvider {
    func transcribe(recording: AudioRecordingFile, context: TranscriptionContext) async throws -> Transcript
}

protocol ScheduleParserProvider {
    func parseSchedule(transcript: Transcript, context: ScheduleParseContext) async throws -> ScheduleParseResult
}
```

The orchestrator should own the end-to-end flow:

```swift
final class AIScheduleAssistantService {
    func createDrafts(from recording: AudioRecordingFile) async throws -> ScheduleParseResult
}
```

Views should not know about HTTP details or provider request formats.

### Provider Adapter Requirements

Each adapter should define:

- Display name.
- Required API key label.
- Whether it supports completed-audio transcription.
- Whether it supports realtime streaming.
- Supported languages, if relevant.
- Request timeout defaults.
- Error mapping into app-level errors.

### API Keys

API keys should be stored in Keychain, not `UserDefaults`.

`UserDefaults` can store only:

- Selected transcription provider id.
- Selected parser provider id.
- Selected models.
- Feature enabled state.
- Default language / auto-detect preference.
- Shortcut preference.

## 11. macOS Permissions And Entitlements

Current entitlement file only enables App Sandbox. AI voice requires additional permissions:

- Microphone entitlement for sandboxed audio input.
- `NSMicrophoneUsageDescription` in generated Info.plist settings.
- Outgoing network client entitlement for cloud provider API calls.

For version 1, avoid global keyboard monitoring permissions by using menu bar and focused-window actions first.

If adding global push-to-talk later, evaluate:

- Carbon `RegisterEventHotKey` for registered shortcuts.
- `NSEvent` global monitor only if necessary.
- Accessibility/Input Monitoring onboarding copy if required.

Do not request Accessibility/Input Monitoring in version 1 unless the implementation cannot meet the product requirement without it.

## 12. Privacy And Security

### User-Facing Privacy Copy

Settings copy should state:

- NotchMove records only while the user starts voice capture.
- Cloud providers may receive audio and/or transcript text depending on selected provider.
- AI output is reviewed before any reminder is added.
- API keys are stored in the macOS Keychain.
- Users can disable AI features at any time.

### Data Handling

Version 1 should:

- Store temporary audio files only long enough to upload.
- Delete temporary audio after transcription succeeds or fails.
- Avoid logging transcript text by default.
- Avoid logging full provider responses.
- Redact API keys in all errors.

### Network

All provider calls should use HTTPS or WSS. The app should have no incoming network server entitlement.

## 13. Error Handling

Common errors and UI responses:

| Error | UI Response |
| --- | --- |
| Microphone denied | Show permission explanation and button to open System Settings |
| Missing API key | Open AI Assistant settings |
| Network unavailable | Keep transcript/audio state if possible and offer retry |
| Provider auth failed | Ask user to update API key |
| Transcription empty | Ask user to try again; do not parse |
| Parser returns no items | Show transcript and AI questions |
| Ambiguous time/date | Show questions; do not auto-add |
| Parsed date is in the past | Warn and require user edit |
| Duplicate-like item | Warn but allow user confirmation |

Provider-specific errors should be normalized into `AIScheduleAssistantError` so the UI remains stable.

## 14. UI Surfaces

### Menu Bar

Add:

- `AI Add Schedule...`
- Disabled status text while processing, e.g. `AI is parsing...`

Avoid long menu item labels.

### Dashboard

Add `Speak` button to:

- Today header.
- Schedule header.

The button opens the same capture sheet.

### AI Capture Sheet

States:

1. Ready: microphone button and short status.
2. Recording: waveform or timer, stop action.
3. Transcribing: spinner and provider name.
4. Parsing: spinner and transcript preview.
5. Review: editable drafts and add action.
6. Error: concise error, retry/settings action.

Do not put feature explanations inside the main workflow. Longer privacy/details text belongs in settings.

### Settings

Add a new `AI Assistant` settings section/page:

- Enable AI assistant.
- Transcription provider picker.
- Parser provider picker.
- Model pickers where relevant.
- API key fields per selected provider.
- Default language / auto detect.
- Default reminder lead time for AI-created drafts.
- Shortcut configuration placeholder.
- Privacy note.

## 15. Testing Strategy

### Unit Tests

- Parser response decoder validates required fields.
- Invalid dates and past dates produce warnings/errors.
- Draft-to-`DailyScheduleItem` conversion preserves fields.
- `AIScheduleAssistantService` calls transcription before parsing.
- Provider error mapping redacts secrets.
- Temporary audio cleanup is called on success and failure.

### Integration Tests

Use fake providers:

- Successful Chinese transcript with two items.
- Ambiguous transcript with questions and no auto-add.
- Network failure during transcription.
- Parser schema failure.
- Duplicate-like existing item warning.

### Manual QA

- First microphone permission prompt.
- Missing API key flow.
- Wrong API key flow.
- Menu bar capture.
- Dashboard capture.
- Confirmed drafts appear in Today/Schedule.
- Existing schedule reminder fires for AI-created item.
- Temporary audio files are not left behind after failure.

## 16. Rollout Plan

### Phase 1: OpenAI MVP

Status: implemented as first-pass MVP on 2026-04-30.

- Add permissions and settings.
- Add Keychain API key storage.
- Add audio capture and temporary recording.
- Add OpenAI transcription adapter.
- Add OpenAI structured parser adapter.
- Add review sheet.
- Add confirmed drafts to `DailyScheduleStore`.
- Add unit tests with fake providers.

### Phase 2: Multi-Provider Adapters

- Add Deepgram and AssemblyAI STT adapters.
- Add Groq and xAI completed-audio STT adapters if reliability is acceptable.
- Add Claude and Gemini parser adapters.
- Add provider health/test button in settings.

### Phase 3: Realtime Voice UX

- Add streaming transcription provider capability.
- Show live transcript in the capture sheet.
- Optionally show compact notch recording state.
- Add global push-to-talk after permission review.

### Phase 4: Local Privacy Mode

- Add WhisperKit or Apple Speech local transcription adapter.
- Allow local STT + cloud parser.
- Explore local parser only if model size and accuracy make sense.

## 17. Open Decisions

- Should version 1 allow future-dated schedule items when current dashboard is day-focused?
- Should OpenAI be the bundled default, or should first launch ask the user to choose a provider?
- Should NotchMove ever ship a developer-owned proxy, or stay BYOK-only?
- Should AI-created drafts include provenance metadata in persistent storage?
- What is the default push-to-talk shortcut if global hotkeys are added?

## 18. Source References

- OpenAI Speech to Text: https://developers.openai.com/api/docs/guides/speech-to-text
- OpenAI Realtime Transcription: https://developers.openai.com/api/docs/guides/realtime-transcription
- OpenAI Structured Outputs: https://developers.openai.com/api/docs/guides/structured-outputs
- OpenAI Models: https://developers.openai.com/api/docs/models
- Deepgram Pricing / STT: https://deepgram.com/pricing
- AssemblyAI Streaming STT: https://www.assemblyai.com/products/streaming-speech-to-text
- xAI Speech to Text: https://docs.x.ai/developers/models/speech-to-text
- Groq Speech to Text: https://console.groq.com/docs/speech-to-text
- Anthropic Structured Outputs: https://docs.claude.com/en/docs/build-with-claude/structured-outputs
- Google Vertex AI Structured Output: https://cloud.google.com/vertex-ai/generative-ai/docs/multimodal/control-generated-output
- Apple Microphone Entitlement: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.device.microphone
- Apple Network Client Entitlement: https://developer.apple.com/documentation/BundleResources/Entitlements/com.apple.security.network.client
- Apple NSEvent Global Monitor: https://developer.apple.com/documentation/appkit/nsevent/addglobalmonitorforevents%28matching%3Ahandler%3A%29
