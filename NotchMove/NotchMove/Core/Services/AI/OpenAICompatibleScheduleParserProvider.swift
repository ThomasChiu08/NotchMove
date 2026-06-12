//
//  OpenAICompatibleScheduleParserProvider.swift
//  NotchMove
//
//  Created by Codex on 5/1/26.
//

import Foundation

struct OpenAICompatibleScheduleParserProvider: ScheduleParserProvider {
    let providerID: AIProviderID
    let apiKey: String
    let model: String
    let baseURL: URL
    let usesJSONResponseFormat: Bool
    let urlSession: URLSession

    var displayName: String { providerID.displayName }

    init(
        providerID: AIProviderID,
        apiKey: String,
        model: String,
        baseURL: URL,
        usesJSONResponseFormat: Bool,
        urlSession: URLSession = .shared
    ) {
        self.providerID = providerID
        self.apiKey = apiKey
        self.model = model
        self.baseURL = baseURL
        self.usesJSONResponseFormat = usesJSONResponseFormat
        self.urlSession = urlSession
    }

    func parseSchedule(transcript: Transcript, context: ScheduleParseContext) async throws -> ScheduleParseResult {
        let messages = makeMessages(transcript: transcript, context: context)
        let firstText = try await requestText(messages: messages)

        do {
            return try ScheduleParserPrompt.decodeResult(from: firstText, provider: displayName)
        } catch let decodeError as AIScheduleAssistantError {
            let repairMessages = messages + [
                ChatCompletionMessage(role: "assistant", content: firstText),
                ChatCompletionMessage(
                    role: "user",
                    content: "The previous response was not valid NotchMove schedule JSON. Return one corrected JSON object only, using the exact schema."
                ),
            ]
            let repairedText = try await requestText(messages: repairMessages)

            do {
                return try ScheduleParserPrompt.decodeResult(from: repairedText, provider: displayName)
            } catch {
                throw decodeError
            }
        }
    }

    private func requestText(messages: [ChatCompletionMessage]) async throws -> String {
        do {
            return try await requestText(
                messages: messages,
                includeResponseFormat: usesJSONResponseFormat
            )
        } catch AIScheduleAssistantError.providerRequestFailed(_, let statusCode, _) where
            usesJSONResponseFormat && (statusCode == 400 || statusCode == 422) {
            return try await requestText(messages: messages, includeResponseFormat: false)
        }
    }

    private func requestText(
        messages: [ChatCompletionMessage],
        includeResponseFormat: Bool
    ) async throws -> String {
        var request = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ChatCompletionRequest(
            model: model,
            messages: messages,
            responseFormat: includeResponseFormat ? .jsonObject : nil,
            stream: false
        ))

        let (data, response) = try await urlSession.data(for: request)
        try ProviderHTTP.validateResponse(
            data: data,
            response: response,
            provider: displayName,
            apiKey: apiKey
        )

        guard let outputText = try OpenAICompatibleChatResponseTextExtractor.outputText(from: data) else {
            throw AIScheduleAssistantError.providerResponseInvalid(
                provider: displayName,
                message: "Missing chat completion output text."
            )
        }

        return outputText
    }

    private func makeMessages(
        transcript: Transcript,
        context: ScheduleParseContext
    ) -> [ChatCompletionMessage] {
        [
            ChatCompletionMessage(
                role: "system",
                content: """
                \(ScheduleParserPrompt.instructions)

                Return exactly one JSON object that conforms to this schema:
                \(ScheduleParserPrompt.schemaJSONString)
                """
            ),
            ChatCompletionMessage(
                role: "user",
                content: ScheduleParserPrompt.input(transcript: transcript, context: context)
            ),
        ]
    }
}

struct OpenAICompatibleChatResponseTextExtractor {
    static func outputText(from data: Data) throws -> String? {
        let response = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        return response.choices.first?.message.content
    }
}

private struct ChatCompletionRequest: Encodable {
    var model: String
    var messages: [ChatCompletionMessage]
    var responseFormat: ResponseFormat?
    var stream: Bool

    private enum CodingKeys: String, CodingKey {
        case model
        case messages
        case responseFormat = "response_format"
        case stream
    }
}

private struct ChatCompletionMessage: Encodable {
    var role: String
    var content: String
}

private struct ResponseFormat: Encodable {
    var type: String

    static let jsonObject = ResponseFormat(type: "json_object")
}

private struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            var content: String?
        }

        var message: Message
    }

    var choices: [Choice]
}
