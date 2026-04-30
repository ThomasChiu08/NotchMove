//
//  AIProviderPreferences.swift
//  NotchMove
//
//  Created by Codex on 4/30/26.
//

import Foundation
import Observation

enum AIProviderID: String, CaseIterable, Identifiable {
    case openAI = "openai"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAI:
            "OpenAI"
        }
    }
}

@MainActor
@Observable
final class AIProviderPreferences {
    private enum Keys {
        static let isEnabled = "aiAssistant.isEnabled"
        static let transcriptionProviderID = "aiAssistant.transcriptionProviderID"
        static let parserProviderID = "aiAssistant.parserProviderID"
        static let transcriptionModel = "aiAssistant.transcriptionModel"
        static let parserModel = "aiAssistant.parserModel"
        static let languageMode = "aiAssistant.languageMode"
        static let defaultReminderLeadMinutes = "aiAssistant.defaultReminderLeadMinutes"
    }

    static let defaultTranscriptionModel = "gpt-4o-mini-transcribe"
    static let defaultParserModel = "gpt-5.4-mini"

    static let supportedTranscriptionModels = [
        "gpt-4o-mini-transcribe",
        "gpt-4o-transcribe",
    ]

    static let supportedParserModels = [
        "gpt-5.4-mini",
        "gpt-5.5",
        "gpt-4o-mini",
    ]

    let defaults: UserDefaults
    let apiKeyStore: APIKeyStoring

    var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Keys.isEnabled) }
    }

    var transcriptionProviderID: String {
        didSet { defaults.set(transcriptionProviderID, forKey: Keys.transcriptionProviderID) }
    }

    var parserProviderID: String {
        didSet { defaults.set(parserProviderID, forKey: Keys.parserProviderID) }
    }

    var transcriptionModel: String {
        didSet { defaults.set(transcriptionModel, forKey: Keys.transcriptionModel) }
    }

    var parserModel: String {
        didSet { defaults.set(parserModel, forKey: Keys.parserModel) }
    }

    var languageMode: String {
        didSet { defaults.set(languageMode, forKey: Keys.languageMode) }
    }

    var defaultReminderLeadMinutes: Int {
        didSet { defaults.set(defaultReminderLeadMinutes, forKey: Keys.defaultReminderLeadMinutes) }
    }

    init(
        defaults: UserDefaults = .standard,
        apiKeyStore: APIKeyStoring = KeychainAPIKeyStore()
    ) {
        self.defaults = defaults
        self.apiKeyStore = apiKeyStore
        defaults.register(defaults: [
            Keys.isEnabled: false,
            Keys.transcriptionProviderID: AIProviderID.openAI.rawValue,
            Keys.parserProviderID: AIProviderID.openAI.rawValue,
            Keys.transcriptionModel: Self.defaultTranscriptionModel,
            Keys.parserModel: Self.defaultParserModel,
            Keys.languageMode: "auto",
            Keys.defaultReminderLeadMinutes: 10,
        ])

        self.isEnabled = defaults.object(forKey: Keys.isEnabled) as? Bool ?? false
        self.transcriptionProviderID = defaults.string(forKey: Keys.transcriptionProviderID) ?? AIProviderID.openAI.rawValue
        self.parserProviderID = defaults.string(forKey: Keys.parserProviderID) ?? AIProviderID.openAI.rawValue
        self.transcriptionModel = defaults.string(forKey: Keys.transcriptionModel) ?? Self.defaultTranscriptionModel
        self.parserModel = defaults.string(forKey: Keys.parserModel) ?? Self.defaultParserModel
        self.languageMode = defaults.string(forKey: Keys.languageMode) ?? "auto"
        self.defaultReminderLeadMinutes = defaults.object(forKey: Keys.defaultReminderLeadMinutes) as? Int ?? 10
    }

    func openAIAPIKey() throws -> String? {
        try apiKeyStore.apiKey(for: .openAI)
    }

    func saveOpenAIAPIKey(_ key: String) throws {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedKey.isEmpty {
            try apiKeyStore.deleteAPIKey(for: .openAI)
        } else {
            try apiKeyStore.saveAPIKey(trimmedKey, for: .openAI)
        }
    }
}
