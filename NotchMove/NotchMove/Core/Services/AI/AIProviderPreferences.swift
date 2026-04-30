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

enum TranscriptionAdapterKind: Equatable {
    case openAI
    case dashScopeOpenAICompatibleAudio
    case tencentSentenceRecognition
    case baiduShortSpeech
    case iFlyTekVoiceDictation
    case volcengineFlash
}

enum ScheduleParserAdapterKind: Equatable {
    case openAIResponses
    case openAICompatibleChat
    case customOpenAICompatibleChat
}

struct AICredentialField: Identifiable, Equatable, Hashable {
    let id: String
    let displayName: String
    let isSecret: Bool
    let isRequired: Bool

    static let apiKey = AICredentialField(id: "apiKey", displayName: "API Key", isSecret: true)
    static let apiSecret = AICredentialField(id: "apiSecret", displayName: "API Secret", isSecret: true)
    static let secretID = AICredentialField(id: "secretID", displayName: "Secret ID", isSecret: false)
    static let secretKey = AICredentialField(id: "secretKey", displayName: "Secret Key", isSecret: true)
    static let appID = AICredentialField(id: "appID", displayName: "App ID", isSecret: false)
    static let accessKey = AICredentialField(id: "accessKey", displayName: "Access Key", isSecret: true, isRequired: false)

    init(id: String, displayName: String, isSecret: Bool, isRequired: Bool = true) {
        self.id = id
        self.displayName = displayName
        self.isSecret = isSecret
        self.isRequired = isRequired
    }
}

struct AICredentialRequest: Identifiable, Equatable, Hashable {
    var provider: AIProviderID
    var field: AICredentialField

    var id: String { "\(provider.rawValue).\(field.id)" }
}

enum AIProviderID: String, CaseIterable, Identifiable {
    case dashScope = "dashscope"
    case openAI = "openai"
    case deepSeek = "deepseek"
    case zhipu = "zhipu"
    case miniMax = "minimax"
    case moonshot = "moonshot"
    case tencentHunyuan = "tencent-hunyuan"
    case baiduERNIE = "baidu-ernie"
    case openRouter = "openrouter"
    case groq = "groq"
    case xAI = "xai"
    case customOpenAICompatible = "custom-openai-compatible"
    case tencentCloudASR = "tencent-cloud-asr"
    case baiduSpeech = "baidu-speech"
    case iFlyTek = "iflytek"
    case volcengine = "volcengine"
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
    let credentialFields: [AICredentialField]
    let transcriptionModels: [AIModelDefinition]
    let parserModels: [AIModelDefinition]
    let defaultTranscriptionModel: String?
    let defaultParserModel: String?
    let openAICompatibleBaseURL: URL?
    let transcriptionAdapter: TranscriptionAdapterKind?
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
            providerID: .dashScope,
            displayName: "DashScope",
            capabilities: [.transcription, .scheduleParsing],
            credentialFields: [.apiKey],
            transcriptionModels: [
                AIModelDefinition(id: "qwen3-asr-flash", displayName: "qwen3-asr-flash"),
            ],
            parserModels: [
                AIModelDefinition(id: "qwen-plus", displayName: "qwen-plus"),
                AIModelDefinition(id: "qwen-turbo", displayName: "qwen-turbo"),
                AIModelDefinition(id: "qwen-max", displayName: "qwen-max"),
            ],
            defaultTranscriptionModel: "qwen3-asr-flash",
            defaultParserModel: "qwen-plus",
            openAICompatibleBaseURL: URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1"),
            transcriptionAdapter: .dashScopeOpenAICompatibleAudio,
            scheduleParserAdapter: .openAICompatibleChat,
            usesJSONResponseFormat: true
        ),
        AIProviderDefinition(
            providerID: .openAI,
            displayName: "OpenAI",
            capabilities: [.transcription, .scheduleParsing],
            credentialFields: [.apiKey],
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
            transcriptionAdapter: .openAI,
            scheduleParserAdapter: .openAIResponses,
            usesJSONResponseFormat: false
        ),
        AIProviderDefinition(
            providerID: .deepSeek,
            displayName: "DeepSeek",
            capabilities: [.scheduleParsing],
            credentialFields: [.apiKey],
            transcriptionModels: [],
            parserModels: [
                AIModelDefinition(id: "deepseek-v4-flash", displayName: "deepseek-v4-flash"),
                AIModelDefinition(id: "deepseek-v4-pro", displayName: "deepseek-v4-pro"),
                AIModelDefinition(id: "deepseek-chat", displayName: "deepseek-chat"),
            ],
            defaultTranscriptionModel: nil,
            defaultParserModel: "deepseek-v4-flash",
            openAICompatibleBaseURL: URL(string: "https://api.deepseek.com"),
            transcriptionAdapter: nil,
            scheduleParserAdapter: .openAICompatibleChat,
            usesJSONResponseFormat: true
        ),
        AIProviderDefinition(
            providerID: .zhipu,
            displayName: "Zhipu GLM",
            capabilities: [.scheduleParsing],
            credentialFields: [.apiKey],
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
            transcriptionAdapter: nil,
            scheduleParserAdapter: .openAICompatibleChat,
            usesJSONResponseFormat: true
        ),
        AIProviderDefinition(
            providerID: .miniMax,
            displayName: "MiniMax",
            capabilities: [.scheduleParsing],
            credentialFields: [.apiKey],
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
            transcriptionAdapter: nil,
            scheduleParserAdapter: .openAICompatibleChat,
            usesJSONResponseFormat: true
        ),
        AIProviderDefinition(
            providerID: .moonshot,
            displayName: "Moonshot Kimi",
            capabilities: [.scheduleParsing],
            credentialFields: [.apiKey],
            transcriptionModels: [],
            parserModels: [
                AIModelDefinition(id: "kimi-latest", displayName: "kimi-latest"),
                AIModelDefinition(id: "kimi-k2-turbo-preview", displayName: "kimi-k2-turbo-preview"),
                AIModelDefinition(id: "moonshot-v1-32k", displayName: "moonshot-v1-32k"),
            ],
            defaultTranscriptionModel: nil,
            defaultParserModel: "kimi-latest",
            openAICompatibleBaseURL: URL(string: "https://api.moonshot.cn/v1"),
            transcriptionAdapter: nil,
            scheduleParserAdapter: .openAICompatibleChat,
            usesJSONResponseFormat: true
        ),
        AIProviderDefinition(
            providerID: .tencentHunyuan,
            displayName: "Tencent Hunyuan",
            capabilities: [.scheduleParsing],
            credentialFields: [.apiKey],
            transcriptionModels: [],
            parserModels: [
                AIModelDefinition(id: "hunyuan-turbos-latest", displayName: "hunyuan-turbos-latest"),
                AIModelDefinition(id: "hunyuan-large", displayName: "hunyuan-large"),
                AIModelDefinition(id: "hunyuan-lite", displayName: "hunyuan-lite"),
            ],
            defaultTranscriptionModel: nil,
            defaultParserModel: "hunyuan-turbos-latest",
            openAICompatibleBaseURL: URL(string: "https://api.hunyuan.cloud.tencent.com/v1"),
            transcriptionAdapter: nil,
            scheduleParserAdapter: .openAICompatibleChat,
            usesJSONResponseFormat: true
        ),
        AIProviderDefinition(
            providerID: .baiduERNIE,
            displayName: "Baidu Qianfan",
            capabilities: [.scheduleParsing],
            credentialFields: [.apiKey],
            transcriptionModels: [],
            parserModels: [
                AIModelDefinition(id: "ernie-4.5-turbo-128k", displayName: "ernie-4.5-turbo-128k"),
                AIModelDefinition(id: "ernie-4.5-turbo-32k", displayName: "ernie-4.5-turbo-32k"),
                AIModelDefinition(id: "ernie-3.5-8k", displayName: "ernie-3.5-8k"),
            ],
            defaultTranscriptionModel: nil,
            defaultParserModel: "ernie-4.5-turbo-128k",
            openAICompatibleBaseURL: URL(string: "https://qianfan.baidubce.com/v2"),
            transcriptionAdapter: nil,
            scheduleParserAdapter: .openAICompatibleChat,
            usesJSONResponseFormat: true
        ),
        AIProviderDefinition(
            providerID: .openRouter,
            displayName: "OpenRouter",
            capabilities: [.scheduleParsing],
            credentialFields: [.apiKey],
            transcriptionModels: [],
            parserModels: [
                AIModelDefinition(id: "openai/gpt-4o-mini", displayName: "openai/gpt-4o-mini"),
                AIModelDefinition(id: "anthropic/claude-3.5-sonnet", displayName: "anthropic/claude-3.5-sonnet"),
                AIModelDefinition(id: "deepseek/deepseek-chat", displayName: "deepseek/deepseek-chat"),
            ],
            defaultTranscriptionModel: nil,
            defaultParserModel: "openai/gpt-4o-mini",
            openAICompatibleBaseURL: URL(string: "https://openrouter.ai/api/v1"),
            transcriptionAdapter: nil,
            scheduleParserAdapter: .openAICompatibleChat,
            usesJSONResponseFormat: true
        ),
        AIProviderDefinition(
            providerID: .groq,
            displayName: "Groq",
            capabilities: [.scheduleParsing],
            credentialFields: [.apiKey],
            transcriptionModels: [],
            parserModels: [
                AIModelDefinition(id: "llama-3.3-70b-versatile", displayName: "llama-3.3-70b-versatile"),
                AIModelDefinition(id: "openai/gpt-oss-120b", displayName: "openai/gpt-oss-120b"),
            ],
            defaultTranscriptionModel: nil,
            defaultParserModel: "llama-3.3-70b-versatile",
            openAICompatibleBaseURL: URL(string: "https://api.groq.com/openai/v1"),
            transcriptionAdapter: nil,
            scheduleParserAdapter: .openAICompatibleChat,
            usesJSONResponseFormat: true
        ),
        AIProviderDefinition(
            providerID: .xAI,
            displayName: "xAI",
            capabilities: [.scheduleParsing],
            credentialFields: [.apiKey],
            transcriptionModels: [],
            parserModels: [
                AIModelDefinition(id: "grok-4", displayName: "grok-4"),
                AIModelDefinition(id: "grok-3-mini", displayName: "grok-3-mini"),
            ],
            defaultTranscriptionModel: nil,
            defaultParserModel: "grok-4",
            openAICompatibleBaseURL: URL(string: "https://api.x.ai/v1"),
            transcriptionAdapter: nil,
            scheduleParserAdapter: .openAICompatibleChat,
            usesJSONResponseFormat: true
        ),
        AIProviderDefinition(
            providerID: .customOpenAICompatible,
            displayName: "Custom OpenAI-Compatible",
            capabilities: [.scheduleParsing],
            credentialFields: [.apiKey],
            transcriptionModels: [],
            parserModels: [],
            defaultTranscriptionModel: nil,
            defaultParserModel: nil,
            openAICompatibleBaseURL: nil,
            transcriptionAdapter: nil,
            scheduleParserAdapter: .customOpenAICompatibleChat,
            usesJSONResponseFormat: true
        ),
        AIProviderDefinition(
            providerID: .tencentCloudASR,
            displayName: "Tencent Cloud ASR",
            capabilities: [.transcription],
            credentialFields: [.secretID, .secretKey],
            transcriptionModels: [
                AIModelDefinition(id: "16k_zh", displayName: "16k_zh"),
                AIModelDefinition(id: "16k_en", displayName: "16k_en"),
                AIModelDefinition(id: "16k_yue", displayName: "16k_yue"),
            ],
            parserModels: [],
            defaultTranscriptionModel: "16k_zh",
            defaultParserModel: nil,
            openAICompatibleBaseURL: nil,
            transcriptionAdapter: .tencentSentenceRecognition,
            scheduleParserAdapter: nil,
            usesJSONResponseFormat: false
        ),
        AIProviderDefinition(
            providerID: .baiduSpeech,
            displayName: "Baidu Speech",
            capabilities: [.transcription],
            credentialFields: [.apiKey, .secretKey],
            transcriptionModels: [
                AIModelDefinition(id: "80001", displayName: "极速版普通话"),
                AIModelDefinition(id: "1537", displayName: "普通话"),
                AIModelDefinition(id: "1737", displayName: "英语"),
            ],
            parserModels: [],
            defaultTranscriptionModel: "80001",
            defaultParserModel: nil,
            openAICompatibleBaseURL: nil,
            transcriptionAdapter: .baiduShortSpeech,
            scheduleParserAdapter: nil,
            usesJSONResponseFormat: false
        ),
        AIProviderDefinition(
            providerID: .iFlyTek,
            displayName: "iFlyTek",
            capabilities: [.transcription],
            credentialFields: [.appID, .apiKey, .apiSecret],
            transcriptionModels: [
                AIModelDefinition(id: "iat", displayName: "语音听写"),
            ],
            parserModels: [],
            defaultTranscriptionModel: "iat",
            defaultParserModel: nil,
            openAICompatibleBaseURL: nil,
            transcriptionAdapter: .iFlyTekVoiceDictation,
            scheduleParserAdapter: nil,
            usesJSONResponseFormat: false
        ),
        AIProviderDefinition(
            providerID: .volcengine,
            displayName: "Volcengine ASR",
            capabilities: [.transcription],
            credentialFields: [.apiKey, .accessKey],
            transcriptionModels: [
                AIModelDefinition(id: "bigmodel", displayName: "bigmodel"),
            ],
            parserModels: [],
            defaultTranscriptionModel: "bigmodel",
            defaultParserModel: nil,
            openAICompatibleBaseURL: nil,
            transcriptionAdapter: .volcengineFlash,
            scheduleParserAdapter: nil,
            usesJSONResponseFormat: false
        ),
        AIProviderDefinition(
            providerID: .anthropic,
            displayName: "Anthropic",
            capabilities: [],
            credentialFields: [.apiKey],
            transcriptionModels: [],
            parserModels: [],
            defaultTranscriptionModel: nil,
            defaultParserModel: nil,
            openAICompatibleBaseURL: nil,
            transcriptionAdapter: nil,
            scheduleParserAdapter: nil,
            usesJSONResponseFormat: false
        ),
        AIProviderDefinition(
            providerID: .gemini,
            displayName: "Gemini",
            capabilities: [],
            credentialFields: [.apiKey],
            transcriptionModels: [],
            parserModels: [],
            defaultTranscriptionModel: nil,
            defaultParserModel: nil,
            openAICompatibleBaseURL: nil,
            transcriptionAdapter: nil,
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
        static let customParserBaseURL = "aiAssistant.customParserBaseURL"
        static let languageMode = "aiAssistant.languageMode"
        static let defaultReminderLeadMinutes = "aiAssistant.defaultReminderLeadMinutes"
    }

    static let defaultTranscriptionProvider: AIProviderID = .dashScope
    static let defaultParserProvider: AIProviderID = .dashScope
    static let defaultTranscriptionModel = defaultTranscriptionProvider.definition.defaultTranscriptionModel!
    static let defaultParserModel = defaultParserProvider.definition.defaultParserModel!

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

    var customParserBaseURL: String {
        didSet { defaults.set(customParserBaseURL, forKey: Keys.customParserBaseURL) }
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
            Keys.transcriptionProviderID: Self.defaultTranscriptionProvider.rawValue,
            Keys.parserProviderID: Self.defaultParserProvider.rawValue,
            Keys.transcriptionModel: Self.defaultTranscriptionModel,
            Keys.parserModel: Self.defaultParserModel,
            Keys.customParserBaseURL: "",
            Keys.languageMode: "auto",
            Keys.defaultReminderLeadMinutes: 10,
        ])

        self.isEnabled = defaults.object(forKey: Keys.isEnabled) as? Bool ?? false
        self.transcriptionProviderID = defaults.string(forKey: Keys.transcriptionProviderID) ?? Self.defaultTranscriptionProvider.rawValue
        self.parserProviderID = defaults.string(forKey: Keys.parserProviderID) ?? Self.defaultParserProvider.rawValue
        self.transcriptionModel = defaults.string(forKey: Keys.transcriptionModel) ?? Self.defaultTranscriptionModel
        self.parserModel = defaults.string(forKey: Keys.parserModel) ?? Self.defaultParserModel
        self.customParserBaseURL = defaults.string(forKey: Keys.customParserBaseURL) ?? ""
        self.languageMode = defaults.string(forKey: Keys.languageMode) ?? "auto"
        self.defaultReminderLeadMinutes = defaults.object(forKey: Keys.defaultReminderLeadMinutes) as? Int ?? 10
        normalizeStoredProviderChoices()
    }

    var selectedTranscriptionProvider: AIProviderID {
        let provider = AIProviderID(rawValue: transcriptionProviderID) ?? Self.defaultTranscriptionProvider
        return provider.supports(.transcription) ? provider : Self.defaultTranscriptionProvider
    }

    var selectedParserProvider: AIProviderID {
        let provider = AIProviderID(rawValue: parserProviderID) ?? Self.defaultParserProvider
        return provider.supports(.scheduleParsing) ? provider : Self.defaultParserProvider
    }

    var availableTranscriptionModels: [String] {
        selectedTranscriptionProvider.definition.transcriptionModels.map(\.id)
    }

    var availableParserModels: [String] {
        selectedParserProvider.definition.parserModels.map(\.id)
    }

    var credentialRequestsForCurrentFlow: [AICredentialRequest] {
        let selected = Set([selectedTranscriptionProvider, selectedParserProvider])
        return AIProviderID.allCases
            .filter { selected.contains($0) }
            .flatMap { provider in
                provider.definition.credentialFields.map { AICredentialRequest(provider: provider, field: $0) }
            }
    }

    var requiredCredentialRequestsForCurrentFlow: [AICredentialRequest] {
        credentialRequestsForCurrentFlow.filter(\.field.isRequired)
    }

    var requiredAPIKeyProvidersForCurrentFlow: [AIProviderID] {
        let providerSet = Set(requiredCredentialRequestsForCurrentFlow.map(\.provider))
        return AIProviderID.allCases.filter { providerSet.contains($0) }
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

        if provider == .customOpenAICompatible {
            if parserModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                parserModel = "custom-model"
            }
            return
        }

        parserModel = validModel(
            currentModel: parserModel,
            availableModels: provider.definition.parserModels,
            defaultModel: provider.definition.defaultParserModel
        )
    }

    func credential(_ fieldID: String, for provider: AIProviderID) throws -> String? {
        try apiKeyStore.credential(fieldID, for: provider)
    }

    func saveCredential(_ value: String, fieldID: String, for provider: AIProviderID) throws {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedValue.isEmpty {
            try apiKeyStore.deleteCredential(fieldID, for: provider)
        } else {
            try apiKeyStore.saveCredential(trimmedValue, fieldID: fieldID, for: provider)
        }
    }

    func apiKey(for provider: AIProviderID) throws -> String? {
        try apiKeyStore.apiKey(for: provider)
    }

    func saveAPIKey(_ key: String, for provider: AIProviderID) throws {
        try saveCredential(key, fieldID: AICredentialField.apiKey.id, for: provider)
    }

    func firstMissingCredentialForCurrentFlow() throws -> AICredentialRequest? {
        for request in requiredCredentialRequestsForCurrentFlow {
            let value = try credential(request.field.id, for: request.provider)
            if value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                return request
            }
        }
        return nil
    }

    func firstMissingAPIKeyProviderForCurrentFlow() throws -> AIProviderID? {
        try firstMissingCredentialForCurrentFlow()?.provider
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
