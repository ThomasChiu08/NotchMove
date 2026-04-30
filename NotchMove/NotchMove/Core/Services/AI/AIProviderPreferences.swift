//
//  AIProviderPreferences.swift
//  NotchMove
//
//  Created by Codex on 4/30/26.
//

import Foundation
import Observation

enum AIProviderCapability: Hashable {
    case transcription
    case scheduleParsing
}

enum ScheduleParserAdapterKind: Equatable {
    case openAIResponses
    case openAICompatibleChat
}

enum AIProviderID: String, CaseIterable, Identifiable {
    case openAI = "openai"
    case deepSeek = "deepseek"
    case zhipu = "zhipu"
    case miniMax = "minimax"
    case openRouter = "openrouter"
    case groq = "groq"
    case xAI = "xai"
    case anthropic = "anthropic"
    case gemini = "gemini"

    var id: String { rawValue }

    var definition: AIProviderDefinition {
        AIProviderDefinition.provider(for: self)
    }

    var displayName: String {
        definition.displayName
    }

    func supports(_ capability: AIProviderCapability) -> Bool {
        definition.capabilities.contains(capability)
    }
}

struct AIModelDefinition: Identifiable, Equatable {
    let id: String
    let displayName: String
}

struct AIProviderDefinition: Identifiable, Equatable {
    let providerID: AIProviderID
    let displayName: String
    let capabilities: Set<AIProviderCapability>
    let transcriptionModels: [AIModelDefinition]
    let parserModels: [AIModelDefinition]
    let defaultTranscriptionModel: String?
    let defaultParserModel: String?
    let openAICompatibleBaseURL: URL?
    let scheduleParserAdapter: ScheduleParserAdapterKind?
    let usesJSONResponseFormat: Bool

    var id: AIProviderID { providerID }

    static func provider(for providerID: AIProviderID) -> AIProviderDefinition {
        all.first { $0.providerID == providerID }!
    }

    static var transcriptionProviders: [AIProviderID] {
        AIProviderID.allCases.filter { $0.supports(.transcription) }
    }

    static var scheduleParserProviders: [AIProviderID] {
        AIProviderID.allCases.filter { $0.supports(.scheduleParsing) }
    }

    private static let all: [AIProviderDefinition] = [
        AIProviderDefinition(
            providerID: .openAI,
            displayName: "OpenAI",
            capabilities: [.transcription, .scheduleParsing],
            transcriptionModels: [
                AIModelDefinition(id: "gpt-4o-mini-transcribe", displayName: "gpt-4o-mini-transcribe"),
                AIModelDefinition(id: "gpt-4o-transcribe", displayName: "gpt-4o-transcribe"),
            ],
            parserModels: [
                AIModelDefinition(id: "gpt-5.4-mini", displayName: "gpt-5.4-mini"),
                AIModelDefinition(id: "gpt-5.5", displayName: "gpt-5.5"),
                AIModelDefinition(id: "gpt-4o-mini", displayName: "gpt-4o-mini"),
            ],
            defaultTranscriptionModel: "gpt-4o-mini-transcribe",
            defaultParserModel: "gpt-5.4-mini",
            openAICompatibleBaseURL: nil,
            scheduleParserAdapter: .openAIResponses,
            usesJSONResponseFormat: false
        ),
        AIProviderDefinition(
            providerID: .deepSeek,
            displayName: "DeepSeek",
            capabilities: [.scheduleParsing],
            transcriptionModels: [],
            parserModels: [
                AIModelDefinition(id: "deepseek-v4-flash", displayName: "deepseek-v4-flash"),
                AIModelDefinition(id: "deepseek-v4-pro", displayName: "deepseek-v4-pro"),
                AIModelDefinition(id: "deepseek-chat", displayName: "deepseek-chat"),
            ],
            defaultTranscriptionModel: nil,
            defaultParserModel: "deepseek-v4-flash",
            openAICompatibleBaseURL: URL(string: "https://api.deepseek.com"),
            scheduleParserAdapter: .openAICompatibleChat,
            usesJSONResponseFormat: true
        ),
        AIProviderDefinition(
            providerID: .zhipu,
            displayName: "Zhipu GLM",
            capabilities: [.scheduleParsing],
            transcriptionModels: [],
            parserModels: [
                AIModelDefinition(id: "glm-5.1", displayName: "glm-5.1"),
                AIModelDefinition(id: "glm-5", displayName: "glm-5"),
                AIModelDefinition(id: "glm-4.7", displayName: "glm-4.7"),
                AIModelDefinition(id: "glm-4-flash-250414", displayName: "glm-4-flash-250414"),
            ],
            defaultTranscriptionModel: nil,
            defaultParserModel: "glm-5.1",
            openAICompatibleBaseURL: URL(string: "https://open.bigmodel.cn/api/paas/v4"),
            scheduleParserAdapter: .openAICompatibleChat,
            usesJSONResponseFormat: true
        ),
        AIProviderDefinition(
            providerID: .miniMax,
            displayName: "MiniMax",
            capabilities: [.scheduleParsing],
            transcriptionModels: [],
            parserModels: [
                AIModelDefinition(id: "MiniMax-M2.7", displayName: "MiniMax-M2.7"),
                AIModelDefinition(id: "MiniMax-M2.7-highspeed", displayName: "MiniMax-M2.7-highspeed"),
                AIModelDefinition(id: "MiniMax-M2.5", displayName: "MiniMax-M2.5"),
                AIModelDefinition(id: "MiniMax-M2.5-highspeed", displayName: "MiniMax-M2.5-highspeed"),
            ],
            defaultTranscriptionModel: nil,
            defaultParserModel: "MiniMax-M2.7",
            openAICompatibleBaseURL: URL(string: "https://api.minimax.io/v1"),
            scheduleParserAdapter: .openAICompatibleChat,
            usesJSONResponseFormat: true
        ),
        AIProviderDefinition(
            providerID: .openRouter,
            displayName: "OpenRouter",
            capabilities: [.scheduleParsing],
            transcriptionModels: [],
            parserModels: [
                AIModelDefinition(id: "openai/gpt-4o-mini", displayName: "openai/gpt-4o-mini"),
                AIModelDefinition(id: "anthropic/claude-3.5-sonnet", displayName: "anthropic/claude-3.5-sonnet"),
                AIModelDefinition(id: "deepseek/deepseek-chat", displayName: "deepseek/deepseek-chat"),
            ],
            defaultTranscriptionModel: nil,
            defaultParserModel: "openai/gpt-4o-mini",
            openAICompatibleBaseURL: URL(string: "https://openrouter.ai/api/v1"),
            scheduleParserAdapter: .openAICompatibleChat,
            usesJSONResponseFormat: true
        ),
        AIProviderDefinition(
            providerID: .groq,
            displayName: "Groq",
            capabilities: [.scheduleParsing],
            transcriptionModels: [],
            parserModels: [
                AIModelDefinition(id: "llama-3.3-70b-versatile", displayName: "llama-3.3-70b-versatile"),
                AIModelDefinition(id: "openai/gpt-oss-120b", displayName: "openai/gpt-oss-120b"),
            ],
            defaultTranscriptionModel: nil,
            defaultParserModel: "llama-3.3-70b-versatile",
            openAICompatibleBaseURL: URL(string: "https://api.groq.com/openai/v1"),
            scheduleParserAdapter: .openAICompatibleChat,
            usesJSONResponseFormat: true
        ),
        AIProviderDefinition(
            providerID: .xAI,
            displayName: "xAI",
            capabilities: [.scheduleParsing],
            transcriptionModels: [],
            parserModels: [
                AIModelDefinition(id: "grok-4", displayName: "grok-4"),
                AIModelDefinition(id: "grok-3-mini", displayName: "grok-3-mini"),
            ],
            defaultTranscriptionModel: nil,
            defaultParserModel: "grok-4",
            openAICompatibleBaseURL: URL(string: "https://api.x.ai/v1"),
            scheduleParserAdapter: .openAICompatibleChat,
            usesJSONResponseFormat: true
        ),
        AIProviderDefinition(
            providerID: .anthropic,
            displayName: "Anthropic",
            capabilities: [],
            transcriptionModels: [],
            parserModels: [],
            defaultTranscriptionModel: nil,
            defaultParserModel: nil,
            openAICompatibleBaseURL: nil,
            scheduleParserAdapter: nil,
            usesJSONResponseFormat: false
        ),
        AIProviderDefinition(
            providerID: .gemini,
            displayName: "Gemini",
            capabilities: [],
            transcriptionModels: [],
            parserModels: [],
            defaultTranscriptionModel: nil,
            defaultParserModel: nil,
            openAICompatibleBaseURL: nil,
            scheduleParserAdapter: nil,
            usesJSONResponseFormat: false
        ),
    ]
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

    static let defaultTranscriptionModel = AIProviderID.openAI.definition.defaultTranscriptionModel!
    static let defaultParserModel = AIProviderID.openAI.definition.defaultParserModel!

    static let supportedTranscriptionProviders = AIProviderDefinition.transcriptionProviders
    static let supportedParserProviders = AIProviderDefinition.scheduleParserProviders

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
        normalizeStoredProviderChoices()
    }

    var selectedTranscriptionProvider: AIProviderID {
        let provider = AIProviderID(rawValue: transcriptionProviderID) ?? .openAI
        return provider.supports(.transcription) ? provider : .openAI
    }

    var selectedParserProvider: AIProviderID {
        let provider = AIProviderID(rawValue: parserProviderID) ?? .openAI
        return provider.supports(.scheduleParsing) ? provider : .openAI
    }

    var availableTranscriptionModels: [String] {
        selectedTranscriptionProvider.definition.transcriptionModels.map(\.id)
    }

    var availableParserModels: [String] {
        selectedParserProvider.definition.parserModels.map(\.id)
    }

    var requiredAPIKeyProvidersForCurrentFlow: [AIProviderID] {
        let selected = Set([selectedTranscriptionProvider, selectedParserProvider])
        return AIProviderID.allCases.filter { selected.contains($0) }
    }

    func selectTranscriptionProvider(_ provider: AIProviderID) {
        guard provider.supports(.transcription) else { return }
        transcriptionProviderID = provider.rawValue
        transcriptionModel = validModel(
            currentModel: transcriptionModel,
            availableModels: provider.definition.transcriptionModels,
            defaultModel: provider.definition.defaultTranscriptionModel
        )
    }

    func selectParserProvider(_ provider: AIProviderID) {
        guard provider.supports(.scheduleParsing) else { return }
        parserProviderID = provider.rawValue
        parserModel = validModel(
            currentModel: parserModel,
            availableModels: provider.definition.parserModels,
            defaultModel: provider.definition.defaultParserModel
        )
    }

    func apiKey(for provider: AIProviderID) throws -> String? {
        try apiKeyStore.apiKey(for: provider)
    }

    func saveAPIKey(_ key: String, for provider: AIProviderID) throws {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedKey.isEmpty {
            try apiKeyStore.deleteAPIKey(for: provider)
        } else {
            try apiKeyStore.saveAPIKey(trimmedKey, for: provider)
        }
    }

    func firstMissingAPIKeyProviderForCurrentFlow() throws -> AIProviderID? {
        for provider in requiredAPIKeyProvidersForCurrentFlow {
            let key = try apiKey(for: provider)
            if key?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                return provider
            }
        }
        return nil
    }

    func openAIAPIKey() throws -> String? {
        try apiKey(for: .openAI)
    }

    func saveOpenAIAPIKey(_ key: String) throws {
        try saveAPIKey(key, for: .openAI)
    }

    private func normalizeStoredProviderChoices() {
        selectTranscriptionProvider(selectedTranscriptionProvider)
        selectParserProvider(selectedParserProvider)
    }

    private func validModel(
        currentModel: String,
        availableModels: [AIModelDefinition],
        defaultModel: String?
    ) -> String {
        let modelIDs = availableModels.map(\.id)
        if modelIDs.contains(currentModel) {
            return currentModel
        }

        if let defaultModel, modelIDs.contains(defaultModel) {
            return defaultModel
        }

        return modelIDs.first ?? currentModel
    }
}
