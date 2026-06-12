//
//  VoiceTextCleanupService.swift
//  NotchMove
//
//  Created by Codex on 5/14/26.
//

import Foundation
import OSLog

struct VoiceTextCleanupContext: Equatable {
    var localeIdentifier: String
    var appName: String?
    var personalTerms: [String]
}

protocol VoiceTextRewriteProvider {
    var displayName: String { get }
    func rewrite(text: String, context: VoiceTextCleanupContext) async throws -> String
}

@MainActor
final class VoiceTextCleanupService {
    private let preferences: AIProviderPreferences
    private let urlSession: URLSession
    private let logger = Logger(subsystem: "com.thomaschiu.developer.NotchMove", category: "voice-cleanup")

    init(
        preferences: AIProviderPreferences,
        urlSession: URLSession = .shared
    ) {
        self.preferences = preferences
        self.urlSession = urlSession
    }

    func clean(
        text: String,
        context: VoiceTextCleanupContext,
        mode: Preferences.VoiceCleanupMode = .clean
    ) async -> String {
        let rawText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawText.isEmpty else { return "" }

        if mode == .raw {
            return rawText
        }

        let localText = VoiceLocalTextCleaner.clean(text)
        guard mode == .polished, preferences.isEnabled else { return localText }

        do {
            let provider = try makeRewriteProvider()
            let rewrittenText = try await provider.rewrite(text: localText, context: context)
            let cleaned = VoiceLocalTextCleaner.clean(rewrittenText)
            return cleaned.isEmpty ? localText : cleaned
        } catch {
            logger.error("Voice cleanup provider failed: \(error.localizedDescription, privacy: .public)")
            return localText
        }
    }

    private func makeRewriteProvider() throws -> any VoiceTextRewriteProvider {
        let providerID = preferences.selectedParserProvider
        let definition = providerID.definition
        let model = preferences.parserModel.trimmingCharacters(in: .whitespacesAndNewlines)

        switch definition.scheduleParserAdapter {
        case .openAIResponses:
            return OpenAIVoiceTextRewriteProvider(
                apiKey: try requiredCredential(.apiKey, for: providerID),
                model: model,
                urlSession: urlSession
            )
        case .openAICompatibleChat:
            guard let baseURL = definition.openAICompatibleBaseURL else {
                throw AIScheduleAssistantError.providerResponseInvalid(
                    provider: providerID.displayName,
                    message: "Missing provider base URL."
                )
            }
            return OpenAICompatibleVoiceTextRewriteProvider(
                providerID: providerID,
                apiKey: try requiredCredential(.apiKey, for: providerID),
                model: model,
                baseURL: baseURL,
                urlSession: urlSession
            )
        case .customOpenAICompatibleChat:
            guard let baseURL = URL(string: preferences.customParserBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)),
                  !model.isEmpty
            else {
                throw AIScheduleAssistantError.providerResponseInvalid(
                    provider: providerID.displayName,
                    message: "Custom cleanup provider configuration is incomplete."
                )
            }
            return OpenAICompatibleVoiceTextRewriteProvider(
                providerID: providerID,
                apiKey: try requiredCredential(.apiKey, for: providerID),
                model: model,
                baseURL: baseURL,
                urlSession: urlSession
            )
        case nil:
            throw AIScheduleAssistantError.providerResponseInvalid(
                provider: providerID.displayName,
                message: "Unsupported cleanup provider."
            )
        }
    }

    private func requiredCredential(_ field: AICredentialField, for provider: AIProviderID) throws -> String {
        let value = try preferences.credential(field.id, for: provider)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty else {
            throw AIScheduleAssistantError.missingCredential(provider: provider.displayName, field: field.displayName)
        }
        return value
    }
}

enum VoiceLocalTextCleaner {
    static func clean(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        var result = trimmed
        result = removeEnglishFillers(result)
        result = removeChineseFillers(result)
        result = collapseRepeatedWords(result)
        result = result.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: #" ?([,.;:!?])"#, with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: #"([,.;:!?])([^\s])"#, with: "$1 $2", options: .regularExpression)
        result = result.replacingOccurrences(of: #"([。！？；：，])\s+"#, with: "$1", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func removeEnglishFillers(_ text: String) -> String {
        let pattern = #"(?i)\b(um+|uh+|erm+|ah+|like|you know|sort of|kind of)\b[, ]*"#
        return text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }

    private static func removeChineseFillers(_ text: String) -> String {
        var result = text
        for filler in ["嗯，", "嗯,", "嗯 ", "呃，", "呃,", "呃 ", "那个，", "那个 ", "就是，", "就是 "] {
            result = result.replacingOccurrences(of: filler, with: "")
        }
        return result
    }

    private static func collapseRepeatedWords(_ text: String) -> String {
        text.replacingOccurrences(
            of: #"(?i)\b([[:alpha:]]{2,})\b(?:\s+\1\b)+"#,
            with: "$1",
            options: .regularExpression
        )
    }
}

private struct OpenAIVoiceTextRewriteProvider: VoiceTextRewriteProvider {
    let apiKey: String
    let model: String
    let urlSession: URLSession

    var displayName: String { "OpenAI" }

    func rewrite(text: String, context: VoiceTextCleanupContext) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(OpenAIVoiceRewriteRequest(
            model: model,
            instructions: VoiceRewritePrompt.instructions(context: context),
            input: text,
            store: false
        ))

        let (data, response) = try await urlSession.data(for: request)
        try ProviderHTTP.validateResponse(data: data, response: response, provider: displayName, apiKey: apiKey)

        guard let outputText = try OpenAIResponseTextExtractor.outputText(from: data) else {
            throw AIScheduleAssistantError.providerResponseInvalid(
                provider: displayName,
                message: "Missing cleanup output text."
            )
        }
        return outputText
    }
}

private struct OpenAICompatibleVoiceTextRewriteProvider: VoiceTextRewriteProvider {
    let providerID: AIProviderID
    let apiKey: String
    let model: String
    let baseURL: URL
    let urlSession: URLSession

    var displayName: String { providerID.displayName }

    func rewrite(text: String, context: VoiceTextCleanupContext) async throws -> String {
        var request = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(VoiceChatCompletionRequest(
            model: model,
            messages: [
                VoiceChatCompletionMessage(role: "system", content: VoiceRewritePrompt.instructions(context: context)),
                VoiceChatCompletionMessage(role: "user", content: text),
            ],
            stream: false
        ))

        let (data, response) = try await urlSession.data(for: request)
        try ProviderHTTP.validateResponse(data: data, response: response, provider: displayName, apiKey: apiKey)

        guard let outputText = try OpenAICompatibleChatResponseTextExtractor.outputText(from: data) else {
            throw AIScheduleAssistantError.providerResponseInvalid(
                provider: displayName,
                message: "Missing cleanup output text."
            )
        }
        return outputText
    }
}

private enum VoiceRewritePrompt {
    static func instructions(context: VoiceTextCleanupContext) -> String {
        let appLine = context.appName.map { "Current app: \($0)." } ?? "Current app: unknown."
        let termLine = context.personalTerms.isEmpty ? "" : "Preserve these personal dictionary terms exactly: \(context.personalTerms.joined(separator: ", "))."
        return """
        You clean short voice dictation for direct insertion into a macOS text field.
        Return only the cleaned text, with no Markdown, quotes, labels, or explanation.
        Preserve the user's language, meaning, numbers, names, URLs, code-like text, and intent.
        Do not add facts, commands, greetings, sign-offs, or content the user did not say.
        Remove filler words, obvious stutters, and accidental repetitions.
        Fix punctuation, casing, and spacing conservatively.
        \(appLine)
        Locale: \(context.localeIdentifier).
        \(termLine)
        """
    }
}

private struct OpenAIVoiceRewriteRequest: Encodable {
    var model: String
    var instructions: String
    var input: String
    var store: Bool
}

private struct VoiceChatCompletionRequest: Encodable {
    var model: String
    var messages: [VoiceChatCompletionMessage]
    var stream: Bool
}

private struct VoiceChatCompletionMessage: Encodable {
    var role: String
    var content: String
}
