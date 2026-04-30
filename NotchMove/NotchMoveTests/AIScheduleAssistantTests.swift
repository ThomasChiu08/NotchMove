//
//  AIScheduleAssistantTests.swift
//  NotchMoveTests
//
//  Created by Codex on 4/30/26.
//

import Foundation
import Testing
@testable import NotchMove

@MainActor
struct AIScheduleDraftTests {
    @Test func draftConversionPreservesDailyScheduleFields() {
        let startDate = makeAIDate(hour: 15, minute: 0)
        let endDate = makeAIDate(hour: 16, minute: 0)
        let draft = AIScheduleDraft(
            title: " Product meeting ",
            startDate: startDate,
            endDate: endDate,
            notes: " Room A ",
            reminderLeadMinutes: 15,
            isReminderEnabled: true,
            sourceTranscript: "remind me",
            confidence: .high
        )

        let item = draft.scheduleItem()

        #expect(item.title == "Product meeting")
        #expect(item.startDate == startDate)
        #expect(item.endDate == endDate)
        #expect(item.notes == "Room A")
        #expect(item.reminderLeadMinutes == 15)
        #expect(item.isReminderEnabled)
    }

    @Test func pastDraftDatesProduceWarning() {
        let result = ScheduleParseResult(
            drafts: [
                AIScheduleDraft(
                    title: "Old item",
                    startDate: makeAIDate(hour: 8, minute: 0),
                    confidence: .medium
                ),
            ],
            transcriptText: "old item"
        )
        let context = ScheduleParseContext(
            currentDate: makeAIDate(hour: 9, minute: 0),
            timeZone: TimeZone(secondsFromGMT: 0)!,
            localeIdentifier: "en",
            appLanguage: "en",
            defaultReminderLeadMinutes: 10,
            existingScheduleItems: []
        )

        let validated = result.validatedAgainstContext(context)

        #expect(validated.drafts[0].warning == "Parsed date is in the past.")
        #expect(validated.warnings == ["Parsed date is in the past."])
        #expect(validated.drafts[0].sourceTranscript == "old item")
    }

    @Test func parserDecoderRequiresSchemaFields() throws {
        let validJSON = """
        {
          "items": [
            {
              "title": "Product meeting",
              "startDate": "2026-04-30T15:00:00Z",
              "endDate": null,
              "notes": null,
              "reminderLeadMinutes": 10,
              "isReminderEnabled": true,
              "confidence": "high",
              "warning": null
            }
          ],
          "questions": [],
          "warnings": []
        }
        """

        let decoded = try JSONDecoder().decode(ScheduleParseResult.self, from: Data(validJSON.utf8))

        #expect(decoded.drafts.count == 1)
        #expect(decoded.drafts[0].title == "Product meeting")
        #expect(decoded.questions.isEmpty)
        #expect(decoded.warnings.isEmpty)

        let invalidJSON = #"{"items":[],"questions":[]}"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ScheduleParseResult.self, from: Data(invalidJSON.utf8))
        }
    }
}

@MainActor
struct AIScheduleAssistantServiceTests {
    @Test func serviceCallsTranscriptionBeforeParsingAndDeletesTemporaryAudio() async throws {
        let context = makeAIServiceContext()
        defer { context.cleanup() }

        let callLog = AICallLog()
        let recording = try makeTemporaryRecordingFile()
        let transcriptionProvider = FakeTranscriptionProvider(
            callLog: callLog,
            result: Transcript(text: "今天下午三点产品会", language: "zh", duration: 1)
        )
        let parserProvider = FakeScheduleParserProvider(
            callLog: callLog,
            result: ScheduleParseResult(
                drafts: [
                    AIScheduleDraft(
                        title: "产品会",
                        startDate: makeAIDate(hour: 15, minute: 0),
                        reminderLeadMinutes: 10,
                        confidence: .high
                    ),
                ]
            )
        )
        let service = AIScheduleAssistantService(
            preferences: context.preferences,
            transcriptionProvider: transcriptionProvider,
            parserProvider: parserProvider,
            dateProvider: { makeAIDate(hour: 9, minute: 0) }
        )

        let result = try await service.createDrafts(
            from: recording,
            existingScheduleItems: [],
            localeIdentifier: "zh-Hans",
            appLanguage: "zh-Hans"
        )

        #expect(callLog.values == ["transcribe", "parse"])
        #expect(result.transcriptText == "今天下午三点产品会")
        #expect(result.drafts[0].sourceTranscript == "今天下午三点产品会")
        #expect(!FileManager.default.fileExists(atPath: recording.url.path))
    }

    @Test func serviceDeletesTemporaryAudioWhenProviderFails() async throws {
        let context = makeAIServiceContext()
        defer { context.cleanup() }

        let recording = try makeTemporaryRecordingFile()
        let service = AIScheduleAssistantService(
            preferences: context.preferences,
            transcriptionProvider: FakeTranscriptionProvider(
                callLog: AICallLog(),
                result: Transcript(text: ""),
                error: AIScheduleAssistantError.networkUnavailable
            ),
            parserProvider: FakeScheduleParserProvider(callLog: AICallLog(), result: ScheduleParseResult())
        )

        do {
            _ = try await service.createDrafts(
                from: recording,
                existingScheduleItems: [],
                localeIdentifier: "en",
                appLanguage: "en"
            )
            Issue.record("Expected networkUnavailable.")
        } catch let error as AIScheduleAssistantError {
            #expect(error == .networkUnavailable)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #expect(!FileManager.default.fileExists(atPath: recording.url.path))
    }

    @Test func emptyTranscriptStopsBeforeParsing() async throws {
        let context = makeAIServiceContext()
        defer { context.cleanup() }

        let callLog = AICallLog()
        let service = AIScheduleAssistantService(
            preferences: context.preferences,
            transcriptionProvider: FakeTranscriptionProvider(
                callLog: callLog,
                result: Transcript(text: "   ")
            ),
            parserProvider: FakeScheduleParserProvider(callLog: callLog, result: ScheduleParseResult())
        )

        do {
            _ = try await service.createDrafts(
                from: makeTemporaryRecordingFile(),
                existingScheduleItems: [],
                localeIdentifier: "en",
                appLanguage: "en"
            )
            Issue.record("Expected emptyTranscript.")
        } catch let error as AIScheduleAssistantError {
            #expect(error == .emptyTranscript)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #expect(callLog.values == ["transcribe"])
    }
}

@MainActor
struct OpenAIProviderSupportTests {
    @Test func responseTextExtractorFindsOutputText() throws {
        let responseJSON = """
        {
          "output": [
            {
              "content": [
                {
                  "type": "output_text",
                  "text": "{\\"items\\":[],\\"questions\\":[],\\"warnings\\":[]}"
                }
              ]
            }
          ]
        }
        """

        let output = try OpenAIResponseTextExtractor.outputText(from: Data(responseJSON.utf8))

        #expect(output == #"{"items":[],"questions":[],"warnings":[]}"#)
    }

    @Test func providerMessagesCanRedactAPIKeys() {
        let redacted = AIScheduleAssistantError.redactedProviderMessage(
            "Invalid key sk-test123",
            apiKey: "sk-test123"
        )

        #expect(redacted == "Invalid key [redacted]")
    }

    @Test func providerRegistryIncludesOpenAICompatibleParserProviders() {
        #expect(AIProviderPreferences.supportedParserProviders.contains(.openAI))
        #expect(AIProviderPreferences.supportedParserProviders.contains(.deepSeek))
        #expect(AIProviderPreferences.supportedParserProviders.contains(.zhipu))
        #expect(AIProviderPreferences.supportedParserProviders.contains(.miniMax))
        #expect(AIProviderPreferences.supportedTranscriptionProviders == [.openAI])
        #expect(AIProviderID.deepSeek.definition.openAICompatibleBaseURL?.absoluteString == "https://api.deepseek.com")
        #expect(AIProviderID.zhipu.definition.defaultParserModel == "glm-5.1")
        #expect(AIProviderID.miniMax.definition.defaultParserModel == "MiniMax-M2.7")
    }

    @Test func parserProviderSelectionFallsBackToProviderDefaultModel() {
        let preferences = AIProviderPreferences(
            defaults: UserDefaults(suiteName: "NotchMoveProviderSelection-\(UUID().uuidString)")!,
            apiKeyStore: InMemoryAPIKeyStore()
        )

        preferences.parserModel = AIProviderPreferences.defaultParserModel
        preferences.selectParserProvider(.deepSeek)

        #expect(preferences.selectedParserProvider == .deepSeek)
        #expect(preferences.parserModel == "deepseek-v4-flash")
        #expect(preferences.availableParserModels.contains("deepseek-v4-pro"))
    }

    @Test func providerFactoryBuildsOpenAICompatibleParserProvider() throws {
        let preferences = AIProviderPreferences(
            defaults: UserDefaults(suiteName: "NotchMoveProviderFactory-\(UUID().uuidString)")!,
            apiKeyStore: InMemoryAPIKeyStore()
        )
        preferences.selectParserProvider(.zhipu)
        try preferences.saveAPIKey("zhipu-test-key", for: .zhipu)

        let provider = try AIProviderFactory.makeParserProvider(preferences: preferences)

        #expect(provider.displayName == "Zhipu GLM")
    }

    @Test func chatCompletionExtractorFindsMessageContent() throws {
        let responseJSON = """
        {
          "choices": [
            {
              "message": {
                "content": "{\\"items\\":[],\\"questions\\":[],\\"warnings\\":[]}"
              }
            }
          ]
        }
        """

        let output = try OpenAICompatibleChatResponseTextExtractor.outputText(from: Data(responseJSON.utf8))

        #expect(output == #"{"items":[],"questions":[],"warnings":[]}"#)
    }

    @Test func scheduleParserPromptStripsThinkingBlocksAndMarkdownFences() throws {
        let providerText = """
        <think>reasoning text</think>
        ```json
        {"items":[],"questions":[],"warnings":[]}
        ```
        """

        let result = try ScheduleParserPrompt.decodeResult(from: providerText, provider: "MiniMax")

        #expect(result.drafts.isEmpty)
        #expect(result.questions.isEmpty)
        #expect(result.warnings.isEmpty)
    }
}

@MainActor
private func makeAIServiceContext() -> AIServiceTestContext {
    let suiteName = "NotchMoveAITests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    let preferences = AIProviderPreferences(
        defaults: defaults,
        apiKeyStore: InMemoryAPIKeyStore()
    )
    preferences.isEnabled = true
    return AIServiceTestContext(suiteName: suiteName, defaults: defaults, preferences: preferences)
}

private func makeAIDate(hour: Int, minute: Int) -> Date {
    var components = DateComponents()
    components.calendar = Calendar(identifier: .gregorian)
    components.timeZone = TimeZone(secondsFromGMT: 0)
    components.year = 2026
    components.month = 4
    components.day = 30
    components.hour = hour
    components.minute = minute
    return components.date!
}

private func makeTemporaryRecordingFile() throws -> AudioRecordingFile {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("notchmove-ai-test-\(UUID().uuidString)")
        .appendingPathExtension("m4a")
    try Data("audio".utf8).write(to: url)
    return AudioRecordingFile(
        url: url,
        startedAt: makeAIDate(hour: 9, minute: 0),
        duration: 1,
        mimeType: "audio/mp4"
    )
}

@MainActor
private struct AIServiceTestContext {
    let suiteName: String
    let defaults: UserDefaults
    let preferences: AIProviderPreferences

    func cleanup() {
        defaults.removePersistentDomain(forName: suiteName)
    }
}

@MainActor
private final class AICallLog {
    var values: [String] = []
}

@MainActor
private final class FakeTranscriptionProvider: TranscriptionProvider {
    let displayName = "Fake Transcription"
    private let callLog: AICallLog
    private let result: Transcript
    private let error: Error?

    init(callLog: AICallLog, result: Transcript, error: Error? = nil) {
        self.callLog = callLog
        self.result = result
        self.error = error
    }

    func transcribe(recording: AudioRecordingFile, context: TranscriptionContext) async throws -> Transcript {
        callLog.values.append("transcribe")
        if let error {
            throw error
        }
        return result
    }
}

@MainActor
private final class FakeScheduleParserProvider: ScheduleParserProvider {
    let displayName = "Fake Parser"
    private let callLog: AICallLog
    private let result: ScheduleParseResult

    init(callLog: AICallLog, result: ScheduleParseResult) {
        self.callLog = callLog
        self.result = result
    }

    func parseSchedule(transcript: Transcript, context: ScheduleParseContext) async throws -> ScheduleParseResult {
        callLog.values.append("parse")
        return result
    }
}

private final class InMemoryAPIKeyStore: APIKeyStoring {
    private var apiKeys: [AIProviderID: String] = [:]

    func apiKey(for provider: AIProviderID) throws -> String? {
        apiKeys[provider]
    }

    func saveAPIKey(_ apiKey: String, for provider: AIProviderID) throws {
        apiKeys[provider] = apiKey
    }

    func deleteAPIKey(for provider: AIProviderID) throws {
        apiKeys.removeValue(forKey: provider)
    }
}
