//
//  AIProviderFactory.swift
//  NotchMove
//
//  Created by Codex on 5/1/26.
//

import Foundation

enum AIProviderFactory {
    @MainActor
    static func makeTranscriptionProvider(
        preferences: AIProviderPreferences,
        urlSession: URLSession = .shared
    ) throws -> any TranscriptionProvider {
        let providerID = preferences.selectedTranscriptionProvider
        let definition = providerID.definition

        switch definition.transcriptionAdapter {
        case .openAI:
            return OpenAITranscriptionProvider(
                apiKey: try requiredCredential(.apiKey, for: providerID, preferences: preferences),
                model: preferences.transcriptionModel,
                urlSession: urlSession
            )
        case .dashScopeOpenAICompatibleAudio:
            return DashScopeTranscriptionProvider(
                apiKey: try requiredCredential(.apiKey, for: providerID, preferences: preferences),
                model: preferences.transcriptionModel,
                urlSession: urlSession
            )
        case .tencentSentenceRecognition:
            return TencentCloudASRTranscriptionProvider(
                secretID: try requiredCredential(.secretID, for: providerID, preferences: preferences),
                secretKey: try requiredCredential(.secretKey, for: providerID, preferences: preferences),
                engineModelType: preferences.transcriptionModel,
                urlSession: urlSession
            )
        case .baiduShortSpeech:
            return BaiduSpeechTranscriptionProvider(
                apiKey: try requiredCredential(.apiKey, for: providerID, preferences: preferences),
                secretKey: try requiredCredential(.secretKey, for: providerID, preferences: preferences),
                devPID: preferences.transcriptionModel,
                urlSession: urlSession
            )
        case .iFlyTekVoiceDictation:
            return IFlyTekTranscriptionProvider(
                appID: try requiredCredential(.appID, for: providerID, preferences: preferences),
                apiKey: try requiredCredential(.apiKey, for: providerID, preferences: preferences),
                apiSecret: try requiredCredential(.apiSecret, for: providerID, preferences: preferences),
                urlSession: urlSession
            )
        case .volcengineFlash:
            return VolcengineTranscriptionProvider(
                apiKey: try requiredCredential(.apiKey, for: providerID, preferences: preferences),
                accessKey: try optionalCredential(.accessKey, for: providerID, preferences: preferences),
                model: preferences.transcriptionModel,
                urlSession: urlSession
            )
        case nil:
            throw AIScheduleAssistantError.providerResponseInvalid(
                provider: providerID.displayName,
                message: "Unsupported transcription provider."
            )
        }
    }

    @MainActor
    static func makeParserProvider(
        preferences: AIProviderPreferences,
        urlSession: URLSession = .shared
    ) throws -> any ScheduleParserProvider {
        let providerID = preferences.selectedParserProvider
        let definition = providerID.definition
        let apiKey = try requiredCredential(.apiKey, for: providerID, preferences: preferences)

        switch definition.scheduleParserAdapter {
        case .openAIResponses:
            return OpenAIScheduleParserProvider(
                apiKey: apiKey,
                model: preferences.parserModel,
                urlSession: urlSession
            )
        case .openAICompatibleChat:
            guard let baseURL = definition.openAICompatibleBaseURL else {
                throw AIScheduleAssistantError.providerResponseInvalid(
                    provider: providerID.displayName,
                    message: "Missing provider base URL."
                )
            }

            return OpenAICompatibleScheduleParserProvider(
                providerID: providerID,
                apiKey: apiKey,
                model: preferences.parserModel,
                baseURL: baseURL,
                usesJSONResponseFormat: definition.usesJSONResponseFormat,
                urlSession: urlSession
            )
        case .customOpenAICompatibleChat:
            let baseURLText = preferences.customParserBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let baseURL = URL(string: baseURLText), baseURL.scheme?.hasPrefix("http") == true else {
                throw AIScheduleAssistantError.providerResponseInvalid(
                    provider: providerID.displayName,
                    message: "Custom provider base URL is invalid."
                )
            }

            let model = preferences.parserModel.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !model.isEmpty else {
                throw AIScheduleAssistantError.providerResponseInvalid(
                    provider: providerID.displayName,
                    message: "Custom provider model is missing."
                )
            }

            return OpenAICompatibleScheduleParserProvider(
                providerID: providerID,
                apiKey: apiKey,
                model: model,
                baseURL: baseURL,
                usesJSONResponseFormat: definition.usesJSONResponseFormat,
                urlSession: urlSession
            )
        case nil:
            throw AIScheduleAssistantError.providerResponseInvalid(
                provider: providerID.displayName,
                message: "Unsupported parser provider."
            )
        }
    }

    @MainActor
    private static func requiredCredential(
        _ field: AICredentialField,
        for provider: AIProviderID,
        preferences: AIProviderPreferences
    ) throws -> String {
        guard let value = try preferences.credential(field.id, for: provider),
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            if field == .apiKey {
                throw AIScheduleAssistantError.missingAPIKey(provider: provider.displayName)
            }
            throw AIScheduleAssistantError.missingCredential(
                provider: provider.displayName,
                field: field.displayName
            )
        }

        return value
    }

    @MainActor
    private static func optionalCredential(
        _ field: AICredentialField,
        for provider: AIProviderID,
        preferences: AIProviderPreferences
    ) throws -> String? {
        let value = try preferences.credential(field.id, for: provider)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }
}
