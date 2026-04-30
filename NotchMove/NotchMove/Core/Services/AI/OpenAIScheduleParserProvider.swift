//
//  OpenAIScheduleParserProvider.swift
//  NotchMove
//
//  Created by Codex on 4/30/26.
//

import Foundation

struct OpenAIScheduleParserProvider: ScheduleParserProvider {
    let apiKey: String
    let model: String
    let urlSession: URLSession

    var displayName: String { "OpenAI" }

    init(
        apiKey: String,
        model: String = AIProviderPreferences.defaultParserModel,
        urlSession: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.model = model
        self.urlSession = urlSession
    }

    func parseSchedule(transcript: Transcript, context: ScheduleParseContext) async throws -> ScheduleParseResult {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(makeRequest(transcript: transcript, context: context))

        let (data, response) = try await urlSession.data(for: request)
        try OpenAIHTTP.validateResponse(
            data: data,
            response: response,
            provider: displayName,
            apiKey: apiKey
        )

        guard let outputText = try OpenAIResponseTextExtractor.outputText(from: data) else {
            throw AIScheduleAssistantError.providerResponseInvalid(
                provider: displayName,
                message: "Missing structured output text."
            )
        }

        return try ScheduleParserPrompt.decodeResult(from: outputText, provider: displayName)
    }

    private func makeRequest(
        transcript: Transcript,
        context: ScheduleParseContext
    ) -> OpenAIResponsesRequest {
        OpenAIResponsesRequest(
            model: model,
            instructions: ScheduleParserPrompt.instructions,
            input: ScheduleParserPrompt.input(transcript: transcript, context: context),
            text: .init(format: .init(
                type: "json_schema",
                name: "notchmove_schedule_parse_result",
                strict: true,
                schema: ScheduleParserPrompt.scheduleSchema
            )),
            store: false
        )
    }
}

struct OpenAIResponseTextExtractor {
    static func outputText(from data: Data) throws -> String? {
        let response = try JSONDecoder().decode(OpenAIResponsesResponse.self, from: data)
        return response.output.lazy
            .compactMap(\.content)
            .flatMap { $0 }
            .first { $0.type == "output_text" }?
            .text
    }
}

private struct OpenAIResponsesRequest: Encodable {
    struct TextConfiguration: Encodable {
        var format: TextFormat
    }

    struct TextFormat: Encodable {
        var type: String
        var name: String
        var strict: Bool
        var schema: JSONValue
    }

    var model: String
    var instructions: String
    var input: String
    var text: TextConfiguration
    var store: Bool
}

private struct OpenAIResponsesResponse: Decodable {
    struct OutputItem: Decodable {
        var content: [ContentItem]?
    }

    struct ContentItem: Decodable {
        var type: String
        var text: String?
    }

    var output: [OutputItem]
}
