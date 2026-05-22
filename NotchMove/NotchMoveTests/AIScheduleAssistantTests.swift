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

        #expect(validated.drafts[0].warning == ScheduleParseResult.pastDateWarning)
        #expect(validated.warnings == [ScheduleParseResult.pastDateWarning])
        #expect(validated.drafts[0].sourceTranscript == "old item")
    }

    @Test func futureDraftDatesProduceNotTodayWarning() {
        let result = ScheduleParseResult(
            drafts: [
                AIScheduleDraft(
                    title: "Future item",
                    startDate: makeAIDate(month: 5, day: 1, hour: 8, minute: 0),
                    confidence: .medium
                ),
            ],
            transcriptText: "future item"
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

        #expect(validated.drafts[0].warning == ScheduleParseResult.notTodayWarning)
        #expect(validated.warnings == [ScheduleParseResult.notTodayWarning])
    }

    @Test func validationPreservesProviderWarningTextOnDraft() {
        let result = ScheduleParseResult(
            drafts: [
                AIScheduleDraft(
                    title: "Needs review",
                    startDate: makeAIDate(hour: 8, minute: 0),
                    confidence: .low,
                    warning: "Provider-specific warning"
                ),
            ]
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

        #expect(validated.drafts[0].warning == "Provider-specific warning")
        #expect(validated.warnings == [ScheduleParseResult.pastDateWarning])
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

    @Test func parserFixturesDecodeExpectedDraftsAcrossSupportedLanguages() throws {
        struct ParserFixture {
            let provider: String
            let providerText: String
            let expectedTitle: String
            let expectedStartDate: Date
            let expectedEndDate: Date?
            let expectedNotes: String?
            let expectedReminderLeadMinutes: Int
            let expectedConfidence: AIScheduleConfidence
        }

        let fixtures = [
            ParserFixture(
                provider: "English",
                providerText: """
                {
                  "items": [
                    {
                      "title": "Product sync",
                      "startDate": "2026-04-30T15:00:00Z",
                      "endDate": "2026-04-30T15:30:00Z",
                      "notes": "Discuss launch blockers",
                      "reminderLeadMinutes": 10,
                      "isReminderEnabled": true,
                      "confidence": "high",
                      "warning": null
                    }
                  ],
                  "questions": [],
                  "warnings": []
                }
                """,
                expectedTitle: "Product sync",
                expectedStartDate: makeAIDate(hour: 15, minute: 0),
                expectedEndDate: makeAIDate(hour: 15, minute: 30),
                expectedNotes: "Discuss launch blockers",
                expectedReminderLeadMinutes: 10,
                expectedConfidence: .high
            ),
            ParserFixture(
                provider: "Simplified Chinese",
                providerText: """
                ```json
                {
                  "items": [
                    {
                      "title": "产品评审",
                      "startDate": "2026-04-30T16:00:00Z",
                      "endDate": null,
                      "notes": "准备路线图",
                      "reminderLeadMinutes": 15,
                      "isReminderEnabled": true,
                      "confidence": "high",
                      "warning": null
                    }
                  ],
                  "questions": [],
                  "warnings": []
                }
                ```
                """,
                expectedTitle: "产品评审",
                expectedStartDate: makeAIDate(hour: 16, minute: 0),
                expectedEndDate: nil,
                expectedNotes: "准备路线图",
                expectedReminderLeadMinutes: 15,
                expectedConfidence: .high
            ),
            ParserFixture(
                provider: "Traditional Chinese",
                providerText: """
                {
                  "items": [
                    {
                      "title": "客戶會議",
                      "startDate": "2026-04-30T11:00:00Z",
                      "endDate": "2026-04-30T12:00:00Z",
                      "notes": "確認合約",
                      "reminderLeadMinutes": 5,
                      "isReminderEnabled": true,
                      "confidence": "medium",
                      "warning": null
                    }
                  ],
                  "questions": [],
                  "warnings": []
                }
                """,
                expectedTitle: "客戶會議",
                expectedStartDate: makeAIDate(hour: 11, minute: 0),
                expectedEndDate: makeAIDate(hour: 12, minute: 0),
                expectedNotes: "確認合約",
                expectedReminderLeadMinutes: 5,
                expectedConfidence: .medium
            ),
            ParserFixture(
                provider: "Japanese",
                providerText: """
                <think>ignore parser reasoning</think>
                {
                  "items": [
                    {
                      "title": "デザインレビュー",
                      "startDate": "2026-04-30T09:30:00Z",
                      "endDate": null,
                      "notes": "資料を確認",
                      "reminderLeadMinutes": 20,
                      "isReminderEnabled": true,
                      "confidence": "high",
                      "warning": null
                    }
                  ],
                  "questions": [],
                  "warnings": []
                }
                """,
                expectedTitle: "デザインレビュー",
                expectedStartDate: makeAIDate(hour: 9, minute: 30),
                expectedEndDate: nil,
                expectedNotes: "資料を確認",
                expectedReminderLeadMinutes: 20,
                expectedConfidence: .high
            ),
        ]

        for fixture in fixtures {
            let result = try ScheduleParserPrompt.decodeResult(
                from: fixture.providerText,
                provider: fixture.provider
            )

            #expect(result.drafts.count == 1)
            #expect(result.questions.isEmpty)
            #expect(result.warnings.isEmpty)

            let draft = try #require(result.drafts.first)
            #expect(draft.title == fixture.expectedTitle)
            #expect(draft.startDate == fixture.expectedStartDate)
            #expect(draft.endDate == fixture.expectedEndDate)
            #expect(draft.notes == fixture.expectedNotes)
            #expect(draft.reminderLeadMinutes == fixture.expectedReminderLeadMinutes)
            #expect(draft.isReminderEnabled)
            #expect(draft.confidence == fixture.expectedConfidence)
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

    @Test func serviceDeletesTemporaryAudioWhenParserFails() async throws {
        let context = makeAIServiceContext()
        defer { context.cleanup() }

        let recording = try makeTemporaryRecordingFile()
        let service = AIScheduleAssistantService(
            preferences: context.preferences,
            transcriptionProvider: FakeTranscriptionProvider(
                callLog: AICallLog(),
                result: Transcript(text: "meet at three")
            ),
            parserProvider: FakeScheduleParserProvider(
                callLog: AICallLog(),
                result: ScheduleParseResult(),
                error: AIScheduleAssistantError.invalidParserJSON(provider: "Fake Parser", message: "bad json")
            )
        )

        do {
            _ = try await service.createDrafts(
                from: recording,
                existingScheduleItems: [],
                localeIdentifier: "en",
                appLanguage: "en"
            )
            Issue.record("Expected invalidParserJSON.")
        } catch let error as AIScheduleAssistantError {
            #expect(error == .invalidParserJSON(provider: "Fake Parser", message: "bad json"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #expect(!FileManager.default.fileExists(atPath: recording.url.path))
    }

    @Test func emptyTranscriptDeletesTemporaryAudio() async throws {
        let context = makeAIServiceContext()
        defer { context.cleanup() }

        let callLog = AICallLog()
        let recording = try makeTemporaryRecordingFile()
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
                from: recording,
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

    @Test func cancellationDuringTranscriptionDeletesTemporaryAudioAndSkipsParser() async throws {
        let context = makeAIServiceContext()
        defer { context.cleanup() }

        let callLog = AICallLog()
        let recording = try makeTemporaryRecordingFile()
        let service = AIScheduleAssistantService(
            preferences: context.preferences,
            transcriptionProvider: FakeTranscriptionProvider(
                callLog: callLog,
                result: Transcript(text: "meet at three"),
                delay: .milliseconds(200)
            ),
            parserProvider: FakeScheduleParserProvider(callLog: callLog, result: ScheduleParseResult())
        )

        let task = Task {
            try await service.createDrafts(
                from: recording,
                existingScheduleItems: [],
                localeIdentifier: "en",
                appLanguage: "en"
            )
        }
        try await Task.sleep(for: .milliseconds(20))
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected cancellation.")
        } catch is CancellationError {
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(callLog.values == ["transcribe"])
        #expect(!FileManager.default.fileExists(atPath: recording.url.path))
    }
}

@MainActor
struct AIProviderSupportTests {
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

    @Test func providerErrorsCanRedactMultipleSecrets() {
        let error = AIScheduleAssistantError.providerRequestFailed(
            provider: "Provider",
            statusCode: 400,
            message: "bad secret-id and secret-key"
        )

        let redacted = AIScheduleAssistantError.redactedProviderError(
            error,
            secrets: ["secret-id", "secret-key"]
        )

        #expect((redacted as? AIScheduleAssistantError) == .providerRequestFailed(
            provider: "Provider",
            statusCode: 400,
            message: "bad [redacted] and [redacted]"
        ))
    }

    @Test func providerRegistryIncludesOpenAICompatibleParserProviders() {
        #expect(AIProviderPreferences.supportedParserProviders.contains(.dashScope))
        #expect(AIProviderPreferences.supportedParserProviders.contains(.openAI))
        #expect(AIProviderPreferences.supportedParserProviders.contains(.deepSeek))
        #expect(AIProviderPreferences.supportedParserProviders.contains(.zhipu))
        #expect(AIProviderPreferences.supportedParserProviders.contains(.miniMax))
        #expect(AIProviderPreferences.supportedParserProviders.contains(.moonshot))
        #expect(AIProviderPreferences.supportedParserProviders.contains(.tencentHunyuan))
        #expect(AIProviderPreferences.supportedParserProviders.contains(.baiduERNIE))
        #expect(AIProviderPreferences.supportedParserProviders.contains(.customOpenAICompatible))
        #expect(AIProviderPreferences.supportedTranscriptionProviders.contains(.dashScope))
        #expect(AIProviderPreferences.supportedTranscriptionProviders.contains(.openAI))
        #expect(AIProviderPreferences.supportedTranscriptionProviders.contains(.tencentCloudASR))
        #expect(AIProviderPreferences.supportedTranscriptionProviders.contains(.baiduSpeech))
        #expect(AIProviderPreferences.supportedTranscriptionProviders.contains(.iFlyTek))
        #expect(AIProviderPreferences.supportedTranscriptionProviders.contains(.volcengine))
        #expect(AIProviderPreferences.supportedTranscriptionProviders.contains(.appleSpeech))
        #expect(AIProviderPreferences.supportedTranscriptionProviders.contains(.localWhisperKit))
        #expect(AIProviderID.dashScope.definition.openAICompatibleBaseURL?.absoluteString == "https://dashscope.aliyuncs.com/compatible-mode/v1")
        #expect(AIProviderID.deepSeek.definition.openAICompatibleBaseURL?.absoluteString == "https://api.deepseek.com")
        #expect(AIProviderID.zhipu.definition.defaultParserModel == "glm-5.1")
        #expect(AIProviderID.miniMax.definition.defaultParserModel == "MiniMax-M2.7")
    }

    @Test func enabledProviderRegistryHasSetupGuides() {
        let enabledProviders = Set(
            AIProviderPreferences.supportedParserProviders + AIProviderPreferences.supportedTranscriptionProviders
        )

        for provider in enabledProviders {
            let guide = provider.definition.setupGuide

            #expect(!guide.overviewKey.isEmpty)
            #expect(!guide.stepsKey.isEmpty)
            #expect(!guide.requiredFieldNames.isEmpty)

            if provider != .customOpenAICompatible {
                #expect(guide.documentationURL != nil || guide.consoleURL != nil)
            }
        }
    }

    @Test func freshPreferencesDefaultToMainlandProviderPair() {
        let preferences = AIProviderPreferences(
            defaults: UserDefaults(suiteName: "NotchMoveMainlandDefaults-\(UUID().uuidString)")!,
            apiKeyStore: InMemoryAPIKeyStore()
        )

        #expect(preferences.selectedTranscriptionProvider == .dashScope)
        #expect(preferences.selectedParserProvider == .dashScope)
        #expect(preferences.transcriptionModel == "qwen3-asr-flash")
        #expect(preferences.parserModel == "qwen-plus")
    }

    @Test func localWhisperKitSelectionUsesBaseModelAndNoCredentials() {
        let preferences = AIProviderPreferences(
            defaults: UserDefaults(suiteName: "NotchMoveLocalSelection-\(UUID().uuidString)")!,
            apiKeyStore: InMemoryAPIKeyStore()
        )

        preferences.selectTranscriptionProvider(.localWhisperKit)

        #expect(preferences.selectedTranscriptionProvider == .localWhisperKit)
        #expect(preferences.transcriptionModel == LocalSpeechModelID.base.rawValue)
        #expect(preferences.credentialRequestsForCurrentFlow.allSatisfy { $0.provider != .localWhisperKit })
    }

    @Test func appleSpeechSelectionUsesAutomaticLocaleAndNoCredentials() {
        let preferences = AIProviderPreferences(
            defaults: UserDefaults(suiteName: "NotchMoveAppleSpeechSelection-\(UUID().uuidString)")!,
            apiKeyStore: InMemoryAPIKeyStore()
        )

        preferences.selectTranscriptionProvider(.appleSpeech)

        #expect(preferences.selectedTranscriptionProvider == .appleSpeech)
        #expect(preferences.transcriptionModel == AppleSpeechTranscriptionProvider.automaticLocaleID)
        #expect(preferences.credentialRequestsForCurrentFlow.allSatisfy { $0.provider != .appleSpeech })
        #expect(AppleSpeechTranscriptionProvider.configuredLocaleIdentifiers().map(\.id).contains("zh-CN"))
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

    @Test func providerFactoryBuildsMainlandTranscriptionProvider() throws {
        let preferences = AIProviderPreferences(
            defaults: UserDefaults(suiteName: "NotchMoveTranscriptionProviderFactory-\(UUID().uuidString)")!,
            apiKeyStore: InMemoryAPIKeyStore()
        )
        preferences.selectTranscriptionProvider(.tencentCloudASR)
        try preferences.saveCredential("secret-id", fieldID: AICredentialField.secretID.id, for: .tencentCloudASR)
        try preferences.saveCredential("secret-key", fieldID: AICredentialField.secretKey.id, for: .tencentCloudASR)

        let provider = try AIProviderFactory.makeTranscriptionProvider(preferences: preferences)

        #expect(provider.displayName == "Tencent Cloud ASR")
    }

    @Test func providerFactoryBuildsAppleSpeechProviderWithoutCredentials() throws {
        let preferences = AIProviderPreferences(
            defaults: UserDefaults(suiteName: "NotchMoveAppleSpeechProviderFactory-\(UUID().uuidString)")!,
            apiKeyStore: InMemoryAPIKeyStore()
        )
        preferences.selectTranscriptionProvider(.appleSpeech)

        let provider = try AIProviderFactory.makeTranscriptionProvider(preferences: preferences)

        #expect(provider.displayName == "Apple Speech")
    }

    @Test func providerFactoryRejectsMissingLocalWhisperKitModelBeforeCapture() {
        let preferences = AIProviderPreferences(
            defaults: UserDefaults(suiteName: "NotchMoveMissingLocalModel-\(UUID().uuidString)")!,
            apiKeyStore: InMemoryAPIKeyStore()
        )
        preferences.selectTranscriptionProvider(.localWhisperKit)

        do {
            _ = try AIProviderFactory.makeTranscriptionProvider(preferences: preferences)
            Issue.record("Expected missing local model.")
        } catch let error as AIScheduleAssistantError {
            #expect(error == .localModelUnavailable(model: LocalSpeechModelID.base.displayName))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func providerFactoryBuildsLocalWhisperKitProviderWhenModelIsReady() throws {
        let defaults = UserDefaults(suiteName: "NotchMoveReadyLocalModel-\(UUID().uuidString)")!
        let preferences = AIProviderPreferences(
            defaults: defaults,
            apiKeyStore: InMemoryAPIKeyStore()
        )
        let modelFolder = try makeLocalSpeechModelFolder()
        defer { try? FileManager.default.removeItem(at: modelFolder) }

        preferences.selectTranscriptionProvider(.localWhisperKit)
        storeLocalSpeechModelPath(modelFolder, model: .base, defaults: defaults)

        let provider = try AIProviderFactory.makeTranscriptionProvider(preferences: preferences)

        #expect(provider.displayName == "Local WhisperKit")
    }

    @Test func readinessReportsMissingCredentialsWithoutBuildingProviders() {
        let preferences = AIProviderPreferences(
            defaults: UserDefaults(suiteName: "NotchMoveReadinessMissingCredentials-\(UUID().uuidString)")!,
            apiKeyStore: InMemoryAPIKeyStore()
        )
        preferences.isEnabled = true

        let readiness = AIProviderFactory.captureReadiness(preferences: preferences)

        #expect(!readiness.isReady)
        #expect(readiness.transcription.error == .missingAPIKey(provider: "DashScope"))
        #expect(readiness.parser.error == .missingAPIKey(provider: "DashScope"))
        #expect(readiness.firstError == .missingAPIKey(provider: "DashScope"))
    }

    @Test func readinessReportsLocalWhisperKitModelState() {
        let preferences = AIProviderPreferences(
            defaults: UserDefaults(suiteName: "NotchMoveReadinessLocalModel-\(UUID().uuidString)")!,
            apiKeyStore: InMemoryAPIKeyStore()
        )
        preferences.isEnabled = true
        preferences.selectTranscriptionProvider(.localWhisperKit)

        let readiness = AIProviderFactory.transcriptionReadiness(preferences: preferences)

        #expect(!readiness.isReady)
        #expect(readiness.error == .localModelUnavailable(model: LocalSpeechModelID.base.displayName))
    }

    @Test func localSpeechModelStoreReportsReadinessFromPersistedModelPath() throws {
        let defaults = UserDefaults(suiteName: "NotchMoveLocalModelStore-\(UUID().uuidString)")!
        let modelFolder = try makeLocalSpeechModelFolder()
        defer { try? FileManager.default.removeItem(at: modelFolder) }
        storeLocalSpeechModelPath(modelFolder, model: .small, defaults: defaults)

        let store = LocalSpeechModelStore(defaults: defaults)

        guard case .ready(let readyURL) = store.state(for: .small) else {
            Issue.record("Expected ready local model.")
            return
        }
        #expect(readyURL.resolvingSymlinksInPath().path == modelFolder.resolvingSymlinksInPath().path)
    }

    @Test func missingProviderCredentialReportsFieldName() {
        let preferences = AIProviderPreferences(
            defaults: UserDefaults(suiteName: "NotchMoveMissingCredential-\(UUID().uuidString)")!,
            apiKeyStore: InMemoryAPIKeyStore()
        )
        preferences.selectTranscriptionProvider(.iFlyTek)

        do {
            _ = try AIProviderFactory.makeTranscriptionProvider(preferences: preferences)
            Issue.record("Expected missing credential.")
        } catch let error as AIScheduleAssistantError {
            #expect(error == .missingCredential(provider: "iFlyTek", field: "App ID"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
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

    @Test func scheduleParserPromptReportsInvalidJSONSeparately() {
        do {
            _ = try ScheduleParserPrompt.decodeResult(from: #"{"items":[]}"#, provider: "Parser")
            Issue.record("Expected invalidParserJSON.")
        } catch let error as AIScheduleAssistantError {
            guard case .invalidParserJSON(let provider, let message) = error else {
                Issue.record("Unexpected assistant error: \(error)")
                return
            }
            #expect(provider == "Parser")
            #expect(!message.isEmpty)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func captureReadinessRejectsInvalidCustomParserBaseURLBeforeRecording() throws {
        let preferences = AIProviderPreferences(
            defaults: UserDefaults(suiteName: "NotchMoveReadiness-\(UUID().uuidString)")!,
            apiKeyStore: InMemoryAPIKeyStore()
        )
        preferences.isEnabled = true
        preferences.selectTranscriptionProvider(.dashScope)
        preferences.selectParserProvider(.customOpenAICompatible)
        preferences.customParserBaseURL = "http:"
        try preferences.saveAPIKey("dashscope-test-key", for: .dashScope)
        try preferences.saveAPIKey("custom-test-key", for: .customOpenAICompatible)

        do {
            try AIProviderFactory.validateCaptureReadiness(preferences: preferences)
            Issue.record("Expected invalid custom base URL.")
        } catch let error as AIScheduleAssistantError {
            #expect(error == .providerResponseInvalid(
                provider: "Custom OpenAI-Compatible",
                message: "Custom provider base URL is invalid."
            ))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func captureReadinessRejectsCustomChatCompletionsEndpointShape() throws {
        let preferences = AIProviderPreferences(
            defaults: UserDefaults(suiteName: "NotchMoveReadinessEndpointShape-\(UUID().uuidString)")!,
            apiKeyStore: InMemoryAPIKeyStore()
        )
        preferences.isEnabled = true
        preferences.selectTranscriptionProvider(.dashScope)
        preferences.selectParserProvider(.customOpenAICompatible)
        preferences.customParserBaseURL = "https://example.com/v1/chat/completions"
        preferences.parserModel = "custom-model"
        try preferences.saveAPIKey("dashscope-test-key", for: .dashScope)
        try preferences.saveAPIKey("custom-test-key", for: .customOpenAICompatible)

        let readiness = AIProviderFactory.parserReadiness(preferences: preferences)

        #expect(readiness.error == .providerResponseInvalid(
            provider: "Custom OpenAI-Compatible",
            message: "Use the provider root Base URL, not the /chat/completions endpoint."
        ))
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

private func makeAIDate(month: Int = 4, day: Int = 30, hour: Int, minute: Int) -> Date {
    var components = DateComponents()
    components.calendar = Calendar(identifier: .gregorian)
    components.timeZone = TimeZone(secondsFromGMT: 0)
    components.year = 2026
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    return components.date!
}

private func makeTemporaryRecordingFile() throws -> AudioRecordingFile {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("notchmove-ai-test-\(UUID().uuidString)")
        .appendingPathExtension("wav")
    try Data("audio".utf8).write(to: url)
    return AudioRecordingFile(
        url: url,
        startedAt: makeAIDate(hour: 9, minute: 0),
        duration: 1,
        mimeType: "audio/wav"
    )
}

private func makeLocalSpeechModelFolder() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("notchmove-local-whisperkit-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

    for component in ["MelSpectrogram", "AudioEncoder", "TextDecoder"] {
        try FileManager.default.createDirectory(
            at: url.appendingPathComponent("\(component).mlmodelc"),
            withIntermediateDirectories: true
        )
    }

    return url
}

private func storeLocalSpeechModelPath(
    _ url: URL,
    model: LocalSpeechModelID,
    defaults: UserDefaults
) {
    defaults.set(url.path, forKey: "aiAssistant.localSpeechModelPath.\(model.rawValue)")
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
    private let delay: Duration?

    init(callLog: AICallLog, result: Transcript, error: Error? = nil, delay: Duration? = nil) {
        self.callLog = callLog
        self.result = result
        self.error = error
        self.delay = delay
    }

    func transcribe(recording: AudioRecordingFile, context: TranscriptionContext) async throws -> Transcript {
        callLog.values.append("transcribe")
        if let delay {
            try await Task.sleep(for: delay)
        }
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
    private let error: Error?

    init(callLog: AICallLog, result: ScheduleParseResult, error: Error? = nil) {
        self.callLog = callLog
        self.result = result
        self.error = error
    }

    func parseSchedule(transcript: Transcript, context: ScheduleParseContext) async throws -> ScheduleParseResult {
        callLog.values.append("parse")
        if let error {
            throw error
        }
        return result
    }
}

private final class InMemoryAPIKeyStore: APIKeyStoring {
    private var credentials: [String: String] = [:]

    func credential(_ fieldID: String, for provider: AIProviderID) throws -> String? {
        credentials["\(provider.rawValue).\(fieldID)"]
    }

    func saveCredential(_ value: String, fieldID: String, for provider: AIProviderID) throws {
        credentials["\(provider.rawValue).\(fieldID)"] = value
    }

    func deleteCredential(_ fieldID: String, for provider: AIProviderID) throws {
        credentials.removeValue(forKey: "\(provider.rawValue).\(fieldID)")
    }
}
