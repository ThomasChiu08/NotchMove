//
//  AIScheduleDraft.swift
//  NotchMove
//
//  Created by Codex on 4/30/26.
//

import Foundation

enum AIScheduleConfidence: String, Codable, CaseIterable {
    case high
    case medium
    case low
}

struct AIScheduleDraft: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var startDate: Date
    var endDate: Date?
    var notes: String?
    var reminderLeadMinutes: Int
    var isReminderEnabled: Bool
    var sourceTranscript: String
    var confidence: AIScheduleConfidence
    var warning: String?

    init(
        id: UUID = UUID(),
        title: String,
        startDate: Date,
        endDate: Date? = nil,
        notes: String? = nil,
        reminderLeadMinutes: Int = 10,
        isReminderEnabled: Bool = true,
        sourceTranscript: String = "",
        confidence: AIScheduleConfidence = .medium,
        warning: String? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.reminderLeadMinutes = reminderLeadMinutes
        self.isReminderEnabled = isReminderEnabled
        self.sourceTranscript = sourceTranscript
        self.confidence = confidence
        self.warning = warning
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case startDate
        case endDate
        case notes
        case reminderLeadMinutes
        case isReminderEnabled
        case sourceTranscript
        case confidence
        case warning
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        startDate = try Self.decodeDate(forKey: .startDate, in: container)
        endDate = try Self.decodeOptionalDate(forKey: .endDate, in: container)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        reminderLeadMinutes = try container.decode(Int.self, forKey: .reminderLeadMinutes)
        isReminderEnabled = try container.decode(Bool.self, forKey: .isReminderEnabled)
        sourceTranscript = try container.decodeIfPresent(String.self, forKey: .sourceTranscript) ?? ""
        confidence = try container.decode(AIScheduleConfidence.self, forKey: .confidence)
        warning = try container.decodeIfPresent(String.self, forKey: .warning)
    }

    func scheduleItem() -> DailyScheduleItem {
        DailyScheduleItem(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: startDate,
            endDate: endDate,
            notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            reminderLeadMinutes: reminderLeadMinutes,
            isReminderEnabled: isReminderEnabled
        )
    }

    private static func decodeDate(
        forKey key: CodingKeys,
        in container: KeyedDecodingContainer<CodingKeys>
    ) throws -> Date {
        let string = try container.decode(String.self, forKey: key)
        guard let date = ISO8601DateFormatter.aiScheduleDate(from: string) else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: container,
                debugDescription: "Expected ISO 8601 date."
            )
        }
        return date
    }

    private static func decodeOptionalDate(
        forKey key: CodingKeys,
        in container: KeyedDecodingContainer<CodingKeys>
    ) throws -> Date? {
        guard let string = try container.decodeIfPresent(String.self, forKey: key) else { return nil }
        guard let date = ISO8601DateFormatter.aiScheduleDate(from: string) else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: container,
                debugDescription: "Expected ISO 8601 date or null."
            )
        }
        return date
    }
}

struct ScheduleParseResult: Codable, Equatable {
    static let pastDateWarning = "Parsed date is in the past."
    static let notTodayWarning = "Parsed date is not today."

    var drafts: [AIScheduleDraft]
    var questions: [String]
    var warnings: [String]
    var transcriptText: String

    init(
        drafts: [AIScheduleDraft] = [],
        questions: [String] = [],
        warnings: [String] = [],
        transcriptText: String = ""
    ) {
        self.drafts = drafts
        self.questions = questions
        self.warnings = warnings
        self.transcriptText = transcriptText
    }

    private enum CodingKeys: String, CodingKey {
        case drafts = "items"
        case questions
        case warnings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        drafts = try container.decode([AIScheduleDraft].self, forKey: .drafts)
        questions = try container.decode([String].self, forKey: .questions)
        warnings = try container.decode([String].self, forKey: .warnings)
        transcriptText = ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(drafts, forKey: .drafts)
        try container.encode(questions, forKey: .questions)
        try container.encode(warnings, forKey: .warnings)
    }

    func validatedAgainstContext(_ context: ScheduleParseContext) -> ScheduleParseResult {
        var copy = self
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = context.timeZone

        var warnings = copy.warnings
        copy.drafts = drafts.map { draft in
            var draft = draft

            if draft.sourceTranscript.isEmpty {
                draft.sourceTranscript = transcriptText
            }

            if draft.startDate < context.currentDate {
                Self.addWarning(Self.pastDateWarning, to: &draft, warnings: &warnings)
            } else if !calendar.isDate(draft.startDate, inSameDayAs: context.currentDate) {
                Self.addWarning(Self.notTodayWarning, to: &draft, warnings: &warnings)
            }

            return draft
        }
        copy.warnings = warnings
        return copy
    }

    private static func addWarning(
        _ warning: String,
        to draft: inout AIScheduleDraft,
        warnings: inout [String]
    ) {
        if draft.warning?.isEmpty != false {
            draft.warning = warning
        }

        if !warnings.contains(warning) {
            warnings.append(warning)
        }
    }
}

struct Transcript: Equatable {
    var text: String
    var language: String?
    var duration: TimeInterval?
}

private extension ISO8601DateFormatter {
    static let aiSchedule: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let aiScheduleWithoutFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func aiScheduleDate(from string: String) -> Date? {
        aiSchedule.date(from: string) ?? aiScheduleWithoutFractionalSeconds.date(from: string)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
