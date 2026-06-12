//
//  ScheduleParserPrompt.swift
//  NotchMove
//
//  Created by Codex on 5/1/26.
//

import Foundation

enum ScheduleParserPrompt {
    static let instructions = """
    Extract schedule reminder drafts for NotchMove. Return only structured output.
    Create drafts only when the title and start date/time are clear.
    Resolve relative dates using the supplied current date, timezone, locale, and app language.
    If the user is ambiguous, add questions and do not invent exact dates.
    Use the default reminder lead minutes unless the transcript says otherwise.
    Never claim that reminders were added. The user will review drafts before anything is saved.
    """

    static func input(transcript: Transcript, context: ScheduleParseContext) -> String {
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

    static var schemaJSONString: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(scheduleSchema),
              let string = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return string
    }

    static func decodeResult(from providerText: String, provider: String) throws -> ScheduleParseResult {
        let jsonText = extractJSONObjectText(from: providerText)

        do {
            return try JSONDecoder().decode(
                ScheduleParseResult.self,
                from: Data(jsonText.utf8)
            )
        } catch {
            throw AIScheduleAssistantError.invalidParserJSON(
                provider: provider,
                message: error.localizedDescription
            )
        }
    }

    static func extractJSONObjectText(from providerText: String) -> String {
        var text = providerText.trimmingCharacters(in: .whitespacesAndNewlines)
        text = stripThinkBlocks(from: text)
        text = stripMarkdownFence(from: text)

        guard let firstObjectCharacter = text.firstIndex(of: "{"),
              let lastObjectCharacter = text.lastIndex(of: "}"),
              firstObjectCharacter <= lastObjectCharacter
        else {
            return text
        }

        return String(text[firstObjectCharacter...lastObjectCharacter])
    }

    static let scheduleSchema: JSONValue = .object([
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

    private static func existingItemsDescription(_ items: [DailyScheduleItem], timeZone: TimeZone) -> String {
        guard !items.isEmpty else { return "[]" }

        return items.map { item in
            let start = ISO8601DateFormatter.aiScheduleString(from: item.startDate, timeZone: timeZone)
            let end = item.endDate.map { ISO8601DateFormatter.aiScheduleString(from: $0, timeZone: timeZone) } ?? "null"
            return "- \(item.title): start=\(start), end=\(end)"
        }
        .joined(separator: "\n")
    }

    private static func stripThinkBlocks(from text: String) -> String {
        var output = text

        while let start = output.range(of: "<think>"),
              let end = output.range(of: "</think>", range: start.upperBound..<output.endIndex) {
            output.removeSubrange(start.lowerBound..<end.upperBound)
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stripMarkdownFence(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") else { return trimmed }

        var lines = trimmed.components(separatedBy: .newlines)
        if lines.first?.hasPrefix("```") == true {
            lines.removeFirst()
        }

        if lines.last?.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```") == true {
            lines.removeLast()
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension ISO8601DateFormatter {
    static func aiScheduleString(from date: Date, timeZone: TimeZone) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = timeZone
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
