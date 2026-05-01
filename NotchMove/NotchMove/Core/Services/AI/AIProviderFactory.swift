//
//  AIProviderFactory.swift
//  NotchMove
//
//  Created by Codex on 5/1/26.
//

import Foundation

struct AIProviderReadinessResult: Equatable {
    let capability: AIProviderCapability
    let provider: AIProviderID
    let error: AIScheduleAssistantError?

    var isReady: Bool { error == nil }
}

struct AICaptureReadinessResult: Equatable {
    let isEnabled: Bool
    let transcription: AIProviderReadinessResult
    let parser: AIProviderReadinessResult

    var isReady: Bool {
        isEnabled && transcription.isReady && parser.isReady
    }

    var firstError: AIScheduleAssistantError? {
        if !isEnabled { return .disabled }
        return transcription.error ?? parser.error
    }
}

enum AIProviderFactory {
    @MainActor
    static func validateCaptureReadiness(preferences: AIProviderPreferences) throws {
        let result = captureReadiness(preferences: preferences)
        if let error = result.firstError {
            throw error
        }

        _ = try makeTranscriptionProvider(preferences: preferences)
        _ = try makeParserProvider(preferences: preferences)
    }

    @MainActor
    static func captureReadiness(preferences: AIProviderPreferences) -> AICaptureReadinessResult {
        AICaptureReadinessResult(
            isEnabled: preferences.isEnabled,
            transcription: transcriptionReadiness(preferences: preferences),
            parser: parserReadiness(preferences: preferences)
        )
    }

    @MainActor
    static func transcriptionReadiness(preferences: AIProviderPreferences) -> AIProviderReadinessResult {
        let providerID = preferences.selectedTranscriptionProvider
        do {
            try validateTranscriptionConfiguration(preferences: preferences)
            return AIProviderReadinessResult(
                capability: .transcription,
                provider: providerID,
                error: nil
            )
        } catch let error as AIScheduleAssistantError {
            return AIProviderReadinessResult(
                capability: .transcription,
                provider: providerID,
                error: error
            )
        } catch {
            return AIProviderReadinessResult(
                capability: .transcription,
                provider: providerID,
                error: .providerResponseInvalid(
                    provider: providerID.displayName,
                    message: error.localizedDescription
                )
            )
        }
    }

    @MainActor
    static func parserReadiness(preferences: AIProviderPreferences) -> AIProviderReadinessResult {
        let providerID = preferences.selectedParserProvider
        do {
            try validateParserConfiguration(preferences: preferences)
            return AIProviderReadinessResult(
                capability: .scheduleParsing,
                provider: providerID,
                error: nil
            )
        } catch let error as AIScheduleAssistantError {
            return AIProviderReadinessResult(
                capability: .scheduleParsing,
                provider: providerID,
                error: error
            )
        } catch {
            return AIProviderReadinessResult(
                capability: .scheduleParsing,
                provider: providerID,
                error: .providerResponseInvalid(
                    provider: providerID.displayName,
                    message: error.localizedDescription
                )
            )
        }
    }

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
        case .appleSpeech:
            return AppleSpeechTranscriptionProvider(
                preferredLocaleIdentifier: preferences.transcriptionModel
            )
        case .localWhisperKit:
            let model = LocalSpeechModelID(rawValue: preferences.transcriptionModel) ?? .base
            let modelStore = LocalSpeechModelStore(defaults: preferences.defaults)
            return WhisperKitTranscriptionProvider(
                model: model,
                modelFolderURL: try modelStore.readyModelFolderURL(for: model)
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
            try validateOpenAICompatibleBaseURL(baseURL, provider: providerID)

            return OpenAICompatibleScheduleParserProvider(
                providerID: providerID,
                apiKey: apiKey,
                model: preferences.parserModel,
                baseURL: baseURL,
                usesJSONResponseFormat: definition.usesJSONResponseFormat,
                urlSession: urlSession
            )
        case .customOpenAICompatibleChat:
            let baseURL = try validatedCustomParserBaseURL(
                preferences.customParserBaseURL,
                provider: providerID
            )
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
    static func redactedProviderError(
        _ error: Error,
        preferences: AIProviderPreferences
    ) -> Error {
        do {
            return AIScheduleAssistantError.redactedProviderError(
                error,
                secrets: try currentCredentialValues(preferences: preferences)
            )
        } catch {
            return error
        }
    }

    @MainActor
    private static func validateTranscriptionConfiguration(
        preferences: AIProviderPreferences
    ) throws {
        let providerID = preferences.selectedTranscriptionProvider
        let definition = providerID.definition

        switch definition.transcriptionAdapter {
        case .appleSpeech:
            switch AppleSpeechTranscriptionProvider.authorizationState() {
            case .authorized, .notDetermined:
                try validateModelName(
                    preferences.transcriptionModel,
                    provider: providerID,
                    missingMessage: "Apple Speech recognition language is missing."
                )
            case .denied:
                throw AIScheduleAssistantError.speechRecognitionDenied
            case .restricted:
                throw AIScheduleAssistantError.speechRecognitionRestricted
            case .unknown:
                throw AIScheduleAssistantError.speechRecognitionUnavailable(locale: "system")
            }
        case .localWhisperKit:
            guard let model = LocalSpeechModelID(rawValue: preferences.transcriptionModel) else {
                throw AIScheduleAssistantError.providerResponseInvalid(
                    provider: providerID.displayName,
                    message: "Local WhisperKit model is invalid."
                )
            }
            let modelStore = LocalSpeechModelStore(defaults: preferences.defaults)
            _ = try modelStore.readyModelFolderURL(for: model)
        case .openAI,
             .dashScopeOpenAICompatibleAudio,
             .tencentSentenceRecognition,
             .baiduShortSpeech,
             .iFlyTekVoiceDictation,
             .volcengineFlash:
            try validateRequiredCredentials(for: providerID, preferences: preferences)
            try validateModelName(
                preferences.transcriptionModel,
                provider: providerID,
                missingMessage: "Transcription model is missing."
            )
        case nil:
            throw AIScheduleAssistantError.providerResponseInvalid(
                provider: providerID.displayName,
                message: "Unsupported transcription provider."
            )
        }
    }

    @MainActor
    private static func validateParserConfiguration(
        preferences: AIProviderPreferences
    ) throws {
        let providerID = preferences.selectedParserProvider
        let definition = providerID.definition

        switch definition.scheduleParserAdapter {
        case .openAIResponses:
            try validateRequiredCredentials(for: providerID, preferences: preferences)
            try validateModelName(
                preferences.parserModel,
                provider: providerID,
                missingMessage: "Parser model is missing."
            )
        case .openAICompatibleChat:
            try validateRequiredCredentials(for: providerID, preferences: preferences)
            guard let baseURL = definition.openAICompatibleBaseURL else {
                throw AIScheduleAssistantError.providerResponseInvalid(
                    provider: providerID.displayName,
                    message: "Missing provider base URL."
                )
            }
            try validateOpenAICompatibleBaseURL(baseURL, provider: providerID)
            try validateModelName(
                preferences.parserModel,
                provider: providerID,
                missingMessage: "Parser model is missing."
            )
        case .customOpenAICompatibleChat:
            try validateRequiredCredentials(for: providerID, preferences: preferences)
            _ = try validatedCustomParserBaseURL(preferences.customParserBaseURL, provider: providerID)
            try validateModelName(
                preferences.parserModel,
                provider: providerID,
                missingMessage: "Custom provider model is missing."
            )
        case nil:
            throw AIScheduleAssistantError.providerResponseInvalid(
                provider: providerID.displayName,
                message: "Unsupported parser provider."
            )
        }
    }

    @MainActor
    private static func validateRequiredCredentials(
        for provider: AIProviderID,
        preferences: AIProviderPreferences
    ) throws {
        for field in provider.definition.credentialFields where field.isRequired {
            _ = try requiredCredential(field, for: provider, preferences: preferences)
        }
    }

    private static func validateModelName(
        _ model: String,
        provider: AIProviderID,
        missingMessage: String
    ) throws {
        guard !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIScheduleAssistantError.providerResponseInvalid(
                provider: provider.displayName,
                message: missingMessage
            )
        }
    }

    private static func validatedCustomParserBaseURL(
        _ value: String,
        provider: AIProviderID
    ) throws -> URL {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = URLComponents(string: trimmedValue)
        guard let scheme = components?.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              components?.host?.isEmpty == false,
              let baseURL = components?.url
        else {
            throw AIScheduleAssistantError.providerResponseInvalid(
                provider: provider.displayName,
                message: "Custom provider base URL is invalid."
            )
        }

        try validateOpenAICompatibleBaseURL(baseURL, provider: provider)
        return baseURL
    }

    private static func validateOpenAICompatibleBaseURL(
        _ baseURL: URL,
        provider: AIProviderID
    ) throws {
        guard let components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              components.host?.isEmpty == false
        else {
            throw AIScheduleAssistantError.providerResponseInvalid(
                provider: provider.displayName,
                message: "Provider base URL is invalid."
            )
        }

        let path = components.path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()
        if path.hasSuffix("chat/completions") {
            throw AIScheduleAssistantError.providerResponseInvalid(
                provider: provider.displayName,
                message: "Use the provider root Base URL, not the /chat/completions endpoint."
            )
        }
    }

    @MainActor
    private static func currentCredentialValues(
        preferences: AIProviderPreferences
    ) throws -> [String] {
        try AIProviderID.allCases.flatMap { provider in
            try provider.definition.credentialFields.compactMap { field in
                try preferences.credential(field.id, for: provider)
            }
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
