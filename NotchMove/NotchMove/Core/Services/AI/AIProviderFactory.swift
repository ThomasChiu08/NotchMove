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

        guard providerID == .openAI else {
            throw AIScheduleAssistantError.providerResponseInvalid(
                provider: providerID.displayName,
                message: "Unsupported transcription provider."
            )
        }

        let apiKey = try requiredAPIKey(for: providerID, preferences: preferences)
        return OpenAITranscriptionProvider(
            apiKey: apiKey,
            model: preferences.transcriptionModel,
            urlSession: urlSession
        )
    }

    @MainActor
    static func makeParserProvider(
        preferences: AIProviderPreferences,
        urlSession: URLSession = .shared
    ) throws -> any ScheduleParserProvider {
        let providerID = preferences.selectedParserProvider
        let definition = providerID.definition
        let apiKey = try requiredAPIKey(for: providerID, preferences: preferences)

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
        case nil:
            throw AIScheduleAssistantError.providerResponseInvalid(
                provider: providerID.displayName,
                message: "Unsupported parser provider."
            )
        }
    }

    @MainActor
    private static func requiredAPIKey(
        for provider: AIProviderID,
        preferences: AIProviderPreferences
    ) throws -> String {
        guard let apiKey = try preferences.apiKey(for: provider),
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw AIScheduleAssistantError.missingAPIKey(provider: provider.displayName)
        }

        return apiKey
    }
}
