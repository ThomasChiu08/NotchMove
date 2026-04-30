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

        do {
            return try ScheduleParseResult.decoder.decode(
                ScheduleParseResult.self,
                from: Data(outputText.utf8)
            )
        } catch {
            throw AIScheduleAssistantError.providerResponseInvalid(
                provider: displayName,
                message: error.localizedDescription
            )
        }
    }

    private func makeRequest(
        transcript: Transcript,
        context: ScheduleParseContext
    ) -> OpenAIResponsesRequest {
        OpenAIResponsesRequest(
            model: model,
            instructions: instructions,
            input: input(transcript: transcript, context: context),
            text: .init(format: .init(
                type: "json_schema",
                name: "notchmove_schedule_parse_result",
                strict: true,
                schema: Self.scheduleSchema
            )),
            store: false
        )
    }

    private var instructions: String {
        """
        Extract schedule reminder drafts for NotchMove. Return only structured output.
        Create drafts only when the title and start date/time are clear.
        Resolve relative dates using the supplied current date, timezone, locale, and app language.
        If the user is ambiguous, add questions and do not invent exact dates.
        Use the default reminder lead minutes unless the transcript says otherwise.
        Never claim that reminders were added. The user will review drafts before anything is saved.
        """
    }

    private func input(transcript: Transcript, context: ScheduleParseContext) -> String {
        """
        Transcript:
        \(transcript.text)

        Current date:
        \(ISO8601DateFormatter.aiScheduleString(from: context.currentDate, timeZone: context.timeZone))

        Timezone:
        \(context.timeZone.identifier)

        Locale:
        \(context.localeIdentifier)

        App language:
        \(context.appLanguage)

        Default reminder lead minutes:
        \(context.defaultReminderLeadMinutes)

        Existing schedule items:
        \(existingItemsDescription(context.existingScheduleItems, timeZone: context.timeZone))
        """
    }

    private func existingItemsDescription(_ items: [DailyScheduleItem], timeZone: TimeZone) -> String {
        guard !items.isEmpty else { return "[]" }

        return items.map { item in
            let start = ISO8601DateFormatter.aiScheduleString(from: item.startDate, timeZone: timeZone)
            let end = item.endDate.map { ISO8601DateFormatter.aiScheduleString(from: $0, timeZone: timeZone) } ?? "null"
            return "- \(item.title): start=\(start), end=\(end)"
        }
        .joined(separator: "\n")
    }

    private static let scheduleSchema: JSONValue = .object([
        "type": .string("object"),
        "additionalProperties": .bool(false),
        "required": .array([
            .string("items"),
            .string("questions"),
            .string("warnings"),
        ]),
        "properties": .object([
            "items": .object([
                "type": .string("array"),
                "items": .object([
                    "type": .string("object"),
                    "additionalProperties": .bool(false),
                    "required": .array([
                        .string("title"),
                        .string("startDate"),
                        .string("endDate"),
                        .string("notes"),
                        .string("reminderLeadMinutes"),
                        .string("isReminderEnabled"),
                        .string("confidence"),
                        .string("warning"),
                    ]),
                    "properties": .object([
                        "title": .object(["type": .string("string")]),
                        "startDate": .object(["type": .string("string")]),
                        "endDate": .object(["type": .array([.string("string"), .string("null")])]),
                        "notes": .object(["type": .array([.string("string"), .string("null")])]),
                        "reminderLeadMinutes": .object(["type": .string("integer")]),
                        "isReminderEnabled": .object(["type": .string("boolean")]),
                        "confidence": .object([
                            "type": .string("string"),
                            "enum": .array([.string("high"), .string("medium"), .string("low")]),
                        ]),
                        "warning": .object(["type": .array([.string("string"), .string("null")])]),
                    ]),
                ]),
            ]),
            "questions": .object([
                "type": .string("array"),
                "items": .object(["type": .string("string")]),
            ]),
            "warnings": .object([
                "type": .string("array"),
                "items": .object(["type": .string("string")]),
            ]),
        ]),
    ])
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

private extension ScheduleParseResult {
    static let decoder: JSONDecoder = {
        JSONDecoder()
    }()
}

private extension ISO8601DateFormatter {
    static func aiScheduleString(from date: Date, timeZone: TimeZone) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = timeZone
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
